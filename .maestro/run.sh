#!/bin/bash
# Maestro e2e runner for the Audiobookphile app (iOS simulator first-class;
# the same flows run on Android once an emulator is connected).
#
# Usage:
#   .maestro/run.sh                # everything tagged smoke+e2e (default CI set)
#   .maestro/run.sh smoke          # fast launch smoke, no credentials needed
#   .maestro/run.sh e2e            # tagged e2e (needs .maestro/.env)
#   .maestro/run.sh auth           # tagged auth
#   .maestro/run.sh flows/10_auth_login.yaml   # a single flow file
#   .maestro/run.sh --android      # repeat any of the above on a device
set -euo pipefail
cd "$(dirname "$0")/.."

APP_BUNDLE_ID="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = .*' Skip.env | awk '{print $3}')"
# Newest built app across any derived-data directory (find order is not
# mtime order — sort by modification time so we never test a stale build).
APP_PATH="$(find DerivedData .build -path '*Products*' -name 'Audiobookphile.app' -type d 2>/dev/null -exec stat -f '%m %N' {} \; | sort -rn | head -n 1 | sed 's/^[0-9]* //')"

if [ -z "${APP_PATH:-}" ]; then
  echo "error: no Audiobookphile.app under DerivedData — build first, e.g."
  echo "  ABP_PROJECT_DIR=\$PWD ABP_SIMULATOR_ID=<udid> ABP_BUNDLE_ID=\$APP_BUNDLE_ID scripts/build_and_run.sh"
  exit 1
fi

if [ -f .maestro/.env ]; then
  set -a; . .maestro/.env; set +a
fi

# Bake runtime config into the built app's Info.plist. Values cannot travel
# via Skip.env: xcconfig treats '//' as a comment, so URLs truncate ('http:')
# and the placeholder anon key ('testkey') gets baked instead — the app then
# sends a garbage apikey and every login 401s. Patching the built plist (then
# re-signing ad hoc, which the simulator accepts) sidesteps xcconfig entirely.
patch_app_plist() {
  local web_env="../audiobookphile-web/.env.local"
  local sb_url sb_key
  sb_url="$(grep -E '^NEXT_PUBLIC_SUPABASE_URL=' "$web_env" 2>/dev/null | cut -d= -f2- | tr -d '"')"
  sb_key="$(grep -E '^NEXT_PUBLIC_SUPABASE_ANON_KEY=' "$web_env" 2>/dev/null | cut -d= -f2- | tr -d '"')"
  [ -n "${SERVER_URL:-}" ] && plutil -replace ServerURL -string "$SERVER_URL" "$1/Info.plist"
  [ -n "$sb_url" ] && plutil -replace SupabaseURL -string "$sb_url" "$1/Info.plist"
  [ -n "$sb_key" ] && plutil -replace SupabaseAnonKey -string "$sb_key" "$1/Info.plist"
  codesign -f -s - "$1" >/dev/null 2>&1 || true
  echo "patched Info.plist (ServerURL${sb_url:+, SupabaseURL${sb_key:+, SupabaseAnonKey}})"
}
patch_app_plist "$APP_PATH"

# Maestro resolves ${VAR} in flows only from `-e KEY=VALUE` CLI flags, not the
# process environment — forward the credential vars explicitly.
ENV_ARGS=""
for VAR in SERVER_URL TEST_EMAIL TEST_PASSWORD MAGIC_LINK_URL; do
  if [ -n "${!VAR:-}" ]; then
    ENV_ARGS="$ENV_ARGS -e $VAR=${!VAR}"
  fi
done

# Flags are plain strings, not arrays: macOS ships bash 3.2, where `set -u`
# treats empty arrays as unbound variables.
TARGET=""
if [ "${1:-}" = "--android" ]; then
  shift
  TARGET="--device android"
else
  # Install (or refresh) the app on every booted simulator so flows test the
  # current build rather than whatever is stale on the device.
  BOOTED="$(xcrun simctl list devices booted -j | /usr/bin/python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        print(d["udid"])')"
  if [ -z "$BOOTED" ]; then
    echo "error: no booted simulator — open Simulator.app first (or pass --android)"
    exit 1
  fi
  for UDID in $BOOTED; do
    xcrun simctl install "$UDID" "$APP_PATH" && echo "installed on $UDID"
  done
fi

# The deeplink flow needs a fresh single-use MAGIC_LINK_URL; skip it when the
# env var is not set instead of failing on an empty openLink.
EXCLUDE_DEEPLINK=""
if [ -z "${MAGIC_LINK_URL:-}" ]; then
  EXCLUDE_DEEPLINK="--exclude-tags deeplink"
fi

case "${1:-}" in
  smoke) exec maestro test $TARGET $ENV_ARGS --include-tags smoke .maestro/flows ;;
  e2e)   exec maestro test $TARGET $ENV_ARGS --include-tags e2e  .maestro/flows ;;
  auth)  exec maestro test $TARGET $ENV_ARGS --include-tags auth $EXCLUDE_DEEPLINK .maestro/flows ;;
  "")    exec maestro test $TARGET $ENV_ARGS --include-tags smoke,e2e .maestro/flows ;;
  *)
    case "$1" in
      /*) FLOW_PATH="$1" ;;
      *)  FLOW_PATH=".maestro/$1" ;;
    esac
    exec maestro test $TARGET $ENV_ARGS "$FLOW_PATH"
    ;;
esac
