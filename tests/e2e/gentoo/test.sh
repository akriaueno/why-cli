#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why
source /test-common.sh

PATH="/bin:$PATH" out=$($WHY bash)
assert_contains "$out" "Provider:    portage ("

echo "gentoo e2e OK"
