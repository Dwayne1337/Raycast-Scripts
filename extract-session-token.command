#!/bin/bash

# @raycast.title Extract Session Token
# @raycast.mode fullOutput
# @raycast.packageName Helpers
# @raycast.schemaVersion 1

set -euo pipefail

read_clipboard() {
  /usr/bin/pbpaste -Prefer txt 2>/dev/null || true
}

# Extract `sessiontoken` from `email:password:sessiontoken` where:
# - email is before the first colon and must contain '@'
# - token is everything after the second colon
extract_tokens() {
  /usr/bin/awk '
    function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }

    {
      line = trim($0)
      if (line == "") next

      first = index(line, ":")
      if (first == 0) next

      email = trim(substr(line, 1, first - 1))
      if (email == "" || index(email, "@") == 0) next

      rest = substr(line, first + 1)
      second_rel = index(rest, ":")
      if (second_rel == 0) next

      token = trim(substr(rest, second_rel + 1))
      if (token == "") next

      if (printed++) print ""
      print token
    }
  '
}

read_clipboard | extract_tokens
