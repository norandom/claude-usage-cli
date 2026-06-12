#!/usr/bin/env bash
# Watch the 5-hour usage bucket and play a sound when little quota is left.
# Usage: ./alert.sh [--interval SEC] [--threshold PCT] [--duration SEC]
#                   [--sound FILE] [ORG_UUID]
# Defaults: check every 60s, alert when <7% remaining, play a 5s sound.
# Each option also reads an env var: INTERVAL, THRESHOLD, ALERT_DURATION, SOUND.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INTERVAL="${INTERVAL:-60}"          # seconds between checks
THRESHOLD="${THRESHOLD:-7}"         # alert when remaining percent is below this
ALERT_DURATION="${ALERT_DURATION:-5}"  # seconds to keep the sound going
SOUND="${SOUND:-/System/Library/Sounds/Sosumi.aiff}"
ORG_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)  INTERVAL="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --duration)  ALERT_DURATION="$2"; shift 2 ;;
    --sound)     SOUND="$2"; shift 2 ;;
    -h|--help)   sed -n '2,7p' "$0" | sed 's/^# //'; exit 0 ;;
    *)           ORG_ARGS+=("$1"); shift ;;
  esac
done

# Play the alert sound for roughly ALERT_DURATION seconds. afplay blocks per
# play (system sounds are ~1s), so loop until the deadline. Falls back to the
# terminal bell when afplay or the sound file is unavailable.
play_alert() {
  local deadline=$(( $(date +%s) + ALERT_DURATION ))
  if command -v afplay >/dev/null 2>&1 && [[ -f "$SOUND" ]]; then
    while [[ "$(date +%s)" -lt "$deadline" ]]; do afplay "$SOUND"; done
  else
    while [[ "$(date +%s)" -lt "$deadline" ]]; do printf '\a'; sleep 1; done
  fi
}

printf 'Watching 5h usage every %ss; alert when <%s%% remains.\n' \
  "$INTERVAL" "$THRESHOLD" >&2

while true; do
  # usage.sh --5h prints e.g. "86.0%" or "-" when the bucket is absent.
  raw="$(cd "$SCRIPT_DIR" && ./usage.sh --5h "${ORG_ARGS[@]}" 2>/dev/null | tr -d '%')"
  stamp="$(date '+%Y-%m-%d %H:%M:%S')"

  if [[ -z "$raw" || "$raw" == "-" ]]; then
    printf '%s  5h usage unavailable\n' "$stamp" >&2
  else
    # Force C locale so the decimal separator stays a dot; a locale comma
    # (e.g. "11,0") would otherwise be string-compared and misfire.
    remaining="$(LC_ALL=C awk -v u="$raw" 'BEGIN { printf "%.1f", 100 - u }')"
    if LC_ALL=C awk -v r="$remaining" -v t="$THRESHOLD" 'BEGIN { exit !(r < t) }'; then
      printf '%s  5h used %s%%, only %s%% left -> ALERT\n' "$stamp" "$raw" "$remaining" >&2
      play_alert
    else
      printf '%s  5h used %s%%, %s%% left\n' "$stamp" "$raw" "$remaining" >&2
    fi
  fi

  sleep "$INTERVAL"
done
