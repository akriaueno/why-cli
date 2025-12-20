#!/usr/bin/env bash
set -euo pipefail

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -qF "$needle" <<<"$haystack"; then
    echo "Expected output to contain: $needle" >&2
    echo "Actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}
