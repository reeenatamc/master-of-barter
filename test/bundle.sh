#!/usr/bin/env sh
# Bundles the real game modules with a stubbed Roblox surface into one Luau file.
#
# Called by ../selfplay.sh; not meant to be run by hand.
#
#   test/bundle.sh <mode> <count> <output>
#
# Everything under src/ is copied VERBATIM -- this script never edits game code,
# it only builds the world around it. What is faked lives in prelude.luau, and it
# is small: task, os.clock, Random, Instance, a service locator and an instance
# tree.
#
# WHY sh AND NOT PYTHON, since it started as python: on a Mac with no Homebrew
# python, `python3` is Xcode's, and Xcode's refuses to run until somebody has
# agreed to a licence in a terminal. A test gate that can be knocked out by an
# OS update is not a gate. sh, awk and sed are always there.
#
# NOT COVERED, said here so nobody reads a green run as more than it is:
# ProfileStore (saving, session locking, migrations -- that is checkpoint 3),
# DuelSceneService (Instance/CFrame work with nothing to assert headlessly), and
# anything on the client.

set -e
cd "$(dirname "$0")/.."

MODE="$1"
COUNT="$2"
OUT="$3"

# name:path, in load order. The parent node comes from the group.
SHARED="Types:src/shared/Types.luau"
CONFIG="Items:src/shared/Config/Items.luau
Economy:src/shared/Config/Economy.luau
DuelRules:src/shared/Config/DuelRules.luau
Strings:src/shared/Config/Strings.luau
Bots:src/shared/Config/Bots.luau
Analytics:src/shared/Config/Analytics.luau
Showcase:src/shared/Config/Showcase.luau"
UTIL="Signal:src/shared/Util/Signal.luau
Trove:src/shared/Util/Trove.luau
Net:src/shared/Util/Net.luau
Kiosk:src/shared/Util/Kiosk.luau"
SERVICES="AnalyticsService:src/server/Services/AnalyticsService.luau
DuelTypes:src/server/Services/DuelTypes.luau
DuelView:src/server/Services/DuelView.luau
DuelReveal:src/server/Services/DuelReveal.luau
DuelOffers:src/server/Services/DuelOffers.luau
DuelStakes:src/server/Services/DuelStakes.luau
DuelService:src/server/Services/DuelService.luau
BotService:src/server/Services/BotService.luau
EconomyService:src/server/Services/EconomyService.luau
InventoryService:src/server/Services/InventoryService.luau
PlayerDataService:src/server/Services/PlayerDataService.luau
ShowcaseService:src/server/Services/ShowcaseService.luau"

mkdir -p "$(dirname "$OUT")"
cat test/prelude.luau > "$OUT"

# Every node is declared before any module body runs, so a module may require
# any other regardless of the order they appear in here.
for group in SHARED CONFIG UTIL SERVICES; do
	case $group in
		SHARED) list=$SHARED parent=Shared ;;
		CONFIG) list=$CONFIG parent=Config ;;
		UTIL) list=$UTIL parent=Util ;;
		SERVICES) list=$SERVICES parent=Services ;;
	esac
	echo "$list" | while IFS=: read -r name path; do
		[ -n "$name" ] || continue
		echo "local MODULE_$name = node(\"$name\", $parent)" >> "$OUT"
	done
done

for group in SHARED CONFIG UTIL SERVICES; do
	case $group in
		SHARED) list=$SHARED ;;
		CONFIG) list=$CONFIG ;;
		UTIL) list=$UTIL ;;
		SERVICES) list=$SERVICES ;;
	esac
	echo "$list" | while IFS=: read -r name path; do
		[ -n "$name" ] || continue
		{
			echo ""
			echo "-- ════ $path ════"
			echo "registry[MODULE_$name] = function(script)"
			cat "$path"
			echo "end"
		} >> "$OUT"
	done
done

if [ "$MODE" = "spec" ]; then
	sed -e 's/ARGV_MODE/"spec-setup"/' -e 's/ARGV_COUNT/0/' test/runner.luau >> "$OUT"
	cat test/spec.luau >> "$OUT"
else
	sed -e "s/ARGV_MODE/\"$MODE\"/" -e "s/ARGV_COUNT/$COUNT/" test/runner.luau >> "$OUT"
fi

echo "$OUT"
