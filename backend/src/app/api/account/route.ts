import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { listAllForUser, removeObjects, MEDIA_BUCKET, AVATAR_BUCKET } from "@/lib/storage";
import { json, withErrorHandling } from "@/lib/http";

/**
 * Deletes the caller's storage files first (both buckets), then the User
 * row — Prisma's onDelete: Cascade removes every dependent row (moments and
 * everything under them, preferences, sessions, tokens) in one transaction.
 */
export const DELETE = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);

  const [mediaPaths, avatarPaths] = await Promise.all([
    listAllForUser(MEDIA_BUCKET, user.id),
    listAllForUser(AVATAR_BUCKET, user.id),
  ]);
  await Promise.all([
    removeObjects(MEDIA_BUCKET, mediaPaths).catch(() => undefined),
    removeObjects(AVATAR_BUCKET, avatarPaths).catch(() => undefined),
  ]);

  await prisma.user.delete({ where: { id: user.id } });

  return json({ ok: true });
});
