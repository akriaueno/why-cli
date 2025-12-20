#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DISTROS=(ubuntu fedora opensuse alpine arch gentoo)
BUILDER_IMAGE="why-e2e-builder"
BUILDER_DOCKERFILE="$ROOT_DIR/tests/e2e/Builder.Dockerfile"
BIN_PATH="$ROOT_DIR/tests/e2e/why-linux-amd64"

if [[ $# -gt 0 ]]; then
  DISTROS=("$@")
fi

jobs=${E2E_JOBS:-$(nproc 2>/dev/null || echo 4)}

build_binary() {
  if [[ ! -f "$BUILDER_DOCKERFILE" ]]; then
    echo "Missing builder Dockerfile: ${BUILDER_DOCKERFILE}" >&2
    return 1
  fi

  echo "==> Building why binary"
  docker build --progress=plain -f "$BUILDER_DOCKERFILE" -t "$BUILDER_IMAGE" "$ROOT_DIR"
  local container_id
  container_id=$(docker create "$BUILDER_IMAGE")
  docker cp "$container_id":/usr/local/bin/why "$BIN_PATH"
  docker rm -v "$container_id" >/dev/null
  chmod +x "$BIN_PATH"
  echo "==> Binary ready: ${BIN_PATH}"
  echo
}

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

build_binary

if command -v parallel >/dev/null 2>&1; then
  export ROOT_DIR
  export -f run_one
  parallel --line-buffer --tag --halt now,fail=1 --jobs "$jobs" run_one ::: "${DISTROS[@]}"
else
  pids=()
  fail=0

  prune_pids() {
    local alive=()
    local pid
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        alive+=("$pid")
      fi
    done
    pids=("${alive[@]}")
  }

  wait_any() {
    if wait -n 2>/dev/null; then
      prune_pids
      return 0
    fi
    local pid="${pids[0]:-}"
    if [[ -n "$pid" ]]; then
      wait "$pid"
      local status=$?
      prune_pids
      return "$status"
    fi
    return 0
  }

  for distro in "${DISTROS[@]}"; do
    run_one "$distro" &
    pids+=("$!")
    while ((${#pids[@]} >= jobs)); do
      if ! wait_any; then
        fail=1
        break
      fi
    done
    if ((fail)); then
      break
    fi
  done

  if ((fail)); then
    for pid in "${pids[@]}"; do
      kill "$pid" 2>/dev/null || true
    done
  fi

  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      fail=1
    fi
  done

  if ((fail)); then
    exit 1
  fi
fi
