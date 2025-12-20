#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why
source /test-common.sh

out=$($WHY ls)
assert_contains "$out" "Provider:    zypper/rpm ("

echo "opensuse e2e OK"
