#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

fail() { echo "FAIL: $1"; exit 1; }

# Test 1: branch with ticket ID → shows ticket or [no ticket] (depends on current branch)
OUTPUT=$(echo '{"workspace":{"current_dir":"'"$SCRIPT_DIR"'"}}' | bash "$STATUSLINE")
# Output must be either "🎫 PROJECT-XXXX" or "[no ticket]" — nothing else is valid
[[ "$OUTPUT" =~ ^\[no\ ticket\]$|^🎫\ [A-Z][A-Z0-9]+-[0-9]+ ]] || fail "unexpected format: $OUTPUT"

# Test 2: non-git directory → shows [no ticket]
OUTPUT=$(echo '{"workspace":{"current_dir":"/tmp"}}' | bash "$STATUSLINE")
[ "$OUTPUT" = "[no ticket]" ] || fail "expected '[no ticket]' for /tmp, got: $OUTPUT"

# Test 3: empty cwd → shows [no ticket]
OUTPUT=$(echo '{}' | bash "$STATUSLINE")
[ "$OUTPUT" = "[no ticket]" ] || fail "expected '[no ticket]' for empty cwd, got: $OUTPUT"

echo "OK"
