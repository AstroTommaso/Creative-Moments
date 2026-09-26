import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { requireUser } from "@/lib/session";
import { json, withErrorHandling } from "@/lib/http";

function serialize(p: {
  environments: string[];
  environment: string;
  atmosphere: string;
  timeStyle: string;
  visualDensity: string;
  preferredInspirations: string[];
  darkMode: boolean;
  reduceMotion: boolean;
  locationEnabled: boolean;
  weatherEnabled: boolean;
  onboarded: boolean;
}) {
  return {
    environments: p.environments,
    environment: p.environment,
    atmosphere: p.atmosphere,
    timeStyle: p.timeStyle,
    visualDensity: p.visualDensity,
    preferredInspirations: p.preferredInspirations,
    darkMode: p.darkMode,
    reduceMotion: p.reduceMotion,
    locationEnabled: p.locationEnabled,
    weatherEnabled: p.weatherEnabled,
    onboarded: p.onboarded,
  };
}

export const GET = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  const prefs =
    (await prisma.userPreferences.findUnique({ where: { userId: user.id } })) ??
    (await prisma.userPreferences.create({ data: { userId: user.id } }));
  return json({ preferences: serialize(prefs) });
});

const schema = z.object({
  environments: z.array(z.string()),
  environment: z.string(),
  atmosphere: z.string(),
  timeStyle: z.enum(["auto", "dawn", "day", "sunset", "night"]),
  visualDensity: z.enum(["subtle", "balanced", "immersive"]),
  preferredInspirations: z.array(z.string()),
  darkMode: z.boolean(),
  reduceMotion: z.boolean(),
  locationEnabled: z.boolean(),
  weatherEnabled: z.boolean(),
  onboarded: z.boolean(),
});

export const PUT = withErrorHandling(async (request: Request) => {
  const user = await requireUser(request);
  const data = schema.parse(await request.json());

  const prefs = await prisma.userPreferences.upsert({
    where: { userId: user.id },
    create: { userId: user.id, ...data },
    update: data,
  });

  return json({ preferences: serialize(prefs) });
});
