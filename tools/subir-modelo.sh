#!/usr/bin/env bash
#
# Upload a 3D model to Roblox and come back with its asset id, without opening
# Studio once.
#
# Usage:  ./tools/subir-modelo.sh assets/clear_tray.glb ["what it is"]
#
# Needs a .env at the repo root holding ROBLOX_API_KEY and ROBLOX_USER_ID. That
# file is gitignored and must stay that way: the key can upload assets to the
# account, and a key that reaches a commit stays leaked even after it is
# deleted, because the history does not forget.
#
# WHAT THIS DOES NOT DO: it does not edit Config. Which id belongs where is a
# decision -- is this the basket, a squishy, scenery? -- and a script that
# guesses wrong writes a wrong number silently. It prints the id and records it
# in the ledger; wiring it in is a person's job.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly API="https://apis.roblox.com/assets/v1"
readonly LEDGER="$ROOT/assets/subidos.json"

# How long to keep asking whether the upload finished. Uploads normally take a
# few seconds; anything past this is a problem worth reporting rather than
# waiting out in silence.
readonly POLL_ATTEMPTS=40
readonly POLL_SECONDS=3

die() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
say() { printf '\033[36m%s\033[0m\n' "$*"; }

# ── what we were asked to upload ────────────────────────────────────────────

[ $# -ge 1 ] || die "Usage: ./tools/subir-modelo.sh <file> [\"what it is\"]"

readonly FILE="$1"
readonly NOTE="${2:-}"
[ -f "$FILE" ] || die "No such file: $FILE"

# 20 MB is the API's ceiling per call. Checking here turns a confusing HTTP
# error into a sentence.
readonly BYTES="$(wc -c < "$FILE" | tr -d ' ')"
[ "$BYTES" -le 20971520 ] || die "$FILE is $((BYTES / 1048576)) MB; the API takes 20 MB at most."

# Lowercased with `tr`, not with bash's ${x,,}: macOS ships bash 3.2 and that
# expansion is a bash 4 feature, so it dies with "bad substitution" on the very
# machine this runs on.
readonly LOWER="$(printf '%s' "$FILE" | tr '[:upper:]' '[:lower:]')"

case "$LOWER" in
	*.fbx)  MIME="model/fbx" ;;
	*.glb)  MIME="model/gltf-binary" ;;
	*.gltf) MIME="model/gltf+json" ;;
	*.obj)  MIME="model/obj" ;;
	*)      die "The API takes .fbx, .gltf, .glb, .rbxm and .rbxmx. This is ${FILE##*.}." ;;
esac

# ── credentials ─────────────────────────────────────────────────────────────

[ -f "$ROOT/.env" ] || die "No .env at the repo root. It needs ROBLOX_API_KEY and ROBLOX_USER_ID."
# shellcheck disable=SC1091
set -a; source "$ROOT/.env"; set +a

# The error names what IS there as well as what is missing. "no ROBLOX_USER_ID"
# next to a .env containing ROBLOX_ID_USER is a two-run diagnosis; showing both
# lists makes a transposed name obvious on the first.
found="$(grep -oE '^[A-Za-z_]+' "$ROOT/.env" | tr '\n' ' ')"
[ -n "${ROBLOX_API_KEY:-}" ] || die ".env has no ROBLOX_API_KEY. It has: $found"
[ -n "${ROBLOX_USER_ID:-}" ] || die ".env has no ROBLOX_USER_ID. It has: $found"

# ── look before uploading ───────────────────────────────────────────────────

# Cheaper to find a broken model here than to find it three screenshots later.
case "$LOWER" in *.glb)
	say "── what is in the file ──"
	python3 "$ROOT/tools/inspect-glb.py" "$FILE" || die "Could not read $FILE as a .glb."
	echo
;; esac

readonly NAME="$(basename "${FILE%.*}")"
say "── uploading $NAME ($((BYTES / 1024)) KB) ──"

# ── upload ──────────────────────────────────────────────────────────────────

request_json=$(python3 -c '
import json, sys
print(json.dumps({
	"assetType": "Model",
	"displayName": sys.argv[1],
	"description": sys.argv[2] or f"{sys.argv[1]} -- Master of Barter",
	"creationContext": {"creator": {"userId": sys.argv[3]}},
}))' "$NAME" "$NOTE" "$ROBLOX_USER_ID")

# --fail-with-body so a rejection arrives as a readable message rather than an
# empty non-zero exit.
create=$(curl --silent --show-error --fail-with-body \
	--location "$API/assets" \
	--header "x-api-key: $ROBLOX_API_KEY" \
	--form "request=$request_json" \
	--form "fileContent=@\"$FILE\";type=$MIME" 2>&1) || die "The upload was refused:
$create"

operation=$(python3 -c '
import json, sys
try:
	body = json.loads(sys.argv[1])
except ValueError:
	sys.exit(f"The API did not answer with JSON:\n{sys.argv[1]}")
path = body.get("path", "")
if not path.startswith("operations/"):
	sys.exit(f"No operation came back. The API said:\n{json.dumps(body, indent=2)}")
print(path.split("/", 1)[1])' "$create") || die "$operation"

say "queued as operation $operation, waiting..."

# ── wait for it ─────────────────────────────────────────────────────────────

# The upload is asynchronous: the POST only queues it. `done` turning true is
# what says the asset exists.
for attempt in $(seq 1 $POLL_ATTEMPTS); do
	status=$(curl --silent --show-error --fail-with-body \
		--location "$API/operations/$operation" \
		--header "x-api-key: $ROBLOX_API_KEY" 2>&1) || die "Could not read the operation:
$status"

	result=$(python3 -c '
import json, sys
body = json.loads(sys.argv[1])
if body.get("error"):
	sys.exit("REFUSED: " + json.dumps(body["error"], indent=2))
if not body.get("done"):
	print("")
	raise SystemExit
asset = body.get("response", {})
asset_id = asset.get("assetId")
if not asset_id:
	sys.exit("It finished but returned no assetId:\n" + json.dumps(body, indent=2))
print(asset_id)' "$status") || die "$result"

	if [ -n "$result" ]; then
		printf '\n\033[32m── done ──\033[0m\n'
		printf 'asset id:  \033[1m%s\033[0m\n' "$result"
		printf 'in Config: \033[1m%s\033[0m\n\n' "assetId = $result,"

		# A ledger, because six months from now "which file is asset 74562733627832"
		# is a question with no other answer.
		python3 -c '
import json, os, sys
path, asset_id, source, note = sys.argv[1:5]
rows = []
if os.path.exists(path):
	with open(path) as f:
		rows = json.load(f)
rows = [r for r in rows if r["assetId"] != asset_id]
rows.append({"assetId": asset_id, "source": source, "note": note})
with open(path, "w") as f:
	json.dump(rows, f, indent="\t")
	f.write("\n")' "$LEDGER" "$result" "$FILE" "$NOTE"
		say "recorded in ${LEDGER#"$ROOT/"}"
		exit 0
	fi

	printf '.'
	sleep $POLL_SECONDS
done

die "
Still not finished after $((POLL_ATTEMPTS * POLL_SECONDS)) seconds. The upload may
still land -- check it by hand:
  curl -H \"x-api-key: \$ROBLOX_API_KEY\" $API/operations/$operation"
