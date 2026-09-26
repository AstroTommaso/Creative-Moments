import { randomUUID } from "node:crypto";
import type { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { requireOwnedMoment } from "@/lib/moments";
import { uploadObject, createSignedUrl, MEDIA_BUCKET } from "@/lib/storage";
import { json, withErrorHandling, ApiError } from "@/lib/http";

type RouteParams = { params: Promise<{ id: string }> };

const ALLOWED_TYPES = new Set(["image", "drawing", "audio"]);
const MAX_BYTES = 10 * 1024 * 1024; // matches the old moment-media bucket limit

function extensionFor(contentType: string): string {
  const [, subtype] = contentType.split("/");
  return subtype?.split("+")[0] || "bin";
}

export const POST = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id: momentId } = await params;
  await requireOwnedMoment(user.id, momentId);

  const form = await request.formData();
  const file = form.get("file");
  const type = String(form.get("type") ?? "image");
  const metadataRaw = form.get("metadata");

  if (!(file instanceof File)) throw new ApiError(400, "missing_file");
  if (!ALLOWED_TYPES.has(type)) throw new ApiError(400, "invalid_media_type");
  if (file.size > MAX_BYTES) throw new ApiError(413, "file_too_large");

  const bytes = Buffer.from(await file.arrayBuffer());
  const contentType = file.type || "application/octet-stream";
  const path = `${user.id}/${momentId}/${randomUUID()}.${extensionFor(contentType)}`;

  await uploadObject(MEDIA_BUCKET, path, bytes, contentType);

  let metadata: Prisma.InputJsonObject = {};
  if (typeof metadataRaw === "string" && metadataRaw.length > 0) {
    try {
      metadata = JSON.parse(metadataRaw);
    } catch {
      throw new ApiError(400, "invalid_metadata");
    }
  }

  const media = await prisma.media.create({
    data: { momentId, type, storagePath: path, metadata },
  });

  return json(
    {
      media: {
        id: media.id,
        momentId: media.momentId,
        type: media.type,
        storagePath: media.storagePath,
        metadata: media.metadata,
        url: await createSignedUrl(MEDIA_BUCKET, path),
      },
    },
    201,
  );
});
