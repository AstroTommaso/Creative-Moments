import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { verifyPassword } from "@/lib/password";
import { newSessionExpiry } from "@/lib/session";
import { toPublicUser } from "@/lib/serializers";
import { json, withErrorHandling, ApiError } from "@/lib/http";

const schema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

export const POST = withErrorHandling(async (request: Request) => {
  const { email, password } = schema.parse(await request.json());

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await verifyPassword(password, user.passwordHash))) {
    throw new ApiError(401, "invalid_credentials");
  }

  const session = await prisma.session.create({
    data: { userId: user.id, expiresAt: newSessionExpiry() },
  });

  return json({ token: session.id, user: toPublicUser(user) });
});
