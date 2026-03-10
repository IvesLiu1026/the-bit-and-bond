# The Bit and Bond Release Checklist

## 1. Environment and Secrets
- Confirm `.env` and local secret files are not tracked.
- Verify Firebase production files are injected in CI/CD, not committed.
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
  - `flutter run -d iPhone`
- Android emulator smoke:
  - `flutter run -d emulator-5554`
- Web smoke:
  - `flutter build web --release`

## 5. Release Execution
- Tag release with semantic version, e.g. `v0.9.0`.
- Ensure GitHub Actions `CI` is green on the release commit.
- Trigger `Release` workflow (tag push or manual).
- Validate release artifacts:
  - server tarball
  - web release zip.

## 6. Post-release Monitoring
- Confirm backend logs show no auth retry storms.
- Confirm media upload/open endpoints show normal success rate.
- Check top client errors for 401/403 spikes and socket write failures.
