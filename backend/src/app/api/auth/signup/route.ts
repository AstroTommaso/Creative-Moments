import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { hashPassword } from "@/lib/password";
import { newSessionExpiry } from "@/lib/session";
import { toPublicUser } from "@/lib/serializers";
import { json, withErrorHandling, ApiError } from "@/lib/http";

const schema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(8),
  name: z.string().trim().min(1).max(80),
});

export const POST = withErrorHandling(async (request: Request) => {
  const { email, password, name } = schema.parse(await request.json());

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) throw new ApiError(409, "email_already_registered");

  const passwordHash = await hashPassword(password);

  const { user, session } = await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: { email, passwordHash, displayName: name },
    });
    await tx.userPreferences.create({ data: { userId: user.id } });
    const session = await tx.session.create({
      data: { userId: user.id, expiresAt: newSessionExpiry() },
    });
    return { user, session };
  });

  return json({ token: session.id, user: toPublicUser(user) }, 201);
});
