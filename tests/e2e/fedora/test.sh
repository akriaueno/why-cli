#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why
source /test-common.sh

out=$($WHY ls)
assert_contains "$out" "Provider:    yum/rpm ("

echo "fedora e2e OK"
