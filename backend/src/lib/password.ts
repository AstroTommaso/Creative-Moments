import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";

const KEY_LENGTH = 64;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1 } as const;

/** `<salt-hex>:<derived-key-hex>`, stored as User.passwordHash. */
export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const derivedKey = scryptSync(password, salt, KEY_LENGTH, SCRYPT_OPTIONS);
  return `${salt.toString("hex")}:${derivedKey.toString("hex")}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [saltHex, keyHex] = stored.split(":");
  if (!saltHex || !keyHex) return false;
  const salt = Buffer.from(saltHex, "hex");
  const expected = Buffer.from(keyHex, "hex");
  const derivedKey = scryptSync(password, salt, expected.length, SCRYPT_OPTIONS);
  return derivedKey.length === expected.length && timingSafeEqual(derivedKey, expected);
}
