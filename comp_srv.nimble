# Package

version       = "0.1.0"
author        = "OscarAndre1"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["comp_srv"]



# Dependencies

requires "nim >= 1.0.0"
requires "NimYAML"
requires "cligen"

# Tasks 

task cross, "Cross-compile":
  --d:release
  --d:mingw
  --cpu:amd64
  setCommand "c", "src/comp_srv"
