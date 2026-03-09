# Changelog

All notable changes to this project are documented in this file.

## v0.9.0 - 2026-03-10

### Added
- Immersive onboarding flow with pixel-art brand direction and compact UX.
- Direct message E2EE phase-1 foundations across server APIs, DB migrations, and Flutter client security flow.
- New DM inbox/chat panels, settings controller, localization scope, and pixel UI primitives.
- Habit proof media support and related backend data model/migration updates.
- Product, architecture, and E2EE planning docs for handoff and implementation tracking.

### Changed
- Rebranded app identity to **The Bit and Bond** across Flutter app shell and docs.
- Refactored large game shell and API client files into domain-focused modules.
- Upgraded social, quest, inventory, shop, and chat integration paths for the new shell.
- Updated CI/release workflow files and local seed/bootstrap scripts.

### Fixed
- Wired previously inactive furniture interactions to live panels (photo dump, profile, habits).
- Stabilized small-screen dialog behavior and pixel UI consistency checks with updated tests.

### Verification
- `flutter analyze` passed.
- `flutter test` passed.
- `cargo test -p the_bit_and_bond_server --locked` passed.
- `cargo clippy -p the_bit_and_bond_server -- -D warnings` passed.
- iOS simulator launch smoke test passed.
- Core API smoke flow passed (auth, quests, social, DM plaintext/encrypted, chat, voice token).
