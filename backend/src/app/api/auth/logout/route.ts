import { prisma } from "@/lib/prisma";
import { requireSession } from "@/lib/session";
import { json, withErrorHandling } from "@/lib/http";

export const POST = withErrorHandling(async (request: Request) => {
  const { session } = await requireSession(request);
  await prisma.session.delete({ where: { id: session.id } });
  return json({ ok: true });
});
