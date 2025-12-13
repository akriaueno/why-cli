#!/bin/bash

set -eux

VERSION=$1
URL=$2
SHA256=$3

NIMBLE_FILE="why_cli.nimble"

if [ ! -f "$NIMBLE_FILE" ]; then
    echo "Error: $NIMBLE_FILE not found." >&2
    exit 1
fi

get_nimble_version() {
    local pkg_name=$1
    # Extract version from lines like: requires "cligen >= 1.7.0"
    grep "requires \"$pkg_name" "$NIMBLE_FILE" | sed -E 's/.*>= *([0-9.]+).*/\1/'
}

generate_resource() {
    local name=$1
    local repo_url_base=$2
    
    local ver=$(get_nimble_version "$name")
    
    if [ -z "$ver" ]; then
        echo "Error: Could not find version for $name in $NIMBLE_FILE" >&2
        exit 1
    fi

    local dl_url="${repo_url_base}/archive/refs/tags/${ver}.tar.gz"

    local tmp_file="/tmp/${name}-${ver}.tar.gz"

    curl -sL "$dl_url" -o "$tmp_file"
    local sha=$(sha256sum "$tmp_file" | awk '{print $1}')
    rm "$tmp_file"

    echo "  resource \"$name\" do"
    echo "    url \"$dl_url\""
    echo "    sha256 \"$sha\""
    echo "  end"
}

cat <<EOF
class Why < Formula
  desc "Show where a command on your system really comes from"
  homepage "https://github.com/akriaueno/why-cli"
  url "${URL}"
  sha256 "${SHA256}"
  license "MIT"

  depends_on "nim" => :build

EOF

# Define dependencies here. The version is auto-detected from .nimble.
generate_resource "cligen" "https://github.com/c-blake/cligen"

cat <<EOF

  def install
    resource("cligen").stage do
      (buildpath/"vendor/cligen").install Dir["*"]
    end

    system "nim", "c", "-d:release", "--path:#{buildpath}/vendor/cligen", "-o:why", "src/why.nim"
    bin.install "why"
  end

  test do
    system "#{bin}/why", "--help"
  end
end
EOF
