import { createClient } from "@supabase/supabase-js";

export const MEDIA_BUCKET = "moment-media";
export const AVATAR_BUCKET = "avatars";

let client: ReturnType<typeof createClient> | null = null;

/**
 * Server-only Supabase client authenticated with the service_role key.
 * This bypasses Storage RLS entirely, so every caller in this codebase MUST
 * check ownership itself before touching a path — see each route handler.
 */
function storageClient() {
  if (client) return client;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not configured");
  }
  client = createClient(url, key, { auth: { persistSession: false } });
  return client;
}

export async function uploadObject(
  bucket: string,
  path: string,
  bytes: Buffer,
  contentType: string,
) {
  const { error } = await storageClient()
    .storage.from(bucket)
    .upload(path, bytes, { contentType, upsert: true });
  if (error) throw error;
}

export async function removeObjects(bucket: string, paths: string[]) {
  if (paths.length === 0) return;
  const { error } = await storageClient().storage.from(bucket).remove(paths);
  if (error) throw error;
}

export async function createSignedUrl(bucket: string, path: string, expiresInSeconds = 3600) {
  const { data, error } = await storageClient()
    .storage.from(bucket)
    .createSignedUrl(path, expiresInSeconds);
  if (error) throw error;
  return data.signedUrl;
}

/** Recursively lists every object path under `<userId>/` in `bucket`. */
export async function listAllForUser(bucket: string, userId: string): Promise<string[]> {
  const paths: string[] = [];
  const walk = async (folder: string) => {
    const { data, error } = await storageClient()
      .storage.from(bucket)
      .list(folder, { limit: 1000 });
    if (error) throw error;
    for (const entry of data ?? []) {
      const entryPath = `${folder}/${entry.name}`;
      if (entry.id === null) {
        // A "directory" placeholder (no id) — recurse into it.
        await walk(entryPath);
      } else {
        paths.push(entryPath);
      }
    }
  };
  await walk(userId);
  return paths;
}
