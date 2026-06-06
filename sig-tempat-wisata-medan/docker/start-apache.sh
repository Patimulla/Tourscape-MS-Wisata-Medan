#!/usr/bin/env bash
set -e

PORT="${PORT:-8080}"

# Railway/runtime safety: ensure Apache only loads one MPM.
rm -f /etc/apache2/mods-enabled/mpm_event.conf /etc/apache2/mods-enabled/mpm_event.load
a2dismod mpm_event >/dev/null 2>&1 || true
a2enmod mpm_prefork >/dev/null 2>&1 || true

ENV_KEYS=(
  CI_ENVIRONMENT
  APP_BASE_URL
  APP_FORCE_HTTPS
  APP_TIMEZONE
  APP_DIAGNOSE_ENABLED
  APP_DIAGNOSE_KEY
  DATABASE_URL
  DB_URL
  DB_DRIVER
  DB_HOST
  DB_PORT
  DB_DATABASE
  DB_USERNAME
  DB_PASSWORD
  DB_SCHEMA
  DB_SSLMODE
  PGHOST
  PGPORT
  PGDATABASE
  PGUSER
  PGPASSWORD
  PGSSLMODE
  SUPABASE_URL
  SUPABASE_KEY
  SUPABASE_BUCKET
)

build_env_directives() {
  local directives=""
  local key=""
  local value=""
  local escaped=""

  for key in "${ENV_KEYS[@]}"; do
    value="${!key-}"
    if [ -n "$value" ]; then
      escaped="${value//\\/\\\\}"
      escaped="${escaped//\"/\\\"}"
      directives+="    SetEnv ${key} \"${escaped}\"\n"
    fi
  done

  printf "%b" "$directives"
}

ENV_DIRECTIVES="$(build_env_directives)"

cat > /etc/apache2/ports.conf <<EOF
Listen ${PORT}
EOF

cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:${PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/public

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>

${ENV_DIRECTIVES}

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

exec apache2-foreground
