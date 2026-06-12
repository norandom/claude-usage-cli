#!/usr/bin/env bash
# Print Claude usage percentages for an organization.
# Usage: ./usage.sh [--5h | --7d-total] [ORG_UUID]
# Defaults to the lastActiveOrg cookie value, or the first org with claude_max.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE=full
while [[ $# -gt 0 ]]; do
  case "$1" in
    --5h)       MODE=five_hour; shift ;;
    --7d-total) MODE=seven_day; shift ;;
    -h|--help)
      sed -n '2,4p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) break ;;
  esac
done

ORG_UUID="${1:-$LAST_ACTIVE_ORG}"
if [[ -z "$ORG_UUID" ]]; then
  ORG_UUID="$(claude_api organizations | jq -r '
    [.[] | select(.capabilities | index("claude_max"))][0].uuid // .[0].uuid
  ')"
fi

USAGE_JSON="$(claude_api "organizations/$ORG_UUID/usage")"

if [[ "$MODE" != full ]]; then
  echo "$USAGE_JSON" | jq -r --arg k "$MODE" '
    .[$k].utilization | if . == null then "-" else "\(.)%" end
  '
  exit 0
fi

ORG_NAME="$(claude_api organizations | jq -r --arg u "$ORG_UUID" '
  .[] | select(.uuid == $u) | .name // "?"
')"

printf 'Org: %s\n     %s\n\n' "$ORG_NAME" "$ORG_UUID"

echo "$USAGE_JSON" | jq -r '
  def fmt(name; obj):
    if obj == null or obj.utilization == null then
      "\(name): -"
    else
      "\(name): \(obj.utilization)%" +
      (if obj.resets_at then " (resets \(obj.resets_at))" else "" end)
    end;

  # Curated buckets, always shown in this order (even when null).
  ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet",
   "seven_day_cowork", "seven_day_omelette"] as $known |

  fmt("5-hour       "; .five_hour),
  fmt("7-day total  "; .seven_day),
  fmt("7-day Opus   "; .seven_day_opus),
  fmt("7-day Sonnet "; .seven_day_sonnet),
  fmt("7-day Cowork "; .seven_day_cowork),
  fmt("7-day Omelet "; .seven_day_omelette),

  # Any other non-null utilization bucket the API adds later shows up here
  # automatically, so new model codenames are not silently dropped.
  ( to_entries[]
    | select(.key != "extra_usage")
    | select(.value | type == "object" and has("utilization"))
    | select(.value.utilization != null)
    | select([.key] | inside($known) | not)
    | fmt(.key; .value) ),

  # Paid extra usage has a different shape (credits, not utilization-only).
  ( .extra_usage
    | select(. != null)
    | select(.is_enabled)
    | "Extra usage  : \(.utilization)% (\(.used_credits)/\(.monthly_limit) \(.currency))" )
'
