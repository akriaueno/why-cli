#!/bin/bash

set -eux

VERSION=$1
URL=$2
SHA256=$3

if [ ! -f "Cargo.toml" ]; then
    echo "Error: Cargo.toml not found." >&2
    exit 1
fi

cat <<EOF
class Why < Formula
  desc "Show where a command on your system really comes from"
  homepage "https://github.com/akriaueno/why-cli"
  url "${URL}"
  sha256 "${SHA256}"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--locked", "--path", ".", "--root", prefix
  end

  test do
    system "#{bin}/why", "--help"
  end
end
EOF
