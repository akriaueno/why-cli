#!/usr/bin/env bash
set -euo pipefail

WHY=/usr/local/bin/why

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

make_bin() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat <<'SCRIPT' > "$path"
#!/usr/bin/env sh
echo ok
SCRIPT
  chmod +x "$path"
}

run_and_assert_provider() {
  local expected="$1"
  local cmd="$2"
  local output
  output=$("$WHY" "$cmd")
  assert_contains "$output" "Provider:    $expected"
}

# dpkg
PATH="/bin:$PATH" out=$($WHY bash)
assert_contains "$out" "Provider:    apt/dpkg ("

# MacPorts
make_bin /opt/local/bin/port
PATH="/opt/local/bin:$PATH" run_and_assert_provider "MacPorts" "port"

# Nix
make_bin /nix/store/test/bin/nix
PATH="/nix/store/test/bin:$PATH" run_and_assert_provider "Nix" "nix"

# asdf
make_bin /root/.asdf/shims/node
PATH="/root/.asdf/shims:$PATH" run_and_assert_provider "asdf" "node"

# SDKMAN!
make_bin /root/.sdkman/candidates/java/current/bin/java
PATH="/root/.sdkman/candidates/java/current/bin:$PATH" run_and_assert_provider "SDKMAN!" "java"

# nvm
make_bin /root/.nvm/versions/node/v20.0.0/bin/node
PATH="/root/.nvm/versions/node/v20.0.0/bin:$PATH" run_and_assert_provider "nvm" "node"

# fnm
make_bin /root/.local/share/fnm/node-versions/v20.0.0/installation/bin/node
PATH="/root/.local/share/fnm/node-versions/v20.0.0/installation/bin:$PATH" run_and_assert_provider "fnm" "node"

# pyenv
make_bin /root/.pyenv/shims/python
PATH="/root/.pyenv/shims:$PATH" run_and_assert_provider "pyenv" "python"

# rbenv
make_bin /root/.rbenv/shims/ruby
PATH="/root/.rbenv/shims:$PATH" run_and_assert_provider "rbenv" "ruby"

# rvm
make_bin /root/.rvm/rubies/ruby-3.2.2/bin/ruby
PATH="/root/.rvm/rubies/ruby-3.2.2/bin:$PATH" run_and_assert_provider "rvm" "ruby"

# rustup (symlink from cargo bin to rustup toolchain)
make_bin /root/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc
mkdir -p /root/.cargo/bin
ln -sf /root/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc /root/.cargo/bin/rustc
PATH="/root/.cargo/bin:$PATH" run_and_assert_provider "Rustup" "rustc"

# conda
make_bin /root/miniconda3/bin/python
PATH="/root/miniconda3/bin:$PATH" run_and_assert_provider "Conda" "python"

# mise
make_bin /root/.local/share/mise/shims/node
PATH="/root/.local/share/mise/shims:$PATH" run_and_assert_provider "Mise" "node"

# volta
make_bin /root/.volta/bin/node
PATH="/root/.volta/bin:$PATH" run_and_assert_provider "Volta" "node"

echo "ubuntu e2e OK"
