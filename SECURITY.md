# Security policy

Please use GitHub's private security advisory feature to report a vulnerability.
Do not open a public issue containing credentials, user data, database dumps, or
production logs.

## Deployment responsibilities

- Generate unique JWT, database, Redis, LiveKit, and other service credentials.
- Keep `.env` files and service-account credentials outside Git.
- Treat Firebase client configuration as public metadata and protect resources
  with Firebase Authentication, Security Rules, App Check, and API restrictions.
- Review CORS, TLS, rate limits, backups, and log retention before production use.

No public deployment is operated or warranted by this repository.
