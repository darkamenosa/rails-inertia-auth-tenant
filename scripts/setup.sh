#!/usr/bin/env bash
set -euo pipefail

# Auth + Tenant Setup Script
#
# Installs the current auth/tenant implementation as the source of truth.
# This script overwrites the matching auth/tenant files in the target project,
# removes stale files from the earlier half-finished skill, and generates a
# compact baseline migration set that matches the final schema directly.
#
# Usage: bash scripts/setup.sh [project_root]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="${1:-.}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

echo "==> Auth + Tenant Setup"
echo "    Skill dir:   $SKILL_DIR"
echo "    Project dir: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

for cmd in rsync perl ruby bundle; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: '$cmd' is required but not found." >&2
    exit 1
  }
done

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# Converts CamelCase to snake_case using the same algorithm as
# ActiveSupport::Inflector#underscore. Handles consecutive capitals correctly
# (e.g. HTTPServer -> http_server, MyAPIGateway -> my_api_gateway).
underscore() {
  ruby -e "puts ARGV[0].gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase" "$1"
}

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

replace_project_name() {
  local app_name app_name_lower
  app_name=$(grep '^module ' config/application.rb | head -1 | awk '{print $2}')

  if [ -z "$app_name" ]; then
    echo "    ERROR: Could not extract module name from config/application.rb" >&2
    exit 1
  fi

  if [[ "$app_name" == *"::"* ]]; then
    echo "    ERROR: Namespaced module names ('$app_name') are not supported." >&2
    echo "           config/application.rb must use a simple name like 'MyApp'." >&2
    exit 1
  fi

  app_name_lower=$(underscore "$app_name")

  if [ "$app_name" = "Enlead" ]; then
    echo "    Project name: Enlead (template default, no replacement needed)"
    return
  fi

  echo "==> Replacing 'Enlead' -> '$app_name', 'enlead' -> '$app_name_lower'..."

  local replace_targets=(
    app/controllers
    app/jobs
    app/models
    app/frontend
    config/initializers
    config/locales
    config/routes.rb
    docs/auth-tenant-guide.md
    test
  )

  for target in "${replace_targets[@]}"; do
    local full_path="$PROJECT_ROOT/$target"

    if [ -d "$full_path" ]; then
      find "$full_path" \
        -type f \
        \( -name "*.rb" -o -name "*.ts" -o -name "*.tsx" -o -name "*.yml" -o -name "*.md" \) \
        -exec perl -pi -e "s/Enlead/${app_name}/g; s/enlead/${app_name_lower}/g" {} +
    elif [ -f "$full_path" ]; then
      perl -pi -e "s/Enlead/${app_name}/g; s/enlead/${app_name_lower}/g" "$full_path"
    fi
  done
}

ensure_claude_note() {
  local claude_path="$PROJECT_ROOT/CLAUDE.md"
  if [ ! -f "$claude_path" ] || grep -Fq 'docs/auth-tenant-guide.md' "$claude_path"; then
    return
  fi

  ruby - "$claude_path" <<'RUBY'
path = ARGV.fetch(0)
needle = "- Read `docs/auth-tenant-guide.md` before adding models, controllers, or features that involve tenant data, authentication, or authorization. It covers the Identity/User/Account pattern, scoping rules, and has a safety checklist\n"
text = File.read(path)

style_line = text.lines.find { |line| line.include?("docs/STYLE.md") }
text = if style_line
  text.sub(style_line, "#{style_line}#{needle}")
else
  text.rstrip + "\n\n#{needle}"
end

File.write(path, text)
RUBY

  echo "    Updated: CLAUDE.md"
}

# Ensures a key exists in .env. Appends it if missing; never overwrites.
ensure_env_key() {
  local key="$1" value="$2" env_file="$PROJECT_ROOT/.env"
  if [ ! -f "$env_file" ]; then
    echo "$key=$value" > "$env_file"
  elif ! grep -q "^${key}=" "$env_file"; then
    echo "$key=$value" >> "$env_file"
  fi
}

# ---------------------------------------------------------------------------
# Migration generation
#
# Creates timestamped migration files directly from templates — no need for
# `bin/rails generate migration`.  If a migration file already exists for a
# given suffix it is updated in-place (preserving the timestamp) so that
# re-running the installer after `db:migrate` does not corrupt the schema.
#
# When only some of the baseline migrations exist (partial previous run) the
# set is deleted and regenerated to guarantee correct ordering.
# ---------------------------------------------------------------------------

BASELINE_SUFFIXES=(
  create_identities
  create_accounts
  create_users
  create_account_cancellations
  create_access_tokens
)

BASELINE_TEMPLATES=(
  create_identities.rb
  create_accounts.rb
  create_users.rb
  create_account_cancellations.rb
  create_access_tokens.rb
)

prepare_migrations() {
  local templates_dir="$SKILL_DIR/assets/db/migrate/templates"
  mkdir -p db/migrate

  # Count how many baseline migrations already exist
  local existing_count=0
  for suffix in "${BASELINE_SUFFIXES[@]}"; do
    if compgen -G "db/migrate/*_${suffix}.rb" >/dev/null 2>&1; then
      existing_count=$((existing_count + 1))
    fi
  done

  local total=${#BASELINE_SUFFIXES[@]}

  if [ "$existing_count" -eq "$total" ]; then
    # All exist — update in-place (idempotent re-run, preserves timestamps)
    echo "    All $total baseline migrations found — updating in-place..."
    for i in "${!BASELINE_SUFFIXES[@]}"; do
      local suffix="${BASELINE_SUFFIXES[$i]}"
      local template="${BASELINE_TEMPLATES[$i]}"
      local existing
      existing=$(ls db/migrate/*_"$suffix".rb 2>/dev/null | head -1)
      cp "$templates_dir/$template" "$existing"
      echo "    Updated: $(basename "$existing")"
    done
  else
    if [ "$existing_count" -gt 0 ]; then
      # Partial set — delete all and regenerate for correct ordering
      echo "    Partial migration set ($existing_count/$total) — regenerating all..."
      for suffix in "${BASELINE_SUFFIXES[@]}"; do
        rm -f "db/migrate/"*_"$suffix".rb
      done
    fi

    # Generate fresh migrations with incrementing timestamps
    local ts
    ts=$(date -u +%Y%m%d%H%M%S)

    for i in "${!BASELINE_SUFFIXES[@]}"; do
      local suffix="${BASELINE_SUFFIXES[$i]}"
      local template="${BASELINE_TEMPLATES[$i]}"
      local target="db/migrate/${ts}_${suffix}.rb"
      cp "$templates_dir/$template" "$target"
      echo "    Created: $(basename "$target")"
      ts=$((ts + 1))
    done
  fi
}

# ===========================================================================
# Main flow
# ===========================================================================

echo "==> Installing Ruby gems..."
add_gem devise --version "~> 5.0"
add_gem omniauth-google-oauth2 --version "~> 1.2"
add_gem omniauth-rails_csrf_protection --version "~> 2.0"
add_gem pg_search --version "~> 2.3"
bundle install --quiet

echo "==> Running Devise install generator..."
if [ ! -f config/initializers/devise.rb ]; then
  bin/rails generate devise:install --quiet 2>/dev/null || true
fi

echo "==> Removing stale auth/tenant files..."
rm -f app/controllers/admin/users_controller.rb
rm -rf app/frontend/pages/admin/users
rm -f app/frontend/components/admin/nav-main.tsx
rm -f app/controllers/concerns/account_scoped.rb
rm -f app/controllers/admin/customers/bulk_deletions_controller.rb
rm -f config/initializers/active_job_tenant.rb

echo "==> Removing stale incremental migrations..."
# Only remove migrations from the old 13-step history that are NOT part of the
# baseline set.  Baseline migrations are handled idempotently by prepare_migrations.
stale_only_suffixes=(
  add_suspended_at_to_identities
  add_external_account_id_to_accounts
  make_identity_optional_on_users
  add_trackable_to_identities
  add_permission_to_access_tokens
  add_token_prefix_to_access_tokens
  harden_tenant_constraints
  convert_user_roles_to_strings
)

for suffix in "${stale_only_suffixes[@]}"; do
  rm -f "db/migrate/"*_"$suffix".rb
done

echo "==> Copying auth/tenant asset bundle..."
rsync -a --exclude 'db/migrate/templates/' "$SKILL_DIR/assets/" "$PROJECT_ROOT/"

replace_project_name
ensure_claude_note

echo "==> Generating baseline migrations..."
prepare_migrations

echo "==> Ensuring .env has auth keys..."
app_name=$(grep '^module ' config/application.rb | head -1 | awk '{print $2}')
app_name_lower=$(underscore "$app_name")

ensure_env_key "DEVISE_MAILER_SENDER" "\"${app_name} <noreply@${app_name_lower}.app>\""
ensure_env_key "GOOGLE_CLIENT_ID" ""
ensure_env_key "GOOGLE_CLIENT_SECRET" ""

echo ""
echo "==> Setup complete."
echo ""
echo "    Next steps:"
echo "    1. Run migrations:  bin/rails db:migrate"
echo "    2. Verify lint/tests:"
echo "       bin/rubocop --autocorrect"
echo "       npm run check && npm run lint:fix"
echo "       bin/rails test test/models test/integration"
