#!/usr/bin/env sh
# Runs the duel core headlessly: hundreds of bot-vs-bot duels, no Studio.
#
# Every module under test is the real file from src/. Only the Roblox surface
# around it is faked (see test/bundle.sh), so a green run means the duel state
# machine, the offer validation, the escrow ledger and the reveal all behaved.
#
#   ./selfplay.sh            200 bot-vs-bot duels
#   ./selfplay.sh 500        more of them
#   ./selfplay.sh 50 puppet  50 duels against a REAL in-memory profile
#   ./selfplay.sh spec       the deterministic assertions (fast, and the gate)
#
# The puppet run is the one that certifies the escrow: in a pure bot-vs-bot duel
# neither side has a profile, so nothing is ever written to escrow and "ended at
# zero" would be true of a system that had no escrow at all.
#
# What this does NOT cover: ProfileStore (saving, session locking) -- that is
# checkpoint 3 and needs Studio -- the scene, and the whole client.

set -e
cd "$(dirname "$0")"

if [ "$1" = "spec" ]; then
	COUNT=0
	MODE=spec
else
	COUNT="${1:-200}"
	MODE="${2:-bots}"
fi

if ! command -v luau >/dev/null 2>&1; then
	echo "luau not found on PATH."
	echo
	echo "The one rokit installs is arm64 and this machine is Intel, so it will not"
	echo "run. Install a native build instead:"
	echo
	echo "    brew install luau"
	exit 1
fi

OUT=".tools/harness.luau"
mkdir -p .tools
test/bundle.sh "$MODE" "$COUNT" "$OUT" >/dev/null
exec luau "$OUT"
