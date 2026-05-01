# claude-usage-cli

Print your Claude.ai usage from the command line.

Claude.ai has a private endpoint at `/api/organizations/{uuid}/usage`. These scripts call it and route the request through `curl-impersonate` so Cloudflare lets it through.

## Requirements

- bash
- jq
- docker (pulls `lwthiker/curl-impersonate:0.6-chrome` on first run)
- A Claude.ai account
- The [Cookie Editor](https://cookie-editor.com/) browser extension

## Setup

1. Sign in to https://claude.ai.
2. Open Cookie Editor on the claude.ai tab, Export → JSON, save the result as `cookie.json` next to the scripts.

The scripts read `sessionKey` and the other claude.ai cookies straight from that file (Cloudflare wants the whole jar, not just the session key).

## Usage

List your organizations:

    ./orgs.sh

Usage for your default org (uses the `lastActiveOrg` cookie):

    ./usage.sh

Just one number (handy for status bars and shell prompts):

    ./usage.sh --5h         # 93.0%
    ./usage.sh --7d-total   # 32.0%

Usage for a specific org:

    ./usage.sh <org-uuid>

Example output:

    Org: name@example.com's Organization
         9b90e33b-fac4-4762-9f2e-8f92152654fb

    5-hour       : 92.0% (resets 2026-05-01T20:00:00Z)
    7-day total  : 32.0% (resets 2026-05-04T17:00:00Z)
    7-day Sonnet : 0.0%

## Notes

`cookie.json` holds a live session token and is gitignored. Don't paste it anywhere public.

When the scripts start returning 401, the cookie has expired — re-export it.
