# Creative Moments API

Custom backend for the Creative Moments app: authentication (signup, login,
password reset), and all app data (moments, photos/drawings, preferences,
profile). Replaces the previous direct-to-Supabase-Auth/RLS design — this
backend is now the only thing that talks to the database and to Storage; the
Flutter app talks only to this API over HTTP with a bearer token.

Stack: Next.js (App Router) + TypeScript + Prisma + scrypt password hashing +
Nodemailer + Supabase Storage (via the `service_role` key, server-side only).

## Prerequisites

- Node.js 22+
- A Postgres database — this project points at the existing Supabase
  project's Postgres instance, used **only as raw Postgres** (not through
  Supabase Auth/RLS/PostgREST)

## One-time setup on the existing Supabase project

The Supabase project already has tables created by hand (the old
`supabase/migrations/*.sql`, now removed from this repo). Prisma needs to
own the schema from scratch, so **before the first `prisma migrate deploy`**,
reset the public schema on that project (Dashboard → SQL Editor):

```sql
drop schema public cascade;
create schema public;
grant all on schema public to postgres;
grant all on schema public to public;
```

There is no real user data in that project yet, so this is safe. Do this
once, before ever running Prisma migrations against it.

## Environment variables

Copy `.env.example` to `.env` and fill in:

| Variable | Meaning |
| --- | --- |
| `DATABASE_URL` | Pooled Postgres connection (port 6543, `pgbouncer=true`) — used at runtime |
| `DIRECT_URL` | Direct Postgres connection (port 5432) — used only by `prisma migrate` |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Project Settings → API → `service_role` key. **Never** expose this to any client |
| `APP_BASE_URL` | Public URL of this backend once deployed (used in password-reset email links) |
| `SMTP_*` | Optional; leave empty in development, emails are logged to the console instead |

Both Supabase Storage buckets (`moment-media`, `avatars`) created by the old
migrations can stay as-is — this backend uses them directly via the
service_role key. Their Storage RLS policies are now dead weight (the
service_role key bypasses RLS by design); all per-user protection is
enforced by this backend's own code (every route checks resource ownership
before returning or writing anything).

## Running locally

```bash
npm install
npx prisma generate
npx prisma migrate deploy   # or `migrate dev` against a fresh/local Postgres
npm run dev
```

## Testing

```bash
npm run typecheck
npm run build
npm test              # unit tests (vitest)
```

The auth + moments + preferences flow was manually smoke-tested end-to-end
against a local, throwaway Postgres 16 instance (signup, login, wrong
password rejection, preferences auto-creation, moment upsert, save-details
dedupe, unauthenticated rejection, forgot/reset-password including token
single-use and session invalidation). It was **not** tested against the
real Supabase project or with real Storage uploads — that needs network
access to Supabase and real credentials, neither available in the sandbox
this was built in.

## Deploying (Railway)

1. Create a new Railway project from this `backend/` directory (or point it
   at this repo with a root directory of `backend`).
2. Set all the environment variables above in Railway's dashboard.
3. Run `npx prisma migrate deploy` against the real database once (either
   from your machine with `DATABASE_URL`/`DIRECT_URL` pointed at Supabase,
   or as a Railway release command).
4. Deploy. `APP_BASE_URL` must match the public Railway URL (or custom
   domain) so password-reset email links work.

## API

See the route handlers under `src/app/api/` — each file documents the
endpoint it implements. In short:

- `POST /api/auth/{signup,login,logout,forgot-password,reset-password}`,
  `GET /api/auth/me`
- `GET/DELETE /api/moments`, `GET/PUT/DELETE /api/moments/:id`,
  `PUT /api/moments/:id/details`, `POST /api/moments/:id/media`
- `DELETE /api/media/:id`
- `GET/PUT /api/preferences`
- `GET/PUT /api/profile`, `POST /api/profile/avatar`
- `DELETE /api/account`

All endpoints except `/api/auth/*` and the `reset-password` page require
`Authorization: Bearer <token>`, where `<token>` is the value returned by
signup/login.
