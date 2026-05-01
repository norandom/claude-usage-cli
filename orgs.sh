#!/usr/bin/env bash
# List Claude organizations the session has access to.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

claude_api organizations | jq -r '
  ["UUID", "NAME", "TIER", "CAPABILITIES"],
  (.[] | [
    .uuid,
    .name,
    (.rate_limit_tier // "-"),
    (.capabilities | join(","))
  ])
  | @tsv
' | column -t -s $'\t'
