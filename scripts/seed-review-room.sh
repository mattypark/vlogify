#!/usr/bin/env bash
# Seeds the App Review demo room on the live Worker. Run it yourself, after
# scripts/deploy-worker.sh, a day or so before submitting:
#
#   scripts/seed-review-room.sh <day1> <day2>        e.g. 2026-09-29 2026-09-30
#
# day1 gets a full day of clips (8 AM - 10 PM), day2 an early morning (6 - 8 AM). Pass the day
# before review and the review day, as app days (they start at 4 AM).
#
# Creates three demo people (matthew, jiwoo, sam -- nobody can sign in as them), a log room
# "app review" with capacity 6 and the fixed invite code REV-1EF, and uploads
# ios/Vlogify/Resources/sample-clip.mov once to R2 at demo/sample-clip.mov for every demo clip
# to play. Idempotent: run it again with new days to add fresh days; nothing is duplicated.
#
# SQL: scripts/seed-review-room.sql. Set LOCAL=1 to seed the `wrangler dev` database instead.

set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/worker"

DB_NAME="vlogify"
BUCKET="vlogify-clips"
OBJECT="demo/sample-clip.mov"
CODE="REV1EF"
SAMPLE="$root/ios/Vlogify/Resources/sample-clip.mov"

usage() { echo "usage: scripts/seed-review-room.sh <day1 YYYY-MM-DD> <day2 YYYY-MM-DD>"; exit 1; }
[ $# -eq 2 ] || usage
for day in "$1" "$2"; do
  [[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || usage
done
[ "$1" != "$2" ] || { echo "day1 and day2 must differ."; exit 1; }
[ -f "$SAMPLE" ] || { echo "Missing $SAMPLE (scripts/make-sample-clip.sh makes it)."; exit 1; }

where="--remote"
[ "${LOCAL:-}" = "1" ] && where="--local"

tmpdir=$(mktemp -d)
sql="$tmpdir/seed.sql"
trap 'rm -f "$sql"; rmdir "$tmpdir"' EXIT
sed -e "s/{{DAY1}}/$1/g" -e "s/{{DAY2}}/$2/g" "$root/scripts/seed-review-room.sql" > "$sql"

echo "Uploading the demo clip to $BUCKET/$OBJECT ($where)"
npx --no-install wrangler r2 object put "$BUCKET/$OBJECT" --file "$SAMPLE" --content-type video/quicktime "$where"

echo "Seeding the review room into D1 '$DB_NAME' ($where)"
npx --no-install wrangler d1 execute "$DB_NAME" "$where" --file "$sql" --yes

npx --no-install wrangler d1 execute "$DB_NAME" "$where" --yes --command \
  "SELECT day, COUNT(*) AS clips FROM clips WHERE room_id = 'demo-review-room' GROUP BY day ORDER BY day"

cat <<EOF

Review room ready. For the App Review notes:

  Sign in with Apple, tap +, choose "join with code" and enter  ${CODE:0:3}-${CODE:3}
  The room "app review" holds three demo friends' clips from $1 and the morning of
  $2; post your own two-second clip in the current hour.
EOF
