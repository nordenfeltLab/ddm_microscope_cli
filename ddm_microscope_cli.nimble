# Package
version       = "0.3.0"
author        = "OscarAndre1"
description   = "A lightweight cli for writing and sending local data to the DDM Framework."
license       = "MIT"
srcDir        = "src"
bin           = @["main"]


# Dependencies
requires "nim >= 1.6.0"
requires "cligen"


# Tasks 
task cross, "Cross-compile":
  exec "nim c --d:release --d:mingw --cpu:amd64 --out:bin/win-main.exe src/main"
  exec "nim c --d:release --os:MacOSX --cpu:amd64 --cc:clang --passC:'-target x86_64-apple-darwin' --passL:'-target x86_64-apple-darwin' --out:bin/mac-x86_64-main src/main"
  exec "nim c --d:release --os:MacOSX --cpu:arm64 --cc:clang --passC:'-target aarch64-apple-darwin' --passL:'-target aarch64-apple-darwin' --out:bin/mac-m1-main src/main"
  exec "nim c --d:release --os:MacOSX --cpu:arm64 --out:bin/mac-arm64-main src/main"

