import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { requireOwnedMoment } from "@/lib/moments";
import { json, withErrorHandling } from "@/lib/http";

type RouteParams = { params: Promise<{ id: string }> };

const schema = z.object({
  inspirations: z.array(z.object({ type: z.string(), name: z.string() })),
  prompts: z.array(
    z.object({ id: z.string(), question: z.string(), answer: z.string().nullish() }),
  ),
});

/**
 * Atomically replaces a moment's inspirations and prompts/answers.
 * Mirrors the old `save_moment_details` Postgres function: full delete then
 * re-insert, deduping inspirations on (momentId, type, name) and only
 * storing an answer when it's non-blank after trimming.
 */
export const PUT = withErrorHandling(async (request: Request, { params }: RouteParams) => {
  const user = await requireUser(request);
  const { id } = await params;
  await requireOwnedMoment(user.id, id); // 404s if not owned

  const { inspirations, prompts } = schema.parse(await request.json());

  await prisma.$transaction(async (tx) => {
    await tx.inspiration.deleteMany({ where: { momentId: id } });
    await tx.prompt.deleteMany({ where: { momentId: id } }); // cascades to answers

    if (inspirations.length > 0) {
      await tx.inspiration.createMany({
        data: inspirations.map((i) => ({ momentId: id, type: i.type, name: i.name })),
        skipDuplicates: true,
      });
    }

    for (const p of prompts) {
      await tx.prompt.create({ data: { id: p.id, momentId: id, question: p.question } });
      const answer = p.answer?.trim();
      if (answer) {
        await tx.answer.create({ data: { promptId: p.id, answer } });
      }
    }
  });

  return json({ ok: true });
});
