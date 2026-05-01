#!/usr/bin/env bash
# Shared helpers: read sessionKey + lastActiveOrg from cookie.json and call the API.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIE_FILE="${COOKIE_FILE:-$SCRIPT_DIR/cookie.json}"

if [[ ! -f "$COOKIE_FILE" ]]; then
  echo "cookie.json not found at $COOKIE_FILE" >&2
  exit 1
fi

cookie_value() {
  jq -r --arg n "$1" '
    map(select(.name == $n)) | .[0].value // empty
  ' "$COOKIE_FILE"
}

SESSION_KEY="$(cookie_value sessionKey)"
if [[ -z "$SESSION_KEY" ]]; then
  echo "sessionKey cookie missing from $COOKIE_FILE" >&2
  exit 1
fi

LAST_ACTIVE_ORG="$(cookie_value lastActiveOrg || true)"

# Build a Cookie header from every cookie scoped to claude.ai. Cloudflare
# rejects the request unless __cf_bm and friends ride along.
COOKIE_HEADER="$(jq -r '
  map(select(.domain | test("claude\\.ai$")))
  | map("\(.name)=\(.value)")
  | join("; ")
' "$COOKIE_FILE")"

CURL_IMAGE="${CURL_IMAGE:-lwthiker/curl-impersonate:0.6-chrome}"
CURL_BIN="${CURL_BIN:-curl_chrome116}"

# Calls Claude's API via curl-impersonate (Chrome TLS fingerprint) so we get
# past Cloudflare's bot challenge. Plain curl is rejected with a 403.
claude_api() {
  docker run --rm -i "$CURL_IMAGE" "$CURL_BIN" -fsS "https://claude.ai/api/$1" \
    -H "Cookie: $COOKIE_HEADER" \
    -H 'Accept: application/json' \
    -H 'Referer: https://claude.ai/settings/usage' \
    -H 'anthropic-client-platform: web_claude_ai' \
    -H 'anthropic-client-version: 1.0.0'
}
