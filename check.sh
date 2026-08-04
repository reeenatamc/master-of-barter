#!/usr/bin/env sh
# Type-checks every file in src/ against the real Roblox API.
#
# This is the "--!strict sin errores de tipo" gate from the Definition of Done.
# Run it before committing. No Studio needed.
#
#   ./check.sh
#
# Tooling lives in .tools/ (gitignored) and is downloaded on first run, so a
# fresh clone only needs rojo on PATH.

set -e
cd "$(dirname "$0")"

LSP=".tools/luau-lsp"
DEFS=".tools/globalTypes.d.luau"

if [ ! -x "$LSP" ]; then
	echo "Downloading luau-lsp into .tools/ ..."
	mkdir -p .tools
	# The macOS build is a universal binary, so it runs on Intel and Apple Silicon.
	url=$(curl -s https://api.github.com/repos/JohnnyMorganz/luau-lsp/releases/latest |
		grep -o 'https://[^"]*luau-lsp-macos.zip')
	curl -sL -o .tools/luau-lsp.zip "$url"
	unzip -oq .tools/luau-lsp.zip -d .tools
	rm .tools/luau-lsp.zip
	chmod +x "$LSP"
	# macOS quarantines downloaded binaries; without this the OS refuses to run it.
	xattr -d com.apple.quarantine "$LSP" 2>/dev/null || true
fi

if [ ! -f "$DEFS" ]; then
	echo "Downloading Roblox API definitions ..."
	curl -sL -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
fi

# The sourcemap tells luau-lsp where each file lands in the DataModel, which is
# what lets it resolve `require(ReplicatedStorage.Shared.Util.Net)`.
rojo sourcemap default.project.json --output sourcemap.json

# Drop luau-lsp's own [INFO]/[WARN] noise; keep only findings.
# ProfileStore is vendored third-party code we do not edit. Its type errors
# are not ours to fix, and leaving them in would bury ours in the noise.
output=$("$LSP" analyze --sourcemap=sourcemap.json --definitions="$DEFS" \
	--ignore="**/ProfileStore.luau" src 2>&1 | grep -v '^\[' || true)

if [ -n "$output" ]; then
	echo "$output"
	echo
	echo "FAIL: type errors above."
	exit 1
fi

echo "OK: src/ is clean under --!strict."
