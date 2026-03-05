---
name: rails-inertia-auth-tenant
description: >-
  This skill should be used when the user asks to "set up authentication",
  "add Devise auth", "set up multi-tenant", "add Identity User Account models",
  "scaffold auth pages", "add login and registration",
  "set up tenant middleware", "add admin customer management",
  or needs authentication + multi-tenancy for a Rails + Inertia.js + React + TypeScript project.
  Covers Devise auth on Identity model, Identity/User/Account three-tier tenancy,
  Google OAuth, 4 auth UI pages, admin customer management, tenant middleware,
  and CurrentAttributes integration.
version: 0.1.0
---

# Auth + Tenant — Identity/User/Account Authentication & Multi-Tenancy

Set up complete authentication and multi-tenancy for a Rails 8 + Inertia.js + React + TypeScript
project. Implements the Identity/User/Account three-tier pattern with Devise, Google OAuth,
tenant scoping middleware, admin customer management, and 4 auth UI pages.

**Prerequisites**:
- Draft UI skill applied (`rails-inertia-react-draft-ui`) — provides layouts, shadcn, pagy, admin/app structure
- Rails 8.1+ (uses `Rails.error.add_middleware` API)
- PostgreSQL database created and accessible

## What Gets Installed

- **Gems**: `devise ~> 5.0`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection`, `pg_search ~> 2.3`
- **Models**: Identity (Devise), Account (tenant), User (membership), Current (attributes)
- **Migrations**: 4 (identities, accounts, users, add_suspended_at)
- **Devise controllers**: sessions, registrations, passwords, omniauth_callbacks
- **Admin controllers**: customers (index/show/destroy + nested REST for suspension, staff access, bulk ops)
- **Concerns**: AccountScoped, BlockSearchEngineIndexing
- **Initializers**: devise.rb (custom AuthFailure), active_job_tenant.rb, error_context.rb, tenanting/account_slug.rb
- **Auth UI pages**: login, register, forgot password, reset password
- **Admin pages**: customer index (with IndexTable), customer detail
- **Frontend utilities**: account-scope.ts, user-initials.ts, format-date.ts, shared/nav-main.tsx, ui/field.tsx

## Setup Process (2 phases)

### Phase 1: Run the setup script

The script handles gems, Devise generator, migration generation, NEW files, and frontend scaffold updates.
After the script completes, run `bin/rails db:migrate` manually.

```bash
bash $SKILL_DIR/scripts/setup.sh $PROJECT_ROOT
```

This copies 50+ files but does NOT modify backend controllers, routes, or types.
Those require Phase 2 (surgical edits) to preserve any project-specific customizations.

After the script finishes, run migrations (with user approval):
```bash
bin/rails db:migrate
```

### Phase 2: Apply surgical edits to existing files

**Project name**: The setup script detects the app module name from `config/application.rb`
and replaces "Enlead"/"enlead" in all copied files. For Phase 2 surgical edits, detect
the same name. The lowercase/snake_case version is used for the Rack env key
(e.g., `my_app.account_id` for a project module `MyApp`).

For each file below, read both the CURRENT project file and the REFERENCE file in
`$SKILL_DIR/assets/`, then apply the described changes surgically. Do NOT copy-replace
these files — they may contain project-specific code that must be preserved.

#### 1. `app/controllers/application_controller.rb`

Reference: `$SKILL_DIR/assets/app/controllers/application_controller.rb`

Add these `before_action` lines after `allow_browser`:
```ruby
before_action :set_current_attributes
before_action :store_user_location, if: :storable_location?
before_action :configure_permitted_parameters, if: :devise_controller?
```

Add these private methods (keep all existing error handlers intact):
```ruby
def set_current_attributes
  Current.identity = current_identity if respond_to?(:current_identity)
  Current.request_id = request.uuid
  Current.user_agent = request.user_agent
  Current.ip_address = request.remote_ip
end

def require_active_identity!
  if Current.identity.present? && !Current.identity.active_for_authentication?
    inactive_message = Current.identity.inactive_message
    sign_out(:identity)
    Current.reset
    redirect_to new_identity_session_path, alert: I18n.t("devise.failure.#{inactive_message}")
  end
end

def storable_location?
  request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
end

def store_user_location
  store_location_for(:identity, request.fullpath)
end

def configure_permitted_parameters
  devise_parameter_sanitizer.permit(:sign_up, keys: [])
  devise_parameter_sanitizer.permit(:account_update, keys: [])
end
```

Replace the existing `current_user` stub (keep the `helper_method` line):
```ruby
# FROM:
def current_user
  nil # Will be implemented in auth skill
end
helper_method :current_user

# TO:
def current_user
  Current.user
end
helper_method :current_user
```

#### 2. `app/controllers/inertia_controller.rb`

Reference: `$SKILL_DIR/assets/app/controllers/inertia_controller.rb`

Replace the `current_user_props` method body:
```ruby
def current_user_props
  return nil unless Current.identity

  user = Current.user || Current.identity.users.order(:created_at).first

  {
    id: Current.identity.id,
    name: user&.name || Current.identity.email.split("@").first,
    email: Current.identity.email,
    role: user&.role,
    staff: Current.identity.staff?,
    account_id: user&.account_id,
    account_name: user&.account&.name
  }
end
```

#### 3. `app/controllers/admin/base_controller.rb`

Reference: `$SKILL_DIR/assets/app/controllers/admin/base_controller.rb`

Add after `include Pagy::Method`:
```ruby
include BlockSearchEngineIndexing
before_action :authenticate_identity!
before_action :require_active_identity!
before_action :require_staff!
before_action :require_unscoped_access!
```

Add private methods (before `pagination_props`).
Read `config/initializers/tenanting/account_slug.rb` to find the Rack env key
(it will be `<app_name_lower>.account_id`, e.g., `my_app.account_id`):
```ruby
def require_staff!
  render_error_page(403, "Forbidden", "Staff access required.") unless Current.identity&.staff?
end

def require_unscoped_access!
  # Use the same Rack env key as in tenanting/account_slug.rb
  render_error_page(404, "Not Found", "Admin routes are not tenant-scoped.") if request.env["<app_name_lower>.account_id"].present?
end
```

Remove `parse_inertia_array` method if it exists (moved to InertiaUtils concern).

#### 4. `app/controllers/app/base_controller.rb`

Add one line inside the class:
```ruby
module App
  class BaseController < InertiaController
    include AccountScoped
  end
end
```

#### 5. `app/controllers/app/settings_controller.rb`

Reference: `$SKILL_DIR/assets/app/controllers/app/settings_controller.rb`

Update `show` action to pass auth props:
```ruby
def show
  render inertia: "app/settings/show", props: {
    name: Current.user.name,
    email: Current.identity.email,
    password_changeable: Current.identity.password_set_by_user?
  }
end
```

Add `update` and `destroy` actions + private methods:
```ruby
def update
  if password_change?
    update_password
  else
    update_profile
  end
end

def destroy
  Current.identity.destroy
  redirect_to root_path, notice: "Your account has been deleted."
end

private
  def update_profile
    if Current.user.update(profile_params)
      redirect_to app_settings_path(account_id: Current.account.id), notice: "Profile updated."
    else
      redirect_to app_settings_path(account_id: Current.account.id), alert: Current.user.errors.full_messages.to_sentence
    end
  end

  def update_password
    if Current.identity.update_with_password(password_params)
      bypass_sign_in(Current.identity)
      redirect_to app_settings_path(account_id: Current.account.id), notice: "Password updated."
    else
      redirect_to app_settings_path(account_id: Current.account.id), alert: Current.identity.errors.full_messages.to_sentence
    end
  end

  def password_change?
    params.dig(:settings, :current_password).present?
  end

  def profile_params
    params.expect(settings: [ :name ])
  end

  def password_params
    params.expect(settings: [ :current_password, :password, :password_confirmation ])
  end
```

#### 6. `config/routes.rb`

Reference: `$SKILL_DIR/assets/config/routes.rb`

This file needs significant restructuring. Read both versions and merge:

**Add at top** (before any namespace):
```ruby
devise_for :identities,
  path: "",
  path_names: { sign_in: "login", sign_out: "logout", registration: "register", sign_up: "" },
  controllers: {
    sessions: "identities/sessions",
    registrations: "identities/registrations",
    passwords: "identities/passwords",
    omniauth_callbacks: "identities/omniauth_callbacks"
  }
```

**Wrap `namespace :app` in authentication + account scoping:**
```ruby
authenticate :identity, ->(identity) { identity.active_for_authentication? && identity.users.active.exists? } do
  scope "app/:account_id", constraints: { account_id: /\d+/ } do
    namespace :app, path: "" do
      # existing app routes here + add:
      resource :settings, only: [ :show, :update, :destroy ]  # was only: :show
    end
  end
  get "app", to: "app/menus#show", as: :app
end
```

**Wrap `namespace :admin` in staff authentication:**
```ruby
authenticate :identity, ->(identity) { identity.active_for_authentication? && identity.staff? } do
  namespace :admin do
    # existing admin routes + replace users with customers:
    resources :customers, only: [ :index, :show, :destroy ] do
      scope module: :customers do
        resource :suspension, only: [ :create, :destroy ]
        resource :staff_access, only: [ :create, :destroy ]
      end
    end
    namespace :customers do
      resource :bulk_suspension, only: [ :create, :destroy ]
      resource :bulk_deletion, only: :create
    end
    # ... keep existing analytics, settings routes
  end
  get "admin", to: redirect("/admin/dashboard")
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"
end
```

Remove standalone `get "app"` redirect and `mount MissionControl` (now inside authenticate block).

#### 7. `app/frontend/types/index.ts`

Reference: `$SKILL_DIR/assets/app/frontend/types/index.ts`

Update `CurrentUser` type (replace optional fields with required + add new fields):
```typescript
export type CurrentUser = {
  id: number
  name: string
  email: string
  role: string | null
  staff: boolean
  accountId: number | null
  accountName: string | null
}
```

Update `SharedProps`:
```typescript
export type SharedProps = {
  flash?: FlashData
  currentUser: CurrentUser | null  // was optional, now required but nullable
}
```

Append new admin types at end of file:
```typescript
export type AdminCustomer = {
  id: number
  email: string
  name: string | null
  authMethod: string
  staff: boolean
  status: string
  accountsCount: number
  createdAt: string
}

export type AdminCustomerDetail = {
  id: number
  email: string
  name: string | null
  authMethod: string
  staff: boolean
  status: string
  suspendedAt: string | null
  createdAt: string
  memberships: AdminCustomerMembership[]
}

export type AdminCustomerMembership = {
  id: number
  accountId: number
  accountName: string
  role: string
  name: string
  active: boolean
  createdAt: string
}
```

### Phase 3: Lint and verify

```bash
bin/rubocop --autocorrect
npm run lint:fix
npx prettier --write "app/frontend/**/*.{ts,tsx}"
npm run check && npm run lint && npm run format:check
```

### Phase 4: Configure (optional)

**Google OAuth** — edit `.env` (created by the setup script) and fill in credentials:
```env
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
```

**Create staff identity** (for admin access):
```ruby
# bin/rails console
identity = Identity.create!(email: "admin@example.com", password: "password123")
identity.update!(staff: true)
Account.create_with_user(identity: identity, name: "Admin User")
```

## Architecture Summary

**Two authorization dimensions:**
- System: `Identity.staff` (boolean) → `/admin/*` access
- Account: `User.role` (owner/admin/member) → per-account permissions

**Route guards:** `/app/*` requires active membership, `/admin/*` requires staff

**Data flow:** Request → AccountSlug middleware → Current.account → Devise → Current.identity → Current.user → Controller (AccountScoped)

## Customization Points

- **App name**: Automatically replaced by the setup script using the Rails module name from `config/application.rb`. Both PascalCase (display) and snake_case (Rack env key, email domain) are derived
- **`.env` file**: Created by the setup script if missing. Fill in `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` for OAuth. Update `DEVISE_MAILER_SENDER` with actual email domain
- **Devise config**: `config/initializers/devise.rb` (mailer sender, password length, etc.)
- **OAuth providers**: Add in devise.rb + create callback methods in `omniauth_callbacks_controller.rb`
- **Account slug**: Modify `AccountSlug.decode/encode` for custom slug formats (e.g., subdomains)
