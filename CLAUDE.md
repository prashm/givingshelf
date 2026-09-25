# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Givingshelf ("The Giving Shelf") is a community book/toy sharing app. Local groups (often ZIP-code based or organization/domain based, e.g. a school) list books and toys, members request them, and owners coordinate pickup. Rails 8 backend, React SPA frontend, PostgreSQL, deployed to a single EC2 box via Kamal/Docker Compose.

## Commands

### Setup & running
```bash
bin/setup          # bundle install, npm install, db:prepare, clears logs/tmp, starts bin/dev
bin/dev             # starts the app via Procfile.dev (overmind/foreman required); rails s on :3000
npx webpack --watch # separately watch/rebuild the React bundle during frontend work (bin/dev does NOT run webpack)
npx webpack          # one-off React/JS build → app/assets/javascripts/application-webpack.js
```
The JS bundle is a custom webpack build (not jsbundling-rails/shakapacker). `bin/dev` only boots Rails — run webpack separately (`npx webpack --watch`) when changing anything under `app/javascript/`.

### Tests
```bash
bin/rails test                 # full Minitest suite (models, controllers, services, jobs, mailers, integration)
bin/rails test:system          # Capybara/Selenium system tests (needs Chrome)
bin/rails test test/models/item_test.rb            # single file
bin/rails test test/models/item_test.rb -n test_name  # single test
bin/rails db:test:prepare      # load schema into test db (CI does this before running tests)
```
CI (`.github/workflows/ci.yml`) runs `bin/rails db:test:prepare test test:system` against a `postgres:16` service, plus `bin/brakeman` and `bin/importmap audit` as separate jobs. There is no JS test runner/linter configured. Rubocop lint is present in CI but currently commented out — `bin/rubocop -f github` still works locally if you want to check style (rubocop-rails-omakase).

### Security / static analysis
```bash
bin/brakeman --no-pager   # Rails security scanner, run in CI
bin/importmap audit        # JS dependency vuln scan (importmap-rails is only used for Hotwire/admin JS, not the React app)
```

### Git workflow
- Always create feature branches from `dev`, never from `main`. Before branching, bring `dev` up to date with `main` (`git fetch origin && git checkout dev && git merge --ff-only origin/main && git push origin dev`).
- Name branches after the Jira ticket in lowercase (e.g. `gs-3` for GS-3). PRs go from the ticket branch back into `dev` (`gh pr create --base dev`) on `prashm/givingshelf`.
- Never open a PR against `main`, and never push or merge to `main`: pushing to `main` triggers a production deploy, and the user merges `dev` → `main` by hand.

### Deployment
Deploys are automatic: pushing to `main` triggers CI, and on green CI, `.github/workflows/deploy.yml` SSHes into the EC2 host, rebuilds Docker images (`docker-compose.production.yml`), runs `db:prepare`, regenerates the sitemap, and restarts services. Don't hand-run deploy steps unless asked — see `deploy/` for the runbooks (RDS/Docker-Postgres setup, SES email, secrets, CloudWatch). Postgres runs as a Docker container on the same EC2 instance (see `deploy/POSTGRES_ON_EC2.md`), not RDS.

## Architecture

### Two frontends coexist in one Rails app
- **React SPA** (`app/javascript/`, entry `packs/application.js`) — the main end-user site (browsing/listing/requesting books & toys, auth, profile, messaging). Bundled by webpack into `app/assets/javascripts/application-webpack.js` and served through Propshaft. Routed client-side; `config/routes.rb` has a catch-all `get "*path" → home#index` that excludes `/api`, `/admin`, `/group`, `/g/`, `/assets`, `/packs`, static file extensions, etc., so React Router owns everything else.
- **Server-rendered Hotwire/Turbo/Stimulus + ActiveAdmin** — used for `/admin` (ActiveAdmin backend, its own `admin/sessions` auth) and `/group/admin/...` (group-admin console: managing a community group, sub-groups, memberships/invites — see `app/controllers/group/`).

Know which surface you're in before editing: `app/javascript/**` and `app/controllers/api/**` for the SPA; `app/controllers/group/**` + `app/views/group/**` for the group-admin console; `app/admin/**` for ActiveAdmin resources.

### API layer (`app/controllers/api/`)
JSON API consumed by the React app. Session-based auth via signed cookie (`Session` model, not JWT/Devise — see below), resumed per-request. Uses a custom JSON:API-flavored cursor pagination concern (`ApiCursorPagination`, `page[size]`/`page[before]`/`page[after]`) rather than page-number pagination — reuse it (`validate_and_setup_page_params`, `paginate`, `page_links_and_meta_data`) for any new paginated index endpoint.

### Multi-tenancy: Community Groups
`CommunityGroup` is the tenant boundary. Groups are resolved per-request by `GroupSubdomain` concern (included in `ApplicationController`) with this precedence: **subdomain (prod)** → **`/g/:short_name` path (local dev only)** → **`X-Site-Group-Short-Name` header (local dev API only)`. Result is stashed in `Current.group`. Groups can be:
- **Domain-locked**: `CommunityGroup#domain` ties membership to an email domain; `User#auto_join_group_by_domain!` auto-joins/leaves on signup or email change and affects `trust_score`.
- **Sub-grouped**: `SubGroup` belongs to a `CommunityGroup` (e.g. school → classroom).
- Item availability is scoped through `GroupItemAvailability` (join between `Item` and `CommunityGroup`), not a direct FK — an item can be available to multiple groups.

When adding group-scoped behavior, go through `Current.group` / `request_group`, not `params[:group_id]` directly — subdomain vs. path vs. header resolution is centralized in `GroupSubdomain` and has dev-only branches (`local_dev_host?`) that must stay consistent with prod subdomain routing.

### Items: STI, not polymorphism
`Item` is the STI base class (`type` column) with `Book` and `Toy` subclasses sharing one `items` table, one `ItemRequest` model, and one `GroupItemAvailability` join — this is the end state of a deliberate migration from a books-only schema (see `MIGRATION_FROM_BOOKSHARE_IMPLEMENTATION_PLAN.md` for the rationale/history if you need it, e.g. why some code still references "Bookshare" data or backward-compat aliases). `User#books`/`User#toys` are just `type`-filtered associations on the same `items` table. Wishlist items are `Item`s with `status: wishlist` and no `user_id` (see `Item#user_id_consistency_with_wishlist_status`); age-range filtering for toys uses `ToyAgeRange` bucket logic in `Item.overlapping_age_bucket`.

### Auth
Custom cookie-session auth, not Devise: `Session` records (`app/models/session.rb`) are created on login and referenced by a signed `session_id` cookie; `Current.session`/`Current.user` (via `ActiveSupport::CurrentAttributes`) are resumed per-request by the `Authentication` concern (`resume_session`/`require_authentication`). Endpoints opt out with `allow_unauthenticated_access`. Email verification uses TOTP-based OTP (`rotp` gem, `User#send_otp!`/`verify_otp`), not magic links. ActiveAdmin and the group-admin console each have their own separate session/login (`admin/sessions`, `group/admin`) — don't assume the main `Authentication` concern covers them (see `authenticate_admin_user!` in `ApplicationController`).

### Services & background jobs
Business logic that doesn't belong on a model/controller lives in `app/services/` (e.g. `ItemService`, `ItemRequestService`, `CommunityGroupService`, `FraudPreventionService`, `AddressVerificationService` for geocoding). Async work (notification emails, wishlist digests) goes through `app/jobs/` using Solid Queue (DB-backed Active Job, no separate Redis-backed Sidekiq); Redis itself is used for cache/Action Cable, per Solid Cache/Solid Cable.

**Design rule**: state-transition or multi-model business logic does not belong on ActiveRecord models. If a method mutates more than its own record's attributes (touches an associated record, bulk-updates siblings, could plausibly grow a notification/side-effect later, raises for control flow), it belongs on the matching `app/services/` class as a public instance method, not on the model. Models should stick to persistence, validations, scopes, and pure predicates/queries (`foo?`, `bar_for(x)`) that read only their own state. Example: `ItemRequest#accept!/decline!/complete!/cancel!/uncancel!/mark_as_in_review!/match_wishlist_donor!` all moved to `ItemRequestService` for this reason — they mutate the associated `Item`'s status (and, for `accept!`, sibling `ItemRequest` rows) alongside their own.

### Trust score & fraud prevention
`User#trust_score` is a computed 0–100 score (profile completeness + address verification + domain-matched group membership) recalculated via `after_update`/`after_create` callbacks — don't set it directly, call `calculate_trust_score!`. `FraudPreventionService` and `CaptchaVerificationService` (Cloudflare Turnstile) gate signup/listing flows.
