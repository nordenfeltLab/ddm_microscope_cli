# Package

version       = "0.2.0"
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

task dll, "Dynamically linked library":
  --app:lib
  --threads:off
  --d:debug
  --noMain
  --header
  --d:useNimRtl
  setCommand "c", "src/srvcom"

task rtl, "Run Time Library":
  --app:lib
  --d:debug
  --threads:off
  --d:createNimRtl
  
  setCommand "c", "src/nimrtl"