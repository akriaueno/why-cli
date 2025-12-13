#!/bin/bash
# .github/scripts/generate_formula.sh

set -eux

VERSION=$1
URL=$2
SHA256=$3

CLEAN_VERSION="${VERSION#v}"

cat <<EOF
class Why < Formula
  desc "Why are you in my computer?"
  homepage "https://github.com/akriaueno/why-cli"
  url "${URL}"
  sha256 "${SHA256}"
  license "MIT"
  version "${CLEAN_VERSION}"

  depends_on "nim" => :build

  def install
    system "nimble", "build", "-Y", "-d:release", "--noNimblePath"
    bin.install "why"
  end

  test do
    system "#{bin}/why", "--help"
  end
end
EOF