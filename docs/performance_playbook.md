# The Bit and Bond Performance Playbook

## Goals
- Keep gameplay interactions smooth on phone-sized devices.
- Keep DM / photo surfaces responsive with large histories.
- Catch regressions before release.

## Client Profiling (Flutter)
Run profile mode on device/simulator:

```bash
cd apps/client_flutter
flutter run --profile -d ios
```

Use Flutter DevTools:
- Performance view: frame build/raster times.
- CPU Profiler: hotspot analysis when opening DM/photo panels.
- Memory view: watch image-heavy screens and GC churn.

## Key Scenarios
1. Open DM inbox with 50+ threads.
2. Enter full-screen conversation and send text + regular image + one-time image.
3. Open one-time photo once, then tap again (should be graceful, no crash/no spinner loop).
4. Switch language and reopen settings/menu panels.
5. Move around sandbox rooms and toggle floorplan overlay.

## Server Profiling
Capture API latency:
- `/api/v1/direct-messages/threads`
- `/api/v1/direct-messages/history`
- `/api/v1/media/once/*`
- `/api/v1/media/vault/upload`

Recommended quick check:

```bash
cd apps/server
cargo test
cargo clippy -- -D warnings
```

## Regression Guardrails
- Keep no-overflow behavior on `390x844` and `844x390`.
- Keep first DM render under one screen refresh on modern devices.
- Avoid plaintext fallback for one-time photo send when secure channel is unavailable.
- Ensure transport retries recover from transient socket write failures.
