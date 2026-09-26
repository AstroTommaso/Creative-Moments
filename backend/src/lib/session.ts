import { prisma } from "./prisma";
import { ApiError } from "./http";
import type { Session, User } from "@prisma/client";

const SESSION_TTL_MS = 24 * 60 * 60 * 1000; // 24h, matches topic-universe's login token expiry
const RESET_TOKEN_TTL_MS = 60 * 60 * 1000; // 1h, matches topic-universe's reset token expiry

export function newSessionExpiry(): Date {
  return new Date(Date.now() + SESSION_TTL_MS);
}

export function newResetTokenExpiry(): Date {
  return new Date(Date.now() + RESET_TOKEN_TTL_MS);
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? request.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length).trim();
  return token.length > 0 ? token : null;
}

/** Resolves the bearer token to its session + owning user, or throws a 401 ApiError. */
export async function requireSession(request: Request): Promise<{ session: Session; user: User }> {
  const token = bearerToken(request);
  if (!token) throw new ApiError(401, "not_authenticated");

  const session = await prisma.session.findUnique({
    where: { id: token },
    include: { user: true },
  });

  if (!session || session.expiresAt < new Date()) {
    throw new ApiError(401, "not_authenticated");
  }

  const { user, ...sessionOnly } = session;
  return { session: sessionOnly, user };
}

/** Resolves the bearer token to its owning user, or throws a 401 ApiError. */
export async function requireUser(request: Request): Promise<User> {
  return (await requireSession(request)).user;
}
