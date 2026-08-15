# The Bit and Bond Release Checklist

## 1. Environment and Secrets
- Confirm `.env` and local secret files are not tracked.
- Verify Firebase client configuration points to the intended project. Client
  identifiers are public metadata; service-account credentials and admin keys
  must be injected through CI/CD and never committed.
- Set mobile/web API targets with `--dart-define`:
  - `APP_ENV=staging` or `APP_ENV=production`
  - `STAGING_API_BASE_URL=...` and/or `PRODUCTION_API_BASE_URL=...`
  - `MOBILE_API_BASE_URL=...` when testing against LAN server.

## 2. Quality Gates
- Client:
  - `flutter analyze`
  - `flutter test`
  - `dart run tool/check_hardcoded_strings.dart --check`
- Server:
  - `cargo test`
  - `cargo clippy -- -D warnings`

## 3. Product Readiness
- Verify onboarding in both `繁體中文` and `English`.
- Verify DM inbox + full-screen chat + one-time photo open flow.
- Verify one-time photo behavior:
  - first open succeeds
  - second open is treated as viewed/expired without crash.
- Verify E2EE state labels:
  - `已加密 / Encrypted`
  - `可加密 / Ready`
  - `未加密 / Plain`

## 4. Build and Smoke
- iOS simulator smoke:
  - `flutter build ios --simulator`
- Android emulator smoke:
  - `flutter run -d emulator-5554`
- Web smoke:
  - `flutter build web --release`

## 5. TestFlight Internal Beta
- Build archive for iOS release:
  - `flutter build ipa --release`
- Upload to App Store Connect (Xcode Organizer or `xcrun altool` pipeline).
- Create an `Internal Testing` group and add at least 5 testers.
- Run the following scripted scenarios once per tester account:
  - onboarding greeting -> customization -> contract -> enter main space
  - manual login/register success + failure path
  - DM text send, image send, one-time image send/open
  - voice room join/leave
  - habit proof submit/review

## 6. Product Telemetry Verification
- Confirm event ingestion endpoint health:
  - `POST /api/v1/telemetry/public-events` (pre-login)
  - `POST /api/v1/telemetry/events` (authenticated)
- Verify key events are arriving:
  - `auth.login.success`, `auth.login.failed`
  - `onboarding.completed`
  - `dm.text_send.success`, `dm.text_send.failed`
  - `photo.vault_upload.success`, `photo.vault_upload.failed`
  - `photo.onetime_send.success`, `photo.onetime_send.failed`
  - `photo.onetime_open.success`, `photo.onetime_open.failed`, `photo.onetime_open.already_viewed`

## 7. Release Execution
- Tag release with semantic version, e.g. `v0.9.0`.
- Ensure GitHub Actions `CI` is green on the release commit.
- Trigger `Release` workflow (tag push or manual).
- Validate release artifacts:
  - server tarball
  - web release zip.

## 8. Post-release Monitoring
- Confirm backend logs show no auth retry storms.
- Confirm media upload/open endpoints show normal success rate.
- Check top client errors for 401/403 spikes and socket write failures.
