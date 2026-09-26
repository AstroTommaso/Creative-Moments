import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { hashPassword } from "@/lib/password";
import { json, withErrorHandling, ApiError } from "@/lib/http";

const schema = z.object({
  token: z.string().min(1),
  password: z.string().min(8),
});

export const POST = withErrorHandling(async (request: Request) => {
  const { token, password } = schema.parse(await request.json());

  const authToken = await prisma.authToken.findUnique({ where: { id: token } });
  if (!authToken || authToken.usedAt || authToken.expiresAt < new Date()) {
    throw new ApiError(400, "invalid_or_expired_token");
  }

  const passwordHash = await hashPassword(password);

  await prisma.$transaction([
    prisma.user.update({ where: { id: authToken.userId }, data: { passwordHash } }),
    prisma.authToken.update({ where: { id: authToken.id }, data: { usedAt: new Date() } }),
    // Force logout everywhere: a leaked old session shouldn't survive a reset.
    prisma.session.deleteMany({ where: { userId: authToken.userId } }),
  ]);

  return json({ ok: true });
});
