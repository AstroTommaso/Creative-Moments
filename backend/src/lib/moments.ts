import { prisma } from "./prisma";
import { ApiError } from "./http";
import { createSignedUrl, MEDIA_BUCKET } from "./storage";
import type { Prisma } from "@prisma/client";

export const momentInclude = {
  creations: true,
  inspirations: true,
  prompts: { include: { answers: true } },
  media: true,
} satisfies Prisma.MomentInclude;

export type MomentWithRelations = Prisma.MomentGetPayload<{ include: typeof momentInclude }>;

/** Loads a moment and throws 404 unless it belongs to `userId`. */
export async function requireOwnedMoment(userId: string, momentId: string): Promise<MomentWithRelations> {
  const moment = await prisma.moment.findUnique({
    where: { id: momentId },
    include: momentInclude,
  });
  if (!moment || moment.userId !== userId) throw new ApiError(404, "moment_not_found");
  return moment;
}

export async function serializeMoment(moment: MomentWithRelations) {
  const media = await Promise.all(
    moment.media.map(async (m) => ({
      id: m.id,
      momentId: m.momentId,
      type: m.type,
      storagePath: m.storagePath,
      metadata: m.metadata,
      url: await createSignedUrl(MEDIA_BUCKET, m.storagePath).catch(() => null),
    })),
  );

  return {
    id: moment.id,
    userId: moment.userId,
    title: moment.title,
    creationType: moment.creationType,
    mood: moment.mood,
    atmosphere: moment.atmosphere,
    timeOfDay: moment.timeOfDay,
    locationName: moment.locationName,
    latitude: moment.latitude,
    longitude: moment.longitude,
    musicTitle: moment.musicTitle,
    musicArtist: moment.musicArtist,
    musicAlbum: moment.musicAlbum,
    musicArtworkUrl: moment.musicArtworkUrl,
    createdAt: moment.createdAt,
    updatedAt: moment.updatedAt,
    finishedAt: moment.finishedAt,
    creations: moment.creations.map((c) => ({
      id: c.id,
      momentId: c.momentId,
      type: c.type,
      textContent: c.textContent,
      drawingData: c.drawingData,
      createdAt: c.createdAt,
    })),
    inspirations: moment.inspirations.map((i) => ({ type: i.type, name: i.name })),
    prompts: moment.prompts.map((p) => ({
      id: p.id,
      question: p.question,
      answer: p.answers[0]?.answer ?? null,
    })),
    media,
  };
}
