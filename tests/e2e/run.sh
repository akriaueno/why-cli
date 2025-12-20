#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DISTROS=(ubuntu fedora opensuse alpine arch gentoo)

if [[ $# -gt 0 ]]; then
  DISTROS=("$@")
fi

for distro in "${DISTROS[@]}"; do
  image="why-e2e-${distro}"
  dockerfile="$ROOT_DIR/tests/e2e/${distro}/Dockerfile"
  if [[ ! -f "$dockerfile" ]]; then
    echo "Missing Dockerfile for ${distro}: ${dockerfile}" >&2
    exit 1
  fi

  echo "==> Building ${image}"
  docker build -f "$dockerfile" -t "$image" "$ROOT_DIR"
  echo "==> Running ${image}"
  docker run --rm "$image"
  echo "==> ${distro} OK"
  echo
  

done
