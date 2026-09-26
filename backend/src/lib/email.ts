import nodemailer from "nodemailer";

function transport() {
  const host = process.env.SMTP_HOST;
  if (!host) return null; // dev mode: log instead of sending

  return nodemailer.createTransport({
    host,
    port: Number(process.env.SMTP_PORT ?? 587),
    secure: Number(process.env.SMTP_PORT) === 465,
    auth: process.env.SMTP_USER
      ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
      : undefined,
  });
}

export async function sendPasswordResetEmail(to: string, resetUrl: string) {
  const body = `Someone requested a password reset for this account.\n\nOpen this link to choose a new password (it expires in 1 hour):\n${resetUrl}\n\nIf you didn't request this, you can ignore this email.`;

  const client = transport();
  if (!client) {
    console.log(`[DEV EMAIL] To: ${to}\nSubject: Reset your Creative Moments password\n\n${body}`);
    return;
  }

  await client.sendMail({
    from: process.env.SMTP_FROM ?? "noreply@creativemoments.app",
    to,
    subject: "Reset your Creative Moments password",
    text: body,
  });
}
