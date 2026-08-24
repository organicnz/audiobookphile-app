#!/bin/sh
# Re-vendor the pinned agent skills from their upstream repos.
# Usage: scripts/update-agent-skills.sh [latest|<sha>]
# Default: re-checkout the exact pinned commits (idempotent refresh).
set -e

cd "$(dirname "$0")/.."
DEST=".agents/skills"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pin() { echo "$1"; }

declare -u=false
if [ "$1" = "latest" ]; then u=true; fi

fetch() { # repo dir-name pinned-sha
  repo="$1"; name="$2"; sha="$3"
  git clone -q "https://github.com/$repo" "$TMP/$name"
  if $u; then
    sha=$(git -C "$TMP/$name" rev-parse origin/main)
  else
    git -C "$TMP/$name" checkout -q "$sha"
  fi
  echo "pinned $repo @ $sha" >&2
  eval "SHA_$name=$sha"
}

fetch twostraws/Swift-Concurrency-Agent-Skill swift-concurrency-pro bee3f69ba17142da148d3c5406f148ed62592b69
fetch n0an/Background-Execution-Agent-Skill background-execution 27a6e444299082f4437e2a1a2a5ebc8f7f1e1db1
fetch n0an/App-Intents-Agent-Skill app-intents 67cfdc1068b77b3df06d8858a7606b293f5d2b66
fetch n0an/Widgets-Agent-Skill widgets 7ada6aeb6b5dbdafe1cf78088ebe11aad46cd905

cp -R "$TMP/swift-concurrency-pro/swift-concurrency-pro/."        "$DEST/swift-concurrency-pro/"
cp -R "$TMP/background-execution/background-execution/."          "$DEST/background-execution/"
cp -R "$TMP/app-intents/app-intents/."                            "$DEST/app-intents/"
cp -R "$TMP/widgets/widgets/."                                    "$DEST/widgets/"

echo "✓ Vendored into $DEST. Review the diff, update pins in $DEST/README.md, then commit."
echo "  (.claude/skills symlinks follow automatically.)"
