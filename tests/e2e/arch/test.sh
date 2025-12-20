#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why
source /test-common.sh

out=$($WHY ls)
assert_contains "$out" "Provider:    pacman ("

echo "arch e2e OK"
