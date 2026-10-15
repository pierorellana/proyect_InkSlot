-- Restore the SQL-only appointment invariant that is intentionally outside Prisma's schema.
CREATE EXTENSION IF NOT EXISTS btree_gist;

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
