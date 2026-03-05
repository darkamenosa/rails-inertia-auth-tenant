#!/usr/bin/env bash
set -euo pipefail

# Auth + Tenant Setup Script (Phase 1 — mechanical steps)
#
# Handles: gems, generators, migrations, NEW file creation, scaffold file updates,
# and file deletions. Does NOT modify backend controllers, routes, or types —
# those require surgical edits described in SKILL.md Step 2.
#
# Prerequisite: Project must have Draft UI skill applied.
#
# Usage: bash scripts/setup.sh [project_root]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "==> Auth + Tenant Setup (Phase 1: Mechanical)"
echo "    Skill dir:   $SKILL_DIR"
echo "    Project dir: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# Portable sed in-place editing (macOS BSD sed vs GNU sed)
sedi() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# ── Step 1: Install Ruby gems ──────────────────────────────────────────
echo "==> Installing Ruby gems..."

add_gem() {
  local output
  if output=$(bundle add "$@" --skip-install 2>&1); then
    echo "    Added: $1"
  elif echo "$output" | grep -qi "already"; then
    echo "    Already present: $1"
  else
    echo "    ERROR adding $1: $output" >&2
    return 1
  fi
}

add_gem devise --version "~> 5.0"
add_gem omniauth-google-oauth2
add_gem omniauth-rails_csrf_protection
add_gem pg_search --version "~> 2.3"
bundle install --quiet

# ── Step 2: Run Devise generator ──────────────────────────────────────
echo "==> Running Devise generator..."
if [ ! -f config/initializers/devise.rb ]; then
  bin/rails generate devise:install --quiet 2>/dev/null || true
fi

# ── Step 3: Generate migrations ───────────────────────────────────────
echo "==> Generating migrations..."
TEMPLATES_DIR="$SKILL_DIR/assets/db/migrate/templates"

generate_migration() {
  local migration_class="$1"
  local snake_name="$2"
  local template_file="$3"

  if ls db/migrate/*_"$snake_name".rb 1>/dev/null 2>&1; then
    echo "    Migration $snake_name already exists, skipping"
    return
  fi

  bin/rails generate migration "$migration_class" --quiet 2>/dev/null

  local generated
  generated=$(ls -t db/migrate/*_"$snake_name".rb 2>/dev/null | head -1)

  if [ -n "$generated" ] && [ -f "$TEMPLATES_DIR/$template_file" ]; then
    cp "$TEMPLATES_DIR/$template_file" "$generated"
    echo "    Created: $(basename "$generated")"
  fi
}

generate_migration "CreateIdentities" "create_identities" "create_identities.rb"
sleep 1
generate_migration "CreateAccounts" "create_accounts" "create_accounts.rb"
sleep 1
generate_migration "CreateUsers" "create_users" "create_users.rb"
sleep 1
generate_migration "AddSuspendedAtToIdentities" "add_suspended_at_to_identities" "add_suspended_at_to_identities.rb"

# ── Step 4: Delete files replaced by this skill ──────────────────────
echo "==> Removing replaced files..."
rm -f "$PROJECT_ROOT/app/controllers/admin/users_controller.rb"
rm -rf "$PROJECT_ROOT/app/frontend/pages/admin/users"
rm -f "$PROJECT_ROOT/app/frontend/components/admin/nav-main.tsx"
echo "    Removed: admin/users_controller, admin/users pages, admin/nav-main"

# ── Step 5: Copy NEW files (files that don't exist yet) ──────────────
echo "==> Copying new files..."

# New Ruby files — concerns, identity controllers, admin customers, app menus, models
mkdir -p "$PROJECT_ROOT/app/controllers/concerns"
mkdir -p "$PROJECT_ROOT/app/controllers/identities"
mkdir -p "$PROJECT_ROOT/app/controllers/admin/customers"
mkdir -p "$PROJECT_ROOT/app/models/user"
cp -f "$SKILL_DIR/assets/app/controllers/concerns/account_scoped.rb" "$PROJECT_ROOT/app/controllers/concerns/"
cp -f "$SKILL_DIR/assets/app/controllers/concerns/block_search_engine_indexing.rb" "$PROJECT_ROOT/app/controllers/concerns/"
cp -Rf "$SKILL_DIR/assets/app/controllers/identities/" "$PROJECT_ROOT/app/controllers/identities/"
cp -f "$SKILL_DIR/assets/app/controllers/admin/customers_controller.rb" "$PROJECT_ROOT/app/controllers/admin/"
cp -Rf "$SKILL_DIR/assets/app/controllers/admin/customers/" "$PROJECT_ROOT/app/controllers/admin/customers/"
cp -f "$SKILL_DIR/assets/app/controllers/app/menus_controller.rb" "$PROJECT_ROOT/app/controllers/app/"
cp -Rf "$SKILL_DIR/assets/app/models/" "$PROJECT_ROOT/app/models/"

# New config files — initializers (devise overwrite, active_job, error_context, tenanting)
mkdir -p "$PROJECT_ROOT/config/initializers/tenanting"
cp -f "$SKILL_DIR/assets/config/initializers/devise.rb" "$PROJECT_ROOT/config/initializers/"
cp -f "$SKILL_DIR/assets/config/initializers/active_job_tenant.rb" "$PROJECT_ROOT/config/initializers/"
cp -f "$SKILL_DIR/assets/config/initializers/error_context.rb" "$PROJECT_ROOT/config/initializers/"
cp -f "$SKILL_DIR/assets/config/initializers/tenanting/account_slug.rb" "$PROJECT_ROOT/config/initializers/tenanting/"
cp -f "$SKILL_DIR/assets/config/locales/devise.en.yml" "$PROJECT_ROOT/config/locales/"

# New frontend files — shared component, field, lib utilities, auth pages, admin customer pages
mkdir -p "$PROJECT_ROOT/app/frontend/components/shared"
mkdir -p "$PROJECT_ROOT/app/frontend/pages/identities/session"
mkdir -p "$PROJECT_ROOT/app/frontend/pages/identities/registration"
mkdir -p "$PROJECT_ROOT/app/frontend/pages/identities/password"
mkdir -p "$PROJECT_ROOT/app/frontend/pages/admin/customers"
cp -f "$SKILL_DIR/assets/app/frontend/components/shared/nav-main.tsx" "$PROJECT_ROOT/app/frontend/components/shared/"
cp -f "$SKILL_DIR/assets/app/frontend/components/ui/field.tsx" "$PROJECT_ROOT/app/frontend/components/ui/"
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/ui/use-index-filters-mode.ts" "$PROJECT_ROOT/app/frontend/components/admin/ui/"
cp -f "$SKILL_DIR/assets/app/frontend/lib/account-scope.ts" "$PROJECT_ROOT/app/frontend/lib/"
cp -f "$SKILL_DIR/assets/app/frontend/lib/format-date.ts" "$PROJECT_ROOT/app/frontend/lib/"
cp -f "$SKILL_DIR/assets/app/frontend/lib/user-initials.ts" "$PROJECT_ROOT/app/frontend/lib/"
cp -Rf "$SKILL_DIR/assets/app/frontend/pages/identities/" "$PROJECT_ROOT/app/frontend/pages/identities/"
cp -Rf "$SKILL_DIR/assets/app/frontend/pages/admin/customers/" "$PROJECT_ROOT/app/frontend/pages/admin/customers/"

# ── Step 6: Copy FRONTEND SCAFFOLD files (safe to overwrite) ─────────
echo "==> Updating frontend scaffold files..."

# These are UI scaffold files from draft-ui that get auth-aware versions.
# Safe to overwrite because users customize them AFTER all skills run.
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/app-sidebar.tsx" "$PROJECT_ROOT/app/frontend/components/admin/"
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/nav-user.tsx" "$PROJECT_ROOT/app/frontend/components/admin/"
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/team-switcher.tsx" "$PROJECT_ROOT/app/frontend/components/admin/"
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/ui/index-table.tsx" "$PROJECT_ROOT/app/frontend/components/admin/ui/"
cp -f "$SKILL_DIR/assets/app/frontend/components/admin/ui/status-badge.tsx" "$PROJECT_ROOT/app/frontend/components/admin/ui/"
cp -f "$SKILL_DIR/assets/app/frontend/components/app/app-sidebar.tsx" "$PROJECT_ROOT/app/frontend/components/app/"
cp -f "$SKILL_DIR/assets/app/frontend/components/app/nav-user.tsx" "$PROJECT_ROOT/app/frontend/components/app/"
cp -f "$SKILL_DIR/assets/app/frontend/components/app/site-header.tsx" "$PROJECT_ROOT/app/frontend/components/app/"
cp -f "$SKILL_DIR/assets/app/frontend/components/app/team-switcher.tsx" "$PROJECT_ROOT/app/frontend/components/app/"
cp -f "$SKILL_DIR/assets/app/frontend/components/site-header.tsx" "$PROJECT_ROOT/app/frontend/components/"
cp -f "$SKILL_DIR/assets/app/frontend/hooks/use-flash.ts" "$PROJECT_ROOT/app/frontend/hooks/"
cp -f "$SKILL_DIR/assets/app/frontend/pages/app/errors/show.tsx" "$PROJECT_ROOT/app/frontend/pages/app/errors/"
cp -f "$SKILL_DIR/assets/app/frontend/pages/app/settings/show.tsx" "$PROJECT_ROOT/app/frontend/pages/app/settings/"

# ── Step 6b: Replace project name in copied files ────────────────────
APP_NAME=$(grep '^module ' config/application.rb | head -1 | awk '{print $2}')
APP_NAME_LOWER=$(echo "$APP_NAME" | sed 's/\([a-z]\)\([A-Z]\)/\1_\2/g' | tr '[:upper:]' '[:lower:]')

if [ -n "$APP_NAME" ] && [ "$APP_NAME" != "Enlead" ]; then
  echo "==> Replacing 'Enlead' → '$APP_NAME', 'enlead' → '$APP_NAME_LOWER'..."
  find "$PROJECT_ROOT/app/frontend/components" "$PROJECT_ROOT/app/frontend/pages/identities" \
    "$PROJECT_ROOT/config/initializers" \
    -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.rb" -o -name "*.yml" \) \
    -exec perl -pi -e "s/Enlead/${APP_NAME}/g; s/enlead/${APP_NAME_LOWER}/g" {} +
else
  echo "    Project name: $APP_NAME (template default, no replacement needed)"
fi

# ── Step 6c: Create .env file if missing ─────────────────────────────
if [ ! -f "$PROJECT_ROOT/.env" ]; then
  echo "==> Creating .env with auth defaults..."
  cat > "$PROJECT_ROOT/.env" << EOF
# Devise / Google OAuth (loaded by dotenv-rails in development/test)
DEVISE_MAILER_SENDER="${APP_NAME} <noreply@${APP_NAME_LOWER}.app>"
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
EOF
  echo "    Created: .env (fill in GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET)"
else
  echo "    .env already exists — ensure it has GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
fi

# Remove "use client" directive from shadcn label.tsx (Next.js-only, meaningless in Vite)
if [ -f "$PROJECT_ROOT/app/frontend/components/ui/label.tsx" ]; then
  sedi '/^"use client"$/d' "$PROJECT_ROOT/app/frontend/components/ui/label.tsx"
  # Also remove the blank line left behind
  sedi '1{/^$/d;}' "$PROJECT_ROOT/app/frontend/components/ui/label.tsx"
fi

# ── Step 7: Remind to run migrations ─────────────────────────────────
echo ""
echo "==> Phase 1 complete."
echo ""
echo "    Next steps:"
echo "    1. Run migrations:  bin/rails db:migrate"
echo "    2. Apply surgical edits (SKILL.md Phase 2) to:"
echo "       application_controller.rb, inertia_controller.rb,"
echo "       admin/base_controller.rb, app/base_controller.rb, app/settings_controller.rb,"
echo "       config/routes.rb, types/index.ts"
