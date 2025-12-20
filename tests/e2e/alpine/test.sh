#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why
source /test-common.sh

out=$($WHY ls)
assert_contains "$out" "Provider:    apk ("

echo "alpine e2e OK"
