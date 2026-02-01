#!/bin/bash

# @raycast.title Escape JSON String (Clipboard)
# @raycast.mode compact
# @raycast.packageName Helpers
# @raycast.schemaVersion 1
# @raycast.description Converts clipboard text into a valid JSON string literal and copies it back to the clipboard.

set -euo pipefail

read_clipboard() {
  /usr/bin/pbpaste -Prefer txt 2>/dev/null || true
}

escape_json_string() {
  /usr/bin/python3 -c 'import json,sys; sys.stdout.write(json.dumps(sys.stdin.read(), ensure_ascii=False))'
}

main() {
  local tmp
  tmp="$(/usr/bin/mktemp -t raycast-json-escape.XXXXXX)"
  trap '/bin/rm -f "$tmp"' EXIT

  read_clipboard >"$tmp"

  if [[ ! -s "$tmp" ]]; then
    echo "Clipboard is empty."
    exit 1
  fi

  escape_json_string <"$tmp" | /usr/bin/pbcopy
  echo "Copied JSON string to clipboard."
}

main "$@"
