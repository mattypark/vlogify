#!/usr/bin/env bash
# Puts the vlogify Worker on your Cloudflare account. Run it yourself:
#
#   scripts/deploy-worker.sh
#
# Idempotent: it creates what is missing and leaves what exists alone.
#   1. Cloudflare login (browser, once)
#   2. D1 database "vlogify" (its id is written into worker/wrangler.toml -- not a secret;
#      commit that change)
#   3. R2 bucket "vlogify-clips" + a lifecycle rule expiring clips/ after 7 days
#   4. The four required secrets, generated with openssl and piped straight into
#      `wrangler secret put` -- never printed, never written to a file
#   5. D1 migrations, remote
#   6. The Worker's tests
#   7. wrangler deploy, then GET /health on the live URL
#
# Optional secrets (Apple revoke, Telegram alerts) are listed at the end with the exact
# commands to set them; the Worker runs without them.

set -euo pipefail
cd "$(dirname "$0")/../worker"

DB_NAME="vlogify"
BUCKET="vlogify-clips"
RULE="expire-clips"
TTL_DAYS="7"
PLACEHOLDER="00000000-0000-0000-0000-000000000000"

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
wrangler() { npx --no-install wrangler "$@"; }

command -v openssl >/dev/null || { echo "openssl is needed to generate secrets."; exit 1; }
[ -d node_modules ] || npm install

bold "1/7  Cloudflare login"
wrangler whoami >/dev/null 2>&1 || wrangler login
wrangler whoami | grep -iE "email|account" || true

bold "2/7  D1 database '$DB_NAME'"
if grep -q "$PLACEHOLDER" wrangler.toml; then
  id=$(wrangler d1 list --json | node -e '
    const list = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const db = list.find((d) => d.name === process.argv[1]);
    if (db) console.log(db.uuid);
  ' "$DB_NAME")
  if [ -z "$id" ]; then
    id=$(wrangler d1 create "$DB_NAME" 2>&1 | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)
  fi
  [ -n "$id" ] || { echo "Couldn't create or find the D1 database '$DB_NAME'."; exit 1; }
  sed -i '' "s/$PLACEHOLDER/$id/" wrangler.toml
  echo "D1 database $id (written to worker/wrangler.toml -- commit it)"
else
  echo "D1 database id already in wrangler.toml"
fi

bold "3/7  R2 bucket '$BUCKET' and its $TTL_DAYS-day rule on clips/"
r2=$(wrangler r2 bucket create "$BUCKET" 2>&1 || true)
if printf '%s' "$r2" | grep -qiE "10042|enable R2"; then
  echo "R2 isn't on for this account yet. Dashboard -> R2 Object Storage -> turn it on (free tier; it asks"
  echo "for a payment method), then run this script again. Nothing else needs redoing."
  exit 1
fi
printf '%s\n' "$r2" | grep -iE "created|already exists" || printf '%s\n' "$r2"
if wrangler r2 bucket lifecycle list "$BUCKET" 2>/dev/null | grep -q "$RULE"; then
  echo "Lifecycle rule '$RULE' already set"
else
  wrangler r2 bucket lifecycle add "$BUCKET" "$RULE" "clips/" --expire-days "$TTL_DAYS" --force
  echo "Lifecycle rule '$RULE': clips/ expires after $TTL_DAYS days"
fi

bold "4/7  Secrets"
existing=$(wrangler secret list --format json 2>/dev/null || echo "[]")
has() { printf '%s' "$existing" | grep -q "\"$1\""; }
# Each value goes from openssl straight into wrangler's stdin. Nothing is echoed or stored here.
for name in SESSION_SECRET PEPPER MEDIA_SIGNING_KEY; do
  if has "$name"; then
    echo "$name already set"
  else
    openssl rand -base64 48 | tr -d '\n' | wrangler secret put "$name" >/dev/null && echo "$name set"
  fi
done
# AES-256 key for sealing Apple refresh tokens: exactly 32 bytes, base64.
if has TOKEN_KEY; then
  echo "TOKEN_KEY already set"
else
  openssl rand -base64 32 | tr -d '\n' | wrangler secret put TOKEN_KEY >/dev/null && echo "TOKEN_KEY set"
fi

bold "5/7  Migrations (remote)"
wrangler d1 migrations apply "$DB_NAME" --remote

bold "6/7  Tests"
npm test

bold "7/7  Deploy"
log=$(mktemp)
trap 'rm -f "$log"' EXIT
wrangler deploy | tee "$log"
url=$(grep -oE 'https://[a-z0-9.-]+\.workers\.dev' "$log" | head -1 || true)

if [ -n "$url" ]; then
  bold "Health check: $url/health"
  if curl -fsS --retry 5 --retry-delay 2 --retry-all-errors "$url/health"; then
    echo
  else
    echo "The Worker deployed but /health did not answer yet. Try: curl $url/health"
  fi
fi

missing=""
for name in APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY TG_BOT_TOKEN TG_CHAT_ID; do
  has "$name" || missing="$missing $name"
done

# xcconfig reads // as a comment, so the URL is written with an empty $() between the slashes.
xcconfig_url=$(printf '%s' "${url:-https://vlogify.<subdomain>.workers.dev}" | sed 's#^https://#https:/$()/#')

bold "Done. Worker: ${url:-see the deploy output above}"
cat <<EOF

Point the app at it -- ios/Vlogify/Base.xcconfig:
  VLOGIFY_API_URL = $xcconfig_url
App Store Connect URLs (served by this Worker until there is a domain):
  Privacy: ${url:-<worker url>}/privacy
  Support: ${url:-<worker url>}/support
Seed the App Review room:
  scripts/seed-review-room.sh <day before review> <review day>     (e.g. 2026-09-29 2026-09-30)
EOF
if [ -n "$missing" ]; then
  cat <<EOF

Optional secrets not set:$missing
  Apple revoke on account deletion (developer.apple.com -> Keys -> Sign in with Apple):
    printf %s R43H5332KH | npx wrangler secret put APPLE_TEAM_ID
    npx wrangler secret put APPLE_KEY_ID
    npx wrangler secret put APPLE_PRIVATE_KEY < ~/Downloads/AuthKey_XXXXXXXXXX.p8
  Report / support alerts to Telegram:
    npx wrangler secret put TG_BOT_TOKEN
    npx wrangler secret put TG_CHAT_ID
  (run from worker/)
EOF
fi
