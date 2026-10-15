/*
  Warnings:

  - You are about to drop the column `time_range` on the `appointments` table. All the data in the column will be lost.

*/
-- AlterEnum
ALTER TYPE "CalendarConnectionStatus" ADD VALUE 'NEEDS_RECONNECT';

-- AlterTable
ALTER TABLE "appointments" DROP COLUMN "time_range";

-- AlterTable
ALTER TABLE "calendar_connections" ADD COLUMN     "calendar_name" VARCHAR(200);

-- CreateTable
CREATE TABLE "calendar_oauth_states" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "state_hash" VARCHAR(128) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "calendar_oauth_states_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "calendar_oauth_states_state_hash_key" ON "calendar_oauth_states"("state_hash");

-- CreateIndex
CREATE INDEX "calendar_oauth_states_artist_id_expires_at_idx" ON "calendar_oauth_states"("artist_id", "expires_at");

-- AddForeignKey
ALTER TABLE "calendar_oauth_states" ADD CONSTRAINT "calendar_oauth_states_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
