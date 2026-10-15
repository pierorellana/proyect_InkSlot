ALTER TABLE "clients" ADD COLUMN "artist_id" UUID;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "clients" WHERE "artist_id" IS NULL) THEN
    RAISE EXCEPTION 'clients.artist_id requires an explicit owner before migration';
  END IF;
END $$;

ALTER TABLE "clients" ALTER COLUMN "artist_id" SET NOT NULL;
ALTER TABLE "clients"
  ADD CONSTRAINT "clients_artist_id_fkey"
  FOREIGN KEY ("artist_id") REFERENCES "artists"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
CREATE INDEX "clients_artist_id_created_at_idx" ON "clients"("artist_id", "created_at");
