import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { uploadObject, createSignedUrl, AVATAR_BUCKET } from "@/lib/storage";
import { json, withErrorHandling, ApiError } from "@/lib/http";

const MAX_BYTES = 3 * 1024 * 1024; // matches the old avatars bucket limit

function extensionFor(contentType: string): string {
  const [, subtype] = contentType.split("/");
  return subtype?.split("+")[0] || "bin";
}

export const POST = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);

  const form = await request.formData();
  const file = form.get("file");
  if (!(file instanceof File)) throw new ApiError(400, "missing_file");
  if (file.size > MAX_BYTES) throw new ApiError(413, "file_too_large");

  const bytes = Buffer.from(await file.arrayBuffer());
  const contentType = file.type || "application/octet-stream";
  const path = `${user.id}/avatar/avatar.${extensionFor(contentType)}`;

  await uploadObject(AVATAR_BUCKET, path, bytes, contentType);
  await prisma.user.update({ where: { id: user.id }, data: { avatarUrl: path } });

  return json({ avatarUrl: await createSignedUrl(AVATAR_BUCKET, path) });
});
