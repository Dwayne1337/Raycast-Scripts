#!/bin/bash

# @raycast.title Extract Email:Password
# @raycast.mode fullOutput
# @raycast.packageName Helpers
# @raycast.schemaVersion 1

set -euo pipefail

read_clipboard() {
  /usr/bin/pbpaste -Prefer txt 2>/dev/null || true
}

# Extract `email:password` where:
# - email is before the first colon and must contain '@'
# - password is after the first colon up to the next colon (if present)
extract_pairs() {
  # Use awk for robust splitting + trimming.
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
      if (second_rel == 0) {
        pw = trim(rest)
      } else {
        pw = trim(substr(rest, 1, second_rel - 1))
      }

      if (pw == "") next
      print email ":" pw
    }
  '
}

read_clipboard | extract_pairs
