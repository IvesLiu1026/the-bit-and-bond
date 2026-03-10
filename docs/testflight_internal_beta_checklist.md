# The Bit and Bond TestFlight Internal Beta Checklist

## Scope
- Target build: latest `main` commit with CI green.
- Audience: 5-10 internal testers (family scenario first).
- Duration: 3-7 days.

## Must-pass Journeys
1. New user onboarding
- Greeting tap -> customization -> contract.
- Google sign-in success path.
- Manual register/login fallback path.

2. Core social messaging
- DM text send and receive.
- DM image send and display.
- One-time image send, first open success, second open consumed state.

3. Shared life systems
- Voice room join/leave.
- Habit challenge create -> submit proof -> review approve/reject.
- Reward/coin changes reflected in profile and inventory.

## Crash and UX Gates
- No crash on auth refresh/expired token.
- No blocking overflow on 390x844 and 844x390.
- No permanent loading state in DM inbox/chat/photo tabs.

## Telemetry Gates
- Login conversion can be computed from:
  - `auth.submit.attempt`
  - `auth.login.success` / `auth.login.failed`
- Onboarding completion can be computed from:
  - `onboarding.completed`
- Messaging reliability can be computed from:
  - `dm.text_send.success` / `dm.text_send.failed`
  - `dm.image_send.success` / `dm.image_send.failed`
  - `dm.onetime_send.success` / `dm.onetime_send.failed`
- Photo reliability can be computed from:
  - `photo.vault_upload.success` / `photo.vault_upload.failed`
  - `photo.onetime_open.success` / `photo.onetime_open.failed` / `photo.onetime_open.already_viewed`

## Exit Criteria
- P0 defects: 0
- P1 defects: <= 2 and workaround available
- Key success rates after at least 100 events:
  - login success rate >= 90%
  - DM text send success rate >= 98%
  - photo vault upload success rate >= 95%
