# chen-leveling

Monorepo for `chen-leveling`, a gamified daily task RPG system.

## Layout

- `apps/server`: Rust backend (Axum + SeaORM + PostgreSQL)
- `apps/server/entity`: SeaORM entity crate
- `apps/server/migration`: SeaORM migration crate
- `apps/client_flutter`: Flutter + Flame + Riverpod app
- `packages/api-spec`: OpenAPI contract
- `infra`: local infrastructure and scripts

## Quick start

0. Prerequisites

```bash
# Rust on Windows requires MSVC linker (Visual Studio Build Tools, Desktop C++)
```

0.5. Create local env file

```bash
cp .env.example .env
```

Set `JWT_SECRET` in `.env` to a long random value (at least 32 characters) before starting the server.
Default `BIND_ADDR` is `0.0.0.0:18080` so LAN devices (e.g. iPad) can reach the API.

1. Start database

```bash
docker compose -f infra/docker-compose.yml up -d
```

Note: this compose file publishes PostgreSQL on host port `5433` by default to avoid conflicts with an existing local PostgreSQL on `5432`. Override with `POSTGRES_PORT=...` if needed.

2. Run migrations

```bash
cargo run -p migration -- up
```

3. Start server

```bash
cargo run -p chen_leveling_server
```

Quick check:

```bash
curl http://127.0.0.1:18080/health
# or
curl http://127.0.0.1:18080/api/v1/health
```

4. Start Flutter client

```bash
cd apps/client_flutter
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:18080 \
  --dart-define=MASTER_EMAIL=parent@example.com \
  --dart-define=MASTER_PASSWORD=Passw0rd! \
  --dart-define=HUNTER_PIN_CODE=2468
```

or run a web-server target so Windows/iPad browsers can open it directly:

```bash
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 18081 \
  --dart-define=API_BASE_URL=http://127.0.0.1:18080
```

Open URLs:

- Same machine: `http://localhost:18081`
- LAN device: `http://<your-pc-lan-ip>:18081`

Optional (pin/hunter overrides):

```bash
--dart-define=MASTER_EMAIL=parent@example.com \
--dart-define=MASTER_PASSWORD=Passw0rd! \
--dart-define=INVITE_CODE=ABC123 \
--dart-define=HUNTER_PIN_CODE=2468
```

## Git strategy (recommended)

- `main`: protected, always deployable, only merge via PR.
- `feat/<scope>-<topic>`: feature branches (e.g. `feat/auth-hunter-login`).
- `fix/<scope>-<topic>`: bugfix branches.
- `chore/<topic>`: tooling/infrastructure/docs.

Suggested flow:

1. Create branch from `main`.
2. Open PR early.
3. Require CI to pass before merge.
4. Use squash merge to keep history clean.

## CI/CD with GitHub Actions

This repo includes two workflows:

- `CI` (`.github/workflows/ci.yml`)
  - Runs on push/PR to `main`.
  - Rust: `fmt`, `clippy`, `test`.
  - Flutter: `analyze`, `test`.
- `PR Preview Build` (`.github/workflows/pr_preview.yml`)
  - Runs on pull requests to `main`.
  - Builds Flutter web preview bundle.
  - Uploads build as workflow artifact and comments instructions in the PR.
- `CD Build Artifacts` (`.github/workflows/cd_build_artifacts.yml`)
  - Manual trigger (`workflow_dispatch`).
  - Builds Rust release binary and Flutter web release bundle.
  - Uploads artifacts to the workflow run.
- `Release` (`.github/workflows/release.yml`)
  - Runs on tag push `v*` (or manual dispatch with a tag).
  - Runs tests, builds Rust + Flutter web, then publishes a GitHub Release with assets.

### Trigger CD manually

1. GitHub repo -> `Actions`
2. Select `CD Build Artifacts`
3. `Run workflow` (default `ref=main`)

### Secrets to add in GitHub

- `JWT_SECRET` (for backend runtime/deploy stage)
- `DATABASE_URL` (if deployment pipeline runs migrations)

Note: the current CD workflow builds and uploads artifacts only. Deployment to a host
(Cloudflare/VM/Kubernetes/etc.) can be added as the next step.

## Branch protection note

`main` branch protection (required PR reviews/checks) requires a plan that supports
branch protection for private repositories. If unavailable on your current plan,
keep using the same PR + CI policy as a team rule and enforce via repository settings
that are still available (for example, squash merge only).
