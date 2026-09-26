import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { requireOwnedMoment, serializeMoment } from "@/lib/moments";
import { removeObjects, MEDIA_BUCKET } from "@/lib/storage";
import { json, withErrorHandling, ApiError } from "@/lib/http";

type RouteParams = { params: Promise<{ id: string }> };

export const GET = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;
  const moment = await requireOwnedMoment(user.id, id);
  return json({ moment: await serializeMoment(moment) });
});

const saveSchema = z.object({
  title: z.string().max(200).default(""),
  creationType: z.string(),
  createdAt: z.string().datetime().optional(),
  mood: z.string().nullish(),
  atmosphere: z.string().nullish(),
  timeOfDay: z.string().nullish(),
  locationName: z.string().nullish(),
  latitude: z.number().min(-90).max(90).nullish(),
  longitude: z.number().min(-180).max(180).nullish(),
  musicTitle: z.string().nullish(),
  musicArtist: z.string().nullish(),
  musicAlbum: z.string().nullish(),
  musicArtworkUrl: z.string().nullish(),
  text: z.object({ id: z.string(), content: z.string() }).optional(),
  drawing: z.object({ id: z.string(), data: z.unknown() }).optional(),
});

/** Upserts a moment's core fields and its text/drawing creations (client-generated id, safe to retry). */
export const PUT = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;
  const body = saveSchema.parse(await request.json());

  const existing = await prisma.moment.findUnique({ where: { id } });
  if (existing && existing.userId !== user.id) throw new ApiError(404, "moment_not_found");

  const coreData = {
    title: body.title,
    creationType: body.creationType,
    mood: body.mood ?? null,
    atmosphere: body.atmosphere ?? null,
    timeOfDay: body.timeOfDay ?? null,
    locationName: body.locationName ?? null,
    latitude: body.latitude ?? null,
    longitude: body.longitude ?? null,
    musicTitle: body.musicTitle ?? null,
    musicArtist: body.musicArtist ?? null,
    musicAlbum: body.musicAlbum ?? null,
    musicArtworkUrl: body.musicArtworkUrl ?? null,
  };

  await prisma.$transaction(async (tx) => {
    await tx.moment.upsert({
      where: { id },
      create: {
        id,
        userId: user.id,
        ...coreData,
        ...(body.createdAt ? { createdAt: new Date(body.createdAt) } : {}),
      },
      update: coreData,
    });

    if (body.text) {
      await tx.creation.upsert({
        where: { id: body.text.id },
        create: { id: body.text.id, momentId: id, type: "text", textContent: body.text.content },
        update: { textContent: body.text.content },
      });
    }

    if (body.drawing) {
      await tx.creation.upsert({
        where: { id: body.drawing.id },
        create: {
          id: body.drawing.id,
          momentId: id,
          type: "drawing",
          drawingData: body.drawing.data as never,
        },
        update: { drawingData: body.drawing.data as never },
      });
    }
  });

  const moment = await requireOwnedMoment(user.id, id);
  return json({ moment: await serializeMoment(moment) });
});

export const DELETE = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;
  const moment = await requireOwnedMoment(user.id, id);

  const paths = moment.media.map((m) => m.storagePath);
  await prisma.moment.delete({ where: { id } });
  await removeObjects(MEDIA_BUCKET, paths).catch(() => undefined);

  return json({ ok: true });
});
