# Modelo lógico PostgreSQL

| Tabla | Campos clave / constraints |
|---|---|
| `artists` | `id uuid PK`, `email unique`, `password_hash`, `display_name`, `active` |
| `studio_settings` | `artist_id FK unique`, `timezone`, `slot_step_minutes`, `buffer_minutes`, `minimum_notice_hours`, `horizon_days` |
| `weekly_availability` | `id`, `artist_id`, `weekday 0..6`, `start_local time`, `end_local time`, `check(start<end)` |
| `availability_blocks` | `id`, `artist_id`, `start_at timestamptz`, `end_at`, `reason`, `check(start<end)` |
| `clients` | `id`, `name`, `email?`, `phone?`, `created_at` |
| `booking_requests` | `id`, `artist_id`, `client_id`, `deposit_verified_at`, `deposit_verified_by`, `duration_minutes`, `status`, `min_date?`, `max_date?`, `allowed_weekdays jsonb?`, `allowed_windows jsonb?`, `created_at`, `version` |
| `booking_tokens` | `id`, `request_id`, `token_hash unique`, `expires_at`, `revoked_at?`, `consumed_at?`, `created_at` |
| `appointments` | `id`, `request_id`, `artist_id`, `start_at`, `end_at`, `status`, `sync_status`, `version`, `created_at` |
| `calendar_connections` | `id`, `artist_id`, `calendar_id`, `encrypted_refresh_token`, `status`, `connected_at`, `updated_at` |
| `calendar_events` | `id`, `appointment_id unique`, `calendar_id`, `external_event_id unique`, `etag?`, `last_synced_at?` |
| `outbox_events` | `id`, `aggregate_id`, `type`, `payload jsonb`, `status`, `attempts`, `next_attempt_at`, `created_at` |
| `sync_issues` | `id`, `appointment_id`, `operation`, `code`, `message_safe`, `status`, `last_attempt_at` |
| `audit_logs` | `id`, `actor_type`, `actor_id?`, `entity_type`, `entity_id`, `action`, `changes jsonb`, `created_at` |
| `idempotency_keys` | `key_hash`, `scope`, `request_hash`, `response_code`, `response_body jsonb`, `created_at`, `expires_at`; unique `(scope,key_hash)` |

## Prevención real de conflictos
Postgres `btree_gist`; columna `time_range tstzrange GENERATED ALWAYS AS (tstzrange(start_at,end_at,'[)')) STORED`; `EXCLUDE USING gist (artist_id WITH =, time_range WITH &&) WHERE (status IN ('confirmed','completed','no_show'))` — revisar si estados terminales deben reservar históricamente el mismo espacio antes de migración; opción recomendada: incluir todos salvo `cancelled` para preservar consistencia histórica. Testear con dos transacciones concurrentes. No depender solo de lock en app.

**Decisión pendiente:** ORM (Prisma/TypeORM) y política de retención/PII, consultar `open-questions.md`.
