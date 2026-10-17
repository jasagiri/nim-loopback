# Package
version       = "0.1.0"
author        = "GodsGolemInc"
description   = "Whether a host, a host:port or a URL names this machine's loopback — one rule (127.0.0.0/8, ::1, localhost) for listening addresses, Host headers and URLs"
license       = "Apache-2.0"
srcDir        = "src"

requires "nim >= 2.0.0"

task test, "Run tests":
  exec "nim c -r --hints:off tests/test_loopback.nim"
