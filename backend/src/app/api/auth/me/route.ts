import { requireUser } from "@/lib/session";
import { toPublicUser } from "@/lib/serializers";
import { json, withErrorHandling } from "@/lib/http";

export const GET = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  return json({ user: toPublicUser(user) });
});
