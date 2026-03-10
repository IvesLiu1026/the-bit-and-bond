-- The Bit and Bond Telemetry Dashboard Queries
-- Usage:
--   psql "$DATABASE_URL" -f docs/telemetry_dashboard_queries.sql
--
-- Default analysis window: last 14 days.

WITH params AS (
  SELECT
    now() - interval '14 days' AS start_at,
    now() AS end_at
),
events AS (
  SELECT
    occurred_at,
    event_name,
    status,
    source,
    platform,
    locale,
    app_version,
    session_id,
    guild_id,
    hunter_id,
    properties_json::jsonb AS properties
  FROM telemetry_events
  CROSS JOIN params
  WHERE occurred_at >= params.start_at
    AND occurred_at < params.end_at
)
SELECT 'window' AS section, start_at, end_at FROM params;

-- 1) Login conversion (daily)
WITH params AS (
  SELECT now() - interval '14 days' AS start_at, now() AS end_at
),
events AS (
  SELECT occurred_at, event_name
  FROM telemetry_events
  CROSS JOIN params
  WHERE occurred_at >= params.start_at
    AND occurred_at < params.end_at
)
SELECT
  date_trunc('day', occurred_at) AS day,
  COUNT(*) FILTER (WHERE event_name = 'auth.submit.attempt') AS auth_attempts,
  COUNT(*) FILTER (WHERE event_name = 'auth.login.success') AS login_success,
  COUNT(*) FILTER (WHERE event_name = 'auth.login.failed') AS login_failed,
  COUNT(*) FILTER (WHERE event_name = 'auth.register.success') AS register_success,
  COUNT(*) FILTER (WHERE event_name = 'auth.register.failed') AS register_failed,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE event_name = 'auth.login.success')
    / NULLIF(COUNT(*) FILTER (WHERE event_name = 'auth.submit.attempt'), 0),
    2
  ) AS login_success_rate_pct
FROM events
GROUP BY 1
ORDER BY 1;

-- 2) Onboarding completion split by entry mode
WITH params AS (
  SELECT now() - interval '14 days' AS start_at, now() AS end_at
),
events AS (
  SELECT properties_json::jsonb AS properties
  FROM telemetry_events
  CROSS JOIN params
  WHERE event_name = 'onboarding.completed'
    AND occurred_at >= params.start_at
    AND occurred_at < params.end_at
)
SELECT
  COALESCE(properties ->> 'entry', 'unknown') AS entry_mode,
  COUNT(*) AS completed_count
FROM events
GROUP BY 1
ORDER BY 2 DESC;

-- 3) DM reliability summary
WITH params AS (
  SELECT now() - interval '14 days' AS start_at, now() AS end_at
),
events AS (
  SELECT event_name, occurred_at
  FROM telemetry_events
  CROSS JOIN params
  WHERE occurred_at >= params.start_at
    AND occurred_at < params.end_at
)
SELECT
  date_trunc('day', occurred_at) AS day,
  COUNT(*) FILTER (WHERE event_name = 'dm.text_send.success') AS dm_text_success,
  COUNT(*) FILTER (WHERE event_name = 'dm.text_send.failed') AS dm_text_failed,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE event_name = 'dm.text_send.success')
    / NULLIF(
      COUNT(*) FILTER (
        WHERE event_name IN ('dm.text_send.success', 'dm.text_send.failed')
      ),
      0
    ),
    2
  ) AS dm_text_success_rate_pct,
  COUNT(*) FILTER (WHERE event_name = 'dm.image_send.success') AS dm_image_success,
  COUNT(*) FILTER (WHERE event_name = 'dm.image_send.failed') AS dm_image_failed,
  COUNT(*) FILTER (WHERE event_name = 'dm.onetime_send.success') AS dm_onetime_success,
  COUNT(*) FILTER (WHERE event_name = 'dm.onetime_send.failed') AS dm_onetime_failed
FROM events
GROUP BY 1
ORDER BY 1;

-- 4) Photo upload/open reliability summary
WITH params AS (
  SELECT now() - interval '14 days' AS start_at, now() AS end_at
),
events AS (
  SELECT event_name, occurred_at
  FROM telemetry_events
  CROSS JOIN params
  WHERE occurred_at >= params.start_at
    AND occurred_at < params.end_at
)
SELECT
  date_trunc('day', occurred_at) AS day,
  COUNT(*) FILTER (WHERE event_name = 'photo.vault_upload.success') AS vault_upload_success,
  COUNT(*) FILTER (WHERE event_name = 'photo.vault_upload.failed') AS vault_upload_failed,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE event_name = 'photo.vault_upload.success')
    / NULLIF(
      COUNT(*) FILTER (
        WHERE event_name IN ('photo.vault_upload.success', 'photo.vault_upload.failed')
      ),
      0
    ),
    2
  ) AS vault_upload_success_rate_pct,
  COUNT(*) FILTER (WHERE event_name = 'photo.onetime_send.success') AS onetime_send_success,
  COUNT(*) FILTER (WHERE event_name = 'photo.onetime_send.failed') AS onetime_send_failed,
  COUNT(*) FILTER (WHERE event_name = 'photo.onetime_open.success') AS onetime_open_success,
  COUNT(*) FILTER (WHERE event_name = 'photo.onetime_open.failed') AS onetime_open_failed,
  COUNT(*) FILTER (WHERE event_name = 'photo.onetime_open.already_viewed') AS onetime_open_consumed
FROM events
GROUP BY 1
ORDER BY 1;

-- 5) Top failure codes (helps triage API regressions quickly)
WITH params AS (
  SELECT now() - interval '14 days' AS start_at, now() AS end_at
),
failed_events AS (
  SELECT
    event_name,
    CASE
      WHEN properties_json::jsonb ? 'status_code'
           AND (properties_json::jsonb ->> 'status_code') ~ '^[0-9]+$'
      THEN (properties_json::jsonb ->> 'status_code')::int
      ELSE NULL
    END AS status_code
  FROM telemetry_events
  CROSS JOIN params
  WHERE occurred_at >= params.start_at
    AND occurred_at < params.end_at
    AND status = 'error'
)
SELECT
  event_name,
  COALESCE(status_code, -1) AS status_code,
  COUNT(*) AS fail_count
FROM failed_events
GROUP BY 1, 2
ORDER BY fail_count DESC, event_name, status_code
LIMIT 50;
