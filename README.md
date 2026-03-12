# Givingshelf

Givingshelf is a community-focused app for sharing books and toys. It lets local groups list items, request them, and coordinate pickups, with an emphasis on reuse and generosity instead of resale.

## Tech stack

- **Backend**: Ruby on Rails
- **Frontend**: React (served via Rails)
- **Database**: PostgreSQL
- **Background jobs / cache / cable**: Redis + Rails (Solid Queue / Active Job, cache, Action Cable)
- **Cloud**: AWS (EC2, RDS, SES, S3, Lambda)
- **CI/CD**: GitHub Actions, Docker
- **Security**: GitHub Dependabot Alerts, Brakeman

## Getting started (development)

1. **Requirements**
   - Ruby (see `.ruby-version`)
   - Bundler
   - Node.js + Yarn (or npm)
   - PostgreSQL

2. **Setup**
   ```bash
   bundle install
   bin/setup
   ```

3. **Run the app**
   ```bash
   bin/dev
   ```

The app should be available at `http://localhost:3000`.

## Environment & configuration

Givingshelf uses environment variables for secrets and external services (database URL, AWS, SES, Cloudflare Turnstile, etc.). In development you can use a local `.env` file (not committed to git) or your preferred secrets manager.

Production configuration and deployment steps are documented under `deploy/`.

### Versioning

The current application version is tracked in the `VERSION` file at the project root. This is used by deployment tooling and can be surfaced in the UI/logs as needed.

## Tests

Run the test suite with:

```bash
bin/rails test
```

If you use RSpec or additional tools, update this section accordingly.

## Deployment

This app is deployed to AWS using Kamal and Docker through a GitHub Actions CI/CD pipeline, with guides under `deploy/` for:

- RDS & EC2 setup
- SES (sending + incoming email forwarding)
- Secrets management

Those docs are written as step-by-step runbooks so you can see how the production environment is set up.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
