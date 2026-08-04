#!/usr/bin/env sh
# Builds the documentation site: the prose in docs/ plus an API reference
# generated from the doc comments in src/.
#
#   ./docs.sh            live-reload server, opens in the browser
#   ./docs.sh build      static site into build/
#   ./docs.sh publish    build and push it to the gh-pages branch
#
# Two things make this more than a one-liner:
#
# 1. Moonwave only publishes an arm64 macOS extractor, which cannot run on an
#    Intel Mac -- Rosetta translates Intel to ARM, not the other way round. So
#    we build the extractor from source once into .tools/ and drop it exactly
#    where the CLI looks for it, which makes the CLI skip its own download.
#    Same idea as check.sh downloading luau-lsp: .tools/ is gitignored and
#    fills itself in on first run.
#
# 2. Moonwave reads every `---` comment as documentation and aborts the whole
#    build if it cannot parse one. Only the paths in CODE_PATHS have been
#    annotated with their @class block so far, so the reference covers those on
#    purpose. Widening that list, one module at a time, is the entire migration.

set -e
cd "$(dirname "$0")"

MOONWAVE_VERSION="1.4.2"
CODE_PATHS="src/shared"

EXTRACTOR=".tools/moonwave-extractor"
SOURCE_DIR=".tools/moonwave-src/moonwave-$MOONWAVE_VERSION"
TARGET="node_modules/moonwave/dist/bin/moonwave-extractor-$MOONWAVE_VERSION"

# --- 1. The Moonwave CLI (JavaScript). An ordinary npm dependency. ----------
if [ ! -d node_modules/moonwave ]; then
	echo "Installing the Moonwave CLI ..."
	npm install --silent
fi

# --- 1b. Mermaid support. --------------------------------------------------
# The architecture docs draw the duel state machine and the remote flow as
# mermaid diagrams. Moonwave's site template does not ship the mermaid theme
# and offers no hook to add dependencies, so we add it to the template
# ourselves. Idempotent: it costs nothing once applied, and it survives the
# `fresh` rebuild because the template is what the rebuild copies from.
TEMPLATE_PKG="node_modules/moonwave/template/root/package.json"
TEMPLATE_LOCK="node_modules/moonwave/template/root/package-lock.json"
if [ -f "$TEMPLATE_PKG" ] && [ -f "$TEMPLATE_LOCK" ]; then
	node -e '
		const fs = require("fs")
		const [pkgFile, lockFile] = process.argv.slice(1)
		const pkg = JSON.parse(fs.readFileSync(pkgFile, "utf8"))
		const lock = JSON.parse(fs.readFileSync(lockFile, "utf8"))

		// Docusaurus refuses to build if two official @docusaurus/* packages
		// disagree on version, and the theme published a newer patch than the
		// core this template pins. So take the exact version out of the lock
		// rather than a caret range that would drift ahead of it.
		const core = Object.entries(lock.packages || {})
			.find(([name]) => name.endsWith("node_modules/@docusaurus/core"))
		if (!core) throw new Error("could not find @docusaurus/core in the template lock file")
		const version = core[1].version

		if (pkg.dependencies["@docusaurus/theme-mermaid"] === version) process.exit(0)
		pkg.dependencies["@docusaurus/theme-mermaid"] = version
		fs.writeFileSync(pkgFile, JSON.stringify(pkg, null, 2) + "\n")
		console.log(`Pinned the mermaid theme to Docusaurus ${version} in the site template.`)
	' "$TEMPLATE_PKG" "$TEMPLATE_LOCK"
fi

# --- 2. The extractor (Rust). Built once, then cached in .tools/. -----------
if [ ! -x "$EXTRACTOR" ]; then
	if ! command -v cargo >/dev/null 2>&1; then
		if [ -x "$HOME/.cargo/bin/cargo" ]; then
			PATH="$HOME/.cargo/bin:$PATH"
			export PATH
		else
			echo "Rust is needed to build the extractor for this machine. Install it with:"
			echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
			exit 1
		fi
	fi

	if [ ! -d "$SOURCE_DIR" ]; then
		echo "Downloading Moonwave $MOONWAVE_VERSION sources ..."
		mkdir -p .tools/moonwave-src
		curl -sL -o .tools/moonwave-src/source.tar.gz \
			"https://github.com/evaera/moonwave/archive/refs/tags/v$MOONWAVE_VERSION.tar.gz"
		tar -xzf .tools/moonwave-src/source.tar.gz -C .tools/moonwave-src
	fi

	echo "Building moonwave-extractor for $(uname -m) (first run only, about a minute) ..."
	cd "$SOURCE_DIR/extractor"
	cargo build --release
	cd - >/dev/null
	cp "$SOURCE_DIR/extractor/target/release/moonwave-extractor" "$EXTRACTOR"
	chmod +x "$EXTRACTOR"
fi

# --- 3. Hand our build to the CLI so it does not fetch the arm64 one. -------
mkdir -p "$(dirname "$TARGET")"
if [ ! -f "$TARGET" ] || [ "$EXTRACTOR" -nt "$TARGET" ]; then
	cp "$EXTRACTOR" "$TARGET"
	chmod +x "$TARGET"
fi

# --- 4. Fail on doc-comment errors before Docusaurus buries them. -----------
# The extractor is fast and its diagnostics are precise; the Docusaurus build
# only reports that extraction failed somewhere.
if ! "$EXTRACTOR" extract $CODE_PATHS >/dev/null; then
	echo
	echo "FAIL: doc comment errors above. A module in CODE_PATHS needs its"
	echo "      @class block, or a --- comment on something private should be --."
	exit 1
fi

# `build` regenerates the cached site project from scratch, which pulls the rug
# from under a dev server using that same directory: it survives the deletion
# and then fills the browser with "Module not found" for files that no longer
# exist. Nothing is corrupted, but the error wall looks like a real failure.
if [ "$1" = "build" ] || [ "$1" = "publish" ]; then
	if pgrep -f "moonwave dev" >/dev/null 2>&1; then
		echo "A dev server is running. Stop it first (Ctrl+C in its terminal),"
		echo "otherwise this build will break it."
		exit 1
	fi
fi

case "$1" in
build)
	npx moonwave build --code $CODE_PATHS
	;;
publish)
	echo "This publishes the site publicly to the gh-pages branch."
	printf "Type yes to continue: "
	read -r answer
	[ "$answer" = "yes" ] || { echo "Cancelled."; exit 1; }
	npx moonwave build --code $CODE_PATHS --publish
	;;
*)
	npx moonwave dev --code $CODE_PATHS
	;;
esac
