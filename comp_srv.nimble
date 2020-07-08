# Package

version       = "0.2.0"
author        = "OscarAndre1"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["comp_srv", "update"]



# Dependencies

requires "nim >= 1.0.0"
requires "NimYAML"
requires "cligen"
requires "github_api >= 0.1.0"

# Tasks 

task cross, "Cross-compile":
  --d:release
  --d:mingw
  --cpu:amd64
  setCommand "c", "src/comp_srv"

task dll, "Dynamically linked library":
  --d:release
  --app:lib
  --noMain
  --header
  --d:useNimRtl
  setCommand "c", "src/srvcom"

task rtl, "Run Time Library":
  --d:release
  --d:createNimRtl
  --app:lib
  setCommand "c", "src/nimrtl"