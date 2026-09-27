-- AlterTable
ALTER TABLE "Moment" ADD COLUMN     "finishedAt" TIMESTAMP(3);

-- Backfill: every moment created before this column existed was already a
-- complete moment by the app's old definition (there was no draft concept
-- yet), so treat it as finished at the moment it was created.
UPDATE "Moment" SET "finishedAt" = "createdAt" WHERE "finishedAt" IS NULL;
