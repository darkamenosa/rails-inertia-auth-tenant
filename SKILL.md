---
name: rails-inertia-auth-tenant
description: >-
  Use this skill when the user wants full authentication + multi-tenancy for a
  Rails + Inertia.js + React + TypeScript app: Devise auth, Identity/User/Account
  tenancy, Google OAuth, access tokens, account cancellation/reactivation,
  admin customer management, request CurrentAttributes wiring, and the related
  frontend shell/pages/tests.
version: 0.2.1
---

# Auth + Tenant

Install the current complete auth/tenant implementation for this stack. This skill is no longer a partial scaffold.
The asset bundle is the source of truth and should overwrite the matching auth/tenant files in the target project.

## Use This Skill For

- Devise authentication on `Identity`
- Identity/User/Account multi-tenancy
- Google OAuth
- Access tokens for API auth
- Admin customer management
- Account cancellation + reactivation + incineration
- Request-scoped `Current` wiring
- Auth/account UI, menu selection UI, and related tests

## Prerequisites

- Draft UI stack already applied for this repo family
- Rails 8.1+
- PostgreSQL
- A clean worktree is strongly preferred before running the installer

## What It Installs

- Gems: `devise`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection`, `pg_search`
- Controllers and request concerns for authentication, authorization, error handling, request metadata, timezone, platform, and forgery protection
- Models for `Identity`, `Account`, `User`, `AccessToken`, `Current`, plus account/user concern modules
- Admin customer flows, account menu routing, access-token flows, billing guardrails, and auth pages
- Tenanting initializers, Mission Control integration, recurring incineration job config, routes, and Devise locale/config
- Frontend shells, shared nav, auth pages, account menu, access token UI, admin customer UI, and shared TS types
- Auth/tenant guide and test support/integration/model tests
- Redirect-state hardening: stale Devise `identity_return_to` values are cleared on sign-out and forced sign-out flows so old `/admin/*` destinations are not replayed after re-login

## Installer Contract

Run:

```bash
bash $SKILL_DIR/scripts/setup.sh $PROJECT_ROOT
```

The setup script does all of this:

1. adds the required gems and runs `bundle install`
2. runs `devise:install` when needed
3. removes stale files from the older half-finished skill
4. copies the final auth/tenant implementation from `assets/` into the project
5. replaces `Enlead`/`enlead` with the target app name and env key
6. updates `CLAUDE.md` with the auth/tenant guide note when that file exists
7. creates `.env` with OAuth placeholders when missing
8. deletes old auth/tenant migration variants and generates a clean baseline set

This skill intentionally overwrites the matching auth/tenant files. Do not use the old "copy some files, then surgically patch seven core files" flow.

## Migration Policy

Do not keep the previous 13-step auth migration history. It mostly compensates for earlier mistakes.

The skill should generate only these baseline migrations:

1. `CreateIdentities`
2. `CreateAccounts`
3. `CreateUsers`
4. `CreateAccountCancellations`
5. `CreateAccessTokens`

Those templates already encode the final schema shape:

- `identities`: Devise database auth, recoverable, rememberable, trackable, OAuth, suspension, staff, and password flags
- `accounts`: `name`, `personal`, and auto-generated `external_account_id`
- `users`: nullable `identity_id`, required `account_id`, string `role`, `active`, partial unique indexes, and the system-user check constraint
- `account_cancellations`: unique `account_id`, nullable `initiated_by_id`, `cascade`/`nullify` foreign keys
- `access_tokens`: token digest, prefix, permission, audit timestamps

After the script finishes, run:

```bash
bin/rails db:migrate
```

## Verification

Run:

```bash
bin/rubocop --autocorrect
npm run check && npm run lint:fix
bin/rails test test/models test/integration
```

If the user only wants a lighter verification pass, at minimum run `bin/rails test test/models test/integration`.

## Customization Notes

- `config/initializers/tenanting/account_slug.rb` is the source of truth for route account scoping and the Rack env key.
- `config/initializers/tenanting/active_storage_tenant.rb` assumes Active Storage is installed. Keep it if the app uses Active Storage; otherwise note that the initializer is optional.
- Fill `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env` or credentials if Google OAuth is needed.
- `docs/auth-tenant-guide.md` is the architecture reference for future auth/tenant work.
- Keep the sign-out flows in `Authentication`, `Identities::SessionsController`, and `App::SettingsController` aligned: when an identity is signed out, clear Devise's stored return path first to avoid replaying stale admin or account URLs on the next login.

## Source Of Truth

Treat the files in `assets/` as the desired end state for auth/tenant behavior in this repo family. Ignore implementation-plan docs when syncing the skill; only ship the runtime code, support files, guide, and tests that represent the final implementation.
