import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { createSignedUrl, AVATAR_BUCKET } from "@/lib/storage";
import { json, withErrorHandling } from "@/lib/http";

async function serialize(user: { id: string; displayName: string; avatarUrl: string | null }) {
  return {
    id: user.id,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl ? await createSignedUrl(AVATAR_BUCKET, user.avatarUrl).catch(() => null) : null,
  };
}

export const GET = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  return json({ profile: await serialize(user) });
});

const schema = z.object({ displayName: z.string().trim().min(1).max(80) });

export const PUT = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  const { displayName } = schema.parse(await request.json());
  const updated = await prisma.user.update({ where: { id: user.id }, data: { displayName } });
  return json({ profile: await serialize(updated) });
});
