import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { momentInclude, serializeMoment } from "@/lib/moments";
import { listAllForUser, removeObjects, MEDIA_BUCKET } from "@/lib/storage";
import { json, withErrorHandling } from "@/lib/http";

export const GET = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  const url = new URL(request.url);
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 500), 500);

  const moments = await prisma.moment.findMany({
    where: { userId: user.id },
    include: momentInclude,
    orderBy: { createdAt: "desc" },
    take: limit,
  });

  return json({ moments: await Promise.all(moments.map(serializeMoment)) });
});

/** Deletes every moment (and its media) belonging to the caller. */
export const DELETE = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);

  const paths = await listAllForUser(MEDIA_BUCKET, user.id);
  await prisma.moment.deleteMany({ where: { userId: user.id } });
  await removeObjects(MEDIA_BUCKET, paths).catch(() => undefined);

  return json({ ok: true });
});
