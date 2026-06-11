#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# pin_xcode_version.sh
#
# Programmatically pins all Xcode Cloud workflows to a stable Xcode version
# using the App Store Connect API.
#
# Prerequisites:
#   1. An App Store Connect API Key (.p8 file)
#      → Create at: https://appstoreconnect.apple.com/access/integrations/api
#      → Needs "Admin" or "App Manager" role
#   2. The Key ID and Issuer ID from the same page
#
# Usage:
#   export ASC_KEY_ID="XXXXXXXXXX"
#   export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
#
#   ./scripts/pin_xcode_version.sh                    # List Xcode versions + workflows
#   ./scripts/pin_xcode_version.sh list-versions       # List available Xcode versions
#   ./scripts/pin_xcode_version.sh list-workflows      # List workflows
#   ./scripts/pin_xcode_version.sh pin "Xcode 16.4"   # Pin all workflows to 16.4
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Validate env ──
: "${ASC_KEY_ID:?Set ASC_KEY_ID to your App Store Connect API Key ID}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID to your App Store Connect Issuer ID}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH to the path of your .p8 private key file}"

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo "ERROR: Private key not found at: $ASC_KEY_PATH" >&2
  exit 1
fi

API_BASE="https://api.appstoreconnect.apple.com/v1"

# ── Generate JWT ──
generate_jwt() {
  local now
  now=$(date +%s)
  local exp=$((now + 1200))  # 20 minutes

  local header
  header=$(printf '{"alg":"ES256","kid":"%s","typ":"JWT"}' "$ASC_KEY_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

  local payload
  payload=$(printf '{"iss":"%s","iat":%d,"exp":%d,"aud":"appstoreconnect-v1"}' "$ASC_ISSUER_ID" "$now" "$exp" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

  local signature
  signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$ASC_KEY_PATH" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

  printf '%s.%s.%s' "$header" "$payload" "$signature"
}

api_get() {
  local path="$1"
  local token
  token=$(generate_jwt)
  curl -sf -H "Authorization: Bearer $token" -H "Content-Type: application/json" "${API_BASE}${path}"
}

api_patch() {
  local path="$1"
  local body="$2"
  local token
  token=$(generate_jwt)
  curl -sf -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${API_BASE}${path}"
}

# ── Commands ──

list_versions() {
  echo "📋 Available Xcode versions on Xcode Cloud:"
  echo ""
  api_get "/ciXcodeVersions?limit=20" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for v in data.get('data', []):
    attrs = v.get('attributes', {})
    name = attrs.get('name', '?')
    version = attrs.get('version', '?')
    vid = v.get('id', '?')
    print(f'  {name:<20} version={version:<10} id={vid}')
" 2>/dev/null || {
    echo "  (Could not parse response — raw output below)"
    api_get "/ciXcodeVersions?limit=20" | python3 -m json.tool 2>/dev/null || api_get "/ciXcodeVersions?limit=20"
  }
}

list_workflows() {
  echo "📋 Xcode Cloud workflows:"
  echo ""
  # First get the product ID
  local products
  products=$(api_get "/ciProducts?limit=10")

  echo "$products" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('data', []):
    attrs = p.get('attributes', {})
    name = attrs.get('name', '?')
    pid = p.get('id', '?')
    ptype = attrs.get('productType', '?')
    print(f'  Product: {name} (type={ptype}, id={pid})')
" 2>/dev/null

  # Get workflows for each product
  echo ""
  local product_ids
  product_ids=$(echo "$products" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('data', []):
    print(p['id'])
" 2>/dev/null)

  for pid in $product_ids; do
    api_get "/ciProducts/$pid/workflows?limit=20" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('data', []):
    attrs = w.get('attributes', {})
    name = attrs.get('name', '?')
    wid = w.get('id', '?')
    xcode_ver = attrs.get('xcodeVersion', {})
    if isinstance(xcode_ver, dict):
        xv = xcode_ver.get('name', xcode_ver.get('version', '?'))
    else:
        xv = str(xcode_ver) if xcode_ver else '?'
    print(f'  Workflow: {name:<30} xcode={xv:<15} id={wid}')
" 2>/dev/null || {
      echo "  Fetching workflows with include..."
      api_get "/ciProducts/$pid/workflows?limit=20&include=xcodeVersion" | python3 -m json.tool 2>/dev/null | head -60
    }
  done
}

pin_version() {
  local target_name="${1:?Usage: pin_xcode_version.sh pin \"Xcode 16.4\"}"

  echo "🔍 Finding Xcode version matching: '$target_name'..."
  local versions_json
  versions_json=$(api_get "/ciXcodeVersions?limit=20")

  local target_id
  target_id=$(echo "$versions_json" | python3 -c "
import json, sys
target = sys.argv[1]
data = json.load(sys.stdin)
for v in data.get('data', []):
    attrs = v.get('attributes', {})
    name = attrs.get('name', '')
    if target.lower() in name.lower():
        print(v['id'])
        break
" "$target_name" 2>/dev/null)

  if [ -z "$target_id" ]; then
    echo "ERROR: No Xcode version found matching '$target_name'" >&2
    echo "Available versions:"
    list_versions
    exit 1
  fi
  echo "  ✅ Found: id=$target_id"

  # Get all workflows
  echo ""
  echo "🔍 Finding all workflows..."
  local products
  products=$(api_get "/ciProducts?limit=10")
  local product_ids
  product_ids=$(echo "$products" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('data', []):
    print(p['id'])
" 2>/dev/null)

  local updated=0
  for pid in $product_ids; do
    local workflows_json
    workflows_json=$(api_get "/ciProducts/$pid/workflows?limit=20")

    local workflow_ids
    workflow_ids=$(echo "$workflows_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('data', []):
    print(w['id'])
" 2>/dev/null)

    for wid in $workflow_ids; do
      local wname
      wname=$(echo "$workflows_json" | python3 -c "
import json, sys
wid = sys.argv[1]
data = json.load(sys.stdin)
for w in data.get('data', []):
    if w['id'] == wid:
        print(w.get('attributes', {}).get('name', '?'))
        break
" "$wid" 2>/dev/null)

      echo "  📌 Pinning workflow '$wname' ($wid) → $target_name..."

      local patch_body
      patch_body=$(python3 -c "
import json
body = {
    'data': {
        'type': 'ciWorkflows',
        'id': '$wid',
        'relationships': {
            'xcodeVersion': {
                'data': {
                    'type': 'ciXcodeVersions',
                    'id': '$target_id'
                }
            }
        }
    }
}
print(json.dumps(body))
")

      if api_patch "/ciWorkflows/$wid" "$patch_body" > /dev/null 2>&1; then
        echo "     ✅ Done"
        updated=$((updated + 1))
      else
        echo "     ❌ Failed — check API key permissions"
      fi
    done
  done

  echo ""
  echo "🎉 Updated $updated workflow(s) to $target_name"
  echo ""
  echo "Trigger a new build to use the updated Xcode version."
}

# ── Main ──
case "${1:-help}" in
  list-versions)
    list_versions
    ;;
  list-workflows)
    list_workflows
    ;;
  pin)
    pin_version "${2:-}"
    ;;
  help|--help|-h)
    echo "Usage:"
    echo "  $0 list-versions              List available Xcode versions"
    echo "  $0 list-workflows             List Xcode Cloud workflows"
    echo "  $0 pin \"Xcode 16.4\"           Pin all workflows to a version"
    echo ""
    echo "Required env vars:"
    echo "  ASC_KEY_ID       App Store Connect API Key ID"
    echo "  ASC_ISSUER_ID    App Store Connect Issuer ID"
    echo "  ASC_KEY_PATH     Path to .p8 private key file"
    ;;
  *)
    echo "Unknown command: $1 (use --help)" >&2
    exit 1
    ;;
esac
