# The Bit and Bond Telemetry Metrics Guide

## Quick Start
1. Make sure backend migration has run (`telemetry_events` table exists).
2. Run:

```bash
psql "$DATABASE_URL" -f docs/telemetry_dashboard_queries.sql
```

## Core KPIs
- Login success rate
  - Numerator: `auth.login.success`
  - Denominator: `auth.submit.attempt`
- Onboarding completion
  - Event: `onboarding.completed`
  - Breakdown: `properties.entry`
- DM reliability
  - `dm.text_send.success / dm.text_send.failed`
  - `dm.image_send.success / dm.image_send.failed`
  - `dm.onetime_send.success / dm.onetime_send.failed`
- Photo reliability
  - `photo.vault_upload.success / photo.vault_upload.failed`
  - `photo.onetime_open.success / photo.onetime_open.failed`
  - `photo.onetime_open.already_viewed` (consumed, not failure)

## Suggested Alert Thresholds
- Login success rate < 90% for 30 minutes
- DM text send success rate < 98% for 30 minutes
- Vault upload success rate < 95% for 30 minutes
- `status=error` with `status_code=401/403` spikes over 3x baseline

## Event Source Notes
- Pre-login events use `/api/v1/telemetry/public-events`
- Authenticated events use `/api/v1/telemetry/events`
- `status='consumed'` means expected one-time behavior, not system failure
