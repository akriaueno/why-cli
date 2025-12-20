#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DISTROS=(ubuntu fedora opensuse alpine arch gentoo)

if [[ $# -gt 0 ]]; then
  DISTROS=("$@")
fi

jobs=${E2E_JOBS:-$(nproc 2>/dev/null || echo 4)}

run_one() {
  local distro="$1"
  local image="why-e2e-${distro}"
  local dockerfile="$ROOT_DIR/tests/e2e/${distro}/Dockerfile"
  if [[ ! -f "$dockerfile" ]]; then
    echo "Missing Dockerfile for ${distro}: ${dockerfile}" >&2
    return 1
  fi

  echo "==> Building ${image}"
  docker build --progress=plain -f "$dockerfile" -t "$image" "$ROOT_DIR"
  echo "==> Running ${image}"
  docker run --rm "$image"
  echo "==> ${distro} OK"
  echo
}

if command -v parallel >/dev/null 2>&1; then
  export ROOT_DIR
  export -f run_one
  parallel --line-buffer --tag --halt now,fail=1 --jobs "$jobs" run_one ::: "${DISTROS[@]}"
else
  printf '%s\n' "${DISTROS[@]}" | xargs -I{} -P "$jobs" bash -c '
    set -euo pipefail
    ROOT_DIR="$1"
    distro="$2"
    image="why-e2e-${distro}"
    dockerfile="$ROOT_DIR/tests/e2e/${distro}/Dockerfile"
    if [[ ! -f "$dockerfile" ]]; then
      echo "Missing Dockerfile for ${distro}: ${dockerfile}" >&2
      exit 1
    fi

    echo "==> Building ${image}"
    docker build --progress=plain -f "$dockerfile" -t "$image" "$ROOT_DIR"
    echo "==> Running ${image}"
    docker run --rm "$image"
    echo "==> ${distro} OK"
    echo
  ' _ "$ROOT_DIR" {}
fi
