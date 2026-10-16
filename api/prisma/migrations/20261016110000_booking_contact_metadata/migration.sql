ALTER TABLE "clients"
  ADD COLUMN "contact_channel" VARCHAR(32),
  ADD COLUMN "contact_value" VARCHAR(320);

ALTER TABLE "booking_requests"
  ADD COLUMN "payment_reference" VARCHAR(160);
