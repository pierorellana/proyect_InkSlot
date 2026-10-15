/*
  Warnings:

  - Added the required column `password_hash` to the `artists` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "BookingRequestStatus" AS ENUM ('PENDING', 'BOOKED', 'CANCELLED', 'EXPIRED', 'CLOSED');

-- CreateEnum
CREATE TYPE "AppointmentStatus" AS ENUM ('CONFIRMED', 'COMPLETED', 'CANCELLED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "SyncStatus" AS ENUM ('PENDING', 'SYNCED', 'FAILED');

-- CreateEnum
CREATE TYPE "CalendarConnectionStatus" AS ENUM ('CONNECTED', 'DISCONNECTED', 'ERROR');

-- CreateEnum
CREATE TYPE "OutboxStatus" AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "SyncIssueStatus" AS ENUM ('OPEN', 'RESOLVED');

-- CreateEnum
CREATE TYPE "ActorType" AS ENUM ('ADMIN', 'SYSTEM', 'PUBLIC');

-- AlterTable
ALTER TABLE "artists" ADD COLUMN     "password_hash" VARCHAR(255) NOT NULL;

-- CreateTable
CREATE TABLE "studio_settings" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "timezone" VARCHAR(64) NOT NULL,
    "slot_step_minutes" INTEGER NOT NULL DEFAULT 30,
    "buffer_minutes" INTEGER NOT NULL DEFAULT 0,
    "minimum_notice_hours" INTEGER NOT NULL DEFAULT 0,
    "horizon_days" INTEGER NOT NULL DEFAULT 60,

    CONSTRAINT "studio_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "weekly_availability" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "weekday" INTEGER NOT NULL,
    "start_local" TIME(6) NOT NULL,
    "end_local" TIME(6) NOT NULL,

    CONSTRAINT "weekly_availability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "availability_blocks" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL,
    "end_at" TIMESTAMPTZ(6) NOT NULL,
    "reason" VARCHAR(240),

    CONSTRAINT "availability_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clients" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "email" VARCHAR(320),
    "phone" VARCHAR(32),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_requests" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "client_id" UUID NOT NULL,
    "deposit_verified_at" TIMESTAMPTZ(6),
    "deposit_verified_by" UUID,
    "duration_minutes" INTEGER NOT NULL,
    "status" "BookingRequestStatus" NOT NULL DEFAULT 'PENDING',
    "min_date" DATE,
    "max_date" DATE,
    "allowed_weekdays" JSONB,
    "allowed_windows" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "booking_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "booking_tokens" (
    "id" UUID NOT NULL,
    "request_id" UUID NOT NULL,
    "token_hash" VARCHAR(128) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "booking_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "appointments" (
    "id" UUID NOT NULL,
    "request_id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL,
    "end_at" TIMESTAMPTZ(6) NOT NULL,
    "status" "AppointmentStatus" NOT NULL DEFAULT 'CONFIRMED',
    "sync_status" "SyncStatus" NOT NULL DEFAULT 'PENDING',
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "appointments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "calendar_connections" (
    "id" UUID NOT NULL,
    "artist_id" UUID NOT NULL,
    "calendar_id" VARCHAR(320) NOT NULL,
    "encrypted_refresh_token" TEXT NOT NULL,
    "status" "CalendarConnectionStatus" NOT NULL DEFAULT 'DISCONNECTED',
    "connected_at" TIMESTAMPTZ(6),
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "calendar_connections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "calendar_events" (
    "id" UUID NOT NULL,
    "appointment_id" UUID NOT NULL,
    "calendar_id" VARCHAR(320) NOT NULL,
    "external_event_id" VARCHAR(320) NOT NULL,
    "etag" VARCHAR(320),
    "last_synced_at" TIMESTAMPTZ(6),

    CONSTRAINT "calendar_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_events" (
    "id" UUID NOT NULL,
    "aggregate_id" UUID NOT NULL,
    "type" VARCHAR(120) NOT NULL,
    "payload" JSONB NOT NULL,
    "status" "OutboxStatus" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sync_issues" (
    "id" UUID NOT NULL,
    "appointment_id" UUID NOT NULL,
    "operation" VARCHAR(32) NOT NULL,
    "code" VARCHAR(64) NOT NULL,
    "message_safe" VARCHAR(500) NOT NULL,
    "status" "SyncIssueStatus" NOT NULL DEFAULT 'OPEN',
    "last_attempt_at" TIMESTAMPTZ(6),

    CONSTRAINT "sync_issues_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "actor_type" "ActorType" NOT NULL,
    "actor_id" UUID,
    "entity_type" VARCHAR(80) NOT NULL,
    "entity_id" UUID NOT NULL,
    "action" VARCHAR(80) NOT NULL,
    "changes" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_keys" (
    "id" UUID NOT NULL,
    "key_hash" VARCHAR(128) NOT NULL,
    "scope" VARCHAR(160) NOT NULL,
    "request_hash" VARCHAR(128) NOT NULL,
    "response_code" INTEGER NOT NULL,
    "response_body" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "studio_settings_artist_id_key" ON "studio_settings"("artist_id");

-- CreateIndex
CREATE INDEX "weekly_availability_artist_id_weekday_idx" ON "weekly_availability"("artist_id", "weekday");

-- CreateIndex
CREATE INDEX "availability_blocks_artist_id_start_at_end_at_idx" ON "availability_blocks"("artist_id", "start_at", "end_at");

-- CreateIndex
CREATE INDEX "booking_requests_artist_id_status_idx" ON "booking_requests"("artist_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "booking_tokens_token_hash_key" ON "booking_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "booking_tokens_request_id_expires_at_idx" ON "booking_tokens"("request_id", "expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "appointments_request_id_key" ON "appointments"("request_id");

-- CreateIndex
CREATE INDEX "appointments_artist_id_start_at_idx" ON "appointments"("artist_id", "start_at");

-- CreateIndex
CREATE UNIQUE INDEX "calendar_connections_artist_id_key" ON "calendar_connections"("artist_id");

-- CreateIndex
CREATE UNIQUE INDEX "calendar_events_appointment_id_key" ON "calendar_events"("appointment_id");

-- CreateIndex
CREATE UNIQUE INDEX "calendar_events_external_event_id_key" ON "calendar_events"("external_event_id");

-- CreateIndex
CREATE INDEX "outbox_events_status_next_attempt_at_idx" ON "outbox_events"("status", "next_attempt_at");

-- CreateIndex
CREATE INDEX "sync_issues_status_last_attempt_at_idx" ON "sync_issues"("status", "last_attempt_at");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_created_at_idx" ON "audit_logs"("entity_type", "entity_id", "created_at");

-- CreateIndex
CREATE INDEX "idempotency_keys_expires_at_idx" ON "idempotency_keys"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "idempotency_keys_scope_key_hash_key" ON "idempotency_keys"("scope", "key_hash");

-- AddForeignKey
ALTER TABLE "studio_settings" ADD CONSTRAINT "studio_settings_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "weekly_availability" ADD CONSTRAINT "weekly_availability_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "availability_blocks" ADD CONSTRAINT "availability_blocks_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_requests" ADD CONSTRAINT "booking_requests_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "booking_tokens" ADD CONSTRAINT "booking_tokens_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "booking_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_request_id_fkey" FOREIGN KEY ("request_id") REFERENCES "booking_requests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "appointments" ADD CONSTRAINT "appointments_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calendar_connections" ADD CONSTRAINT "calendar_connections_artist_id_fkey" FOREIGN KEY ("artist_id") REFERENCES "artists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sync_issues" ADD CONSTRAINT "sync_issues_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- PostgreSQL invariants that are intentionally kept in SQL instead of the ORM schema.
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "studio_settings"
ADD CONSTRAINT "studio_settings_positive_values_check"
CHECK (
  "slot_step_minutes" > 0
  AND "buffer_minutes" >= 0
  AND "minimum_notice_hours" >= 0
  AND "horizon_days" > 0
);

ALTER TABLE "weekly_availability"
ADD CONSTRAINT "weekly_availability_valid_range_check"
CHECK ("weekday" BETWEEN 0 AND 6 AND "start_local" < "end_local");

ALTER TABLE "availability_blocks"
ADD CONSTRAINT "availability_blocks_valid_range_check"
CHECK ("start_at" < "end_at");

ALTER TABLE "booking_requests"
ADD CONSTRAINT "booking_requests_positive_duration_check"
CHECK ("duration_minutes" > 0),
ADD CONSTRAINT "booking_requests_valid_date_window_check"
CHECK ("min_date" IS NULL OR "max_date" IS NULL OR "min_date" <= "max_date");

ALTER TABLE "booking_tokens"
ADD CONSTRAINT "booking_tokens_non_empty_hash_check"
CHECK (char_length("token_hash") >= 32);

ALTER TABLE "appointments"
ADD CONSTRAINT "appointments_valid_range_check"
CHECK ("start_at" < "end_at");

ALTER TABLE "appointments"
ADD COLUMN "time_range" tstzrange
GENERATED ALWAYS AS (tstzrange("start_at", "end_at", '[)'::text)) STORED;

ALTER TABLE "appointments"
ADD CONSTRAINT "appointments_no_overlap"
EXCLUDE USING GIST (
  "artist_id" WITH =,
  "time_range" WITH &&
)
WHERE ("status" IN (
  'CONFIRMED'::"AppointmentStatus",
  'COMPLETED'::"AppointmentStatus",
  'NO_SHOW'::"AppointmentStatus"
));
