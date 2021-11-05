import strutils, strformat, options
import httpClient, os, system, uri
import cligen
import logging
#import streams, tables
import json
import error_handler

# -- EXE COMPILATION
proc send(address         = "http://localhost:4443",
          img_path        = "images",
          reponse_path    = "reponse.txt",
          sync_path       = "sync.txt",
          logging_path    = "log.txt",
          root_dir        = getCurrentDir(),
          ) : int =
  
  errorHandling(root_dir, logging_path, sync_path):

    discard sendImage(address, img_path, root_dir, sync_path)
    info("Got response from server.")

dispatchMulti([send, help  = {"address"       : "Server address, e.g 'http://localhost:4444'.",
                              "img_path"      : "Filename of the image to be sent.",
                              "root_dir"      : "Path to root directory.",
                              "sync_path"     : "Filename for sync-status."}],
              [fetch, help = {"address"       : "Server address.",
                              "sync_path"     : "Filename for sync-status.",
                              "response_path" : "Filename of response-dump.",
                              "logging_path"  : "Filename for logging.",
                              "root_dir"      : "Path to root directory.",
                              "queryString"   : "Query."
                      }]
          )
# -- UTILS
proc writePositions(output_path : string,
                     stage_x : openArray[JsonNode],
                     stage_y : openArray[JsonNode]
                     ) =

    let f = open(output_path, fmWrite)
    defer: close(f)
    for i in low(stage_x)..high(stage_x):
      let lines = [fmt"stage_x={stage_x[i]}", fmt"stage_y={stage_y[i]}"]
      for line in lines:
        f.writeLine(line)

proc fetch*(address      = "http://localhost:4443",
            sync_path    = "sync.txt",
            reponse_path = "response.txt",
            logging_path = "log.txt",
            root_dir     = getCurrentDir(),
            queryString  : string
          ): int =

  errorHandling(root_dir, logging_path, sync_path):
    let client = newHttpClient()
    let response = client.getContent(address & queryString).parseJson
    if response["response"].getBool: #this will change to write response dynamically
      writePositions(root_dir / reponse_path,
        response["stage_pos_x"].getElems,
        response["stage_pos_y"].getElems
        )
      info("Wrote coordinates to response dump.")
      
    writeFile(root_dir / sync_path, response["response"].str)

proc loadLatestImage*(img_path : string): string =
  var latest = none(string)
  for fname in walkFiles(img_path / "*"):
    if latest.isNone or fileNewer(fname, get(latest)):
      latest = some(fname)

  if latest.isSome:
    return readFile(get(latest))
  return readFile(img_path)

proc sendImage*(address : string,
              img_path : string,
              root_dir : string,
              sync_path : string,
              ) : JsonNode =

  var client = newHttpClient()
  var data = newMultipartData()

  info("Loading image from: " & root_dir / img_path)
  let img = loadLatestImage(root_dir / img_path)
  data["image"] = ("img.nd2", "image/nd2", img) #handle multipart for tif/nd2 etc dynamically...
  info("Image loaded...")

  let response = client.postContent(address, multipart = data).parseJson
  writeFile(root_dir / sync_path, response["response"].str)

