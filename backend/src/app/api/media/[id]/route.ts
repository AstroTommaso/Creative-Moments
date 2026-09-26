import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { uploadObject, createSignedUrl, removeObjects, MEDIA_BUCKET } from "@/lib/storage";
import { json, withErrorHandling, ApiError } from "@/lib/http";

type RouteParams = { params: Promise<{ id: string }> };

/** Overwrites an existing media item's file in place (same row, same storage path). */
export const PUT = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;

  const media = await prisma.media.findUnique({ where: { id }, include: { moment: true } });
  if (!media || media.moment.userId !== user.id) throw new ApiError(404, "media_not_found");

  const form = await request.formData();
  const file = form.get("file");
  if (!(file instanceof File)) throw new ApiError(400, "missing_file");

  const bytes = Buffer.from(await file.arrayBuffer());
  await uploadObject(MEDIA_BUCKET, media.storagePath, bytes, file.type || "application/octet-stream");

  return json({
    media: {
      id: media.id,
      momentId: media.momentId,
      type: media.type,
      storagePath: media.storagePath,
      metadata: media.metadata,
      url: await createSignedUrl(MEDIA_BUCKET, media.storagePath),
    },
  });
});

export const DELETE = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;

  const media = await prisma.media.findUnique({
    where: { id },
    include: { moment: true },
  });
  if (!media || media.moment.userId !== user.id) throw new ApiError(404, "media_not_found");

  await prisma.media.delete({ where: { id } });
  await removeObjects(MEDIA_BUCKET, [media.storagePath]).catch(() => undefined);

  return json({ ok: true });
});
