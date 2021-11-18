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
  --d:release
  --d:mingw
  --cpu:amd64
  setCommand "c", "src/main"

