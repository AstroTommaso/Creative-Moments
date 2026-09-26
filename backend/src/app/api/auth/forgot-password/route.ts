import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { newResetTokenExpiry } from "@/lib/session";
import { sendPasswordResetEmail } from "@/lib/email";
import { json, withErrorHandling } from "@/lib/http";

const schema = z.object({ email: z.string().trim().toLowerCase().email() });

export const POST = withErrorHandling(async (request: Request) => {
  const { email } = schema.parse(await request.json());

  const user = await prisma.user.findUnique({ where: { email } });
  // Always respond the same way whether or not the account exists, so this
  // endpoint can't be used to discover which emails are registered.
  if (user) {
    const token = await prisma.authToken.create({
      data: { userId: user.id, expiresAt: newResetTokenExpiry() },
    });
    const resetUrl = `${process.env.APP_BASE_URL}/reset-password?token=${token.id}`;
    await sendPasswordResetEmail(user.email, resetUrl);
  }

  return json({ message: "check_your_email" });
});
