import type { User } from "@prisma/client";

export function toPublicUser(user: User) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
  };
}
