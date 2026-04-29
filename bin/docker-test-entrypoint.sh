#!/usr/bin/env bash
# docker-test-entrypoint.sh — runs inside ruby:3.2 container
# Clones Redmine (once, cached in volume), installs gems, runs specs.
set -euo pipefail

REDMINE_REF="6.0-stable"
PLUGIN_DIR="/plugin"
REDMINE_DIR="/redmine"

# Clone Redmine if not present
if [ ! -f "${REDMINE_DIR}/Gemfile" ]; then
  echo "==> Cloning Redmine ${REDMINE_REF}..."
  git clone --depth=1 --branch "${REDMINE_REF}" https://github.com/redmine/redmine.git "${REDMINE_DIR}"
fi

# Link plugin
mkdir -p "${REDMINE_DIR}/plugins"
if [ ! -d "${REDMINE_DIR}/plugins/redmine_github" ]; then
  ln -s "${PLUGIN_DIR}" "${REDMINE_DIR}/plugins/redmine_github"
fi

# Database config
cat > "${REDMINE_DIR}/config/database.yml" << 'EOF'
test:
  adapter: postgresql
  url: <%= ENV['DATABASE_URL'] %>
  encoding: utf8
EOF

# Add plugin Gemfile.local to Redmine Gemfile (idempotent)
GEMFILE_LINE='eval_gemfile "plugins/redmine_github/Gemfile.local"'
grep -qxF "${GEMFILE_LINE}" "${REDMINE_DIR}/Gemfile" || echo "${GEMFILE_LINE}" >> "${REDMINE_DIR}/Gemfile"

cd "${REDMINE_DIR}"

echo "==> bundle install..."
bundle install --quiet

echo "==> db:migrate..."
bundle exec rake db:migrate
bundle exec rake redmine:plugins:migrate

echo "==> Copying rails_helper..."
mkdir -p "${REDMINE_DIR}/spec"
cp "${PLUGIN_DIR}/.github/ci/rails_helper.rb" "${REDMINE_DIR}/spec/rails_helper.rb"

echo "==> Running specs..."
bundle exec rspec \
  plugins/redmine_github/spec/ \
  -I spec \
  -I plugins/redmine_github/spec \
  --format documentation
