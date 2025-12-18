# Package

version       = "0.1.0"
author        = "akira ueno"
description   = "Tells you why a command is installed on your system."
license       = "MIT"
srcDir        = "src"
bin           = @["why"]

# Dependencies
requires "nim >= 2.2.6"
requires "cligen >= 1.7.0"

task test, "Run unit tests":
  exec "nim c -r tests/test_why_core.nim"
