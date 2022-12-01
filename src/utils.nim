import httpClient, os, system, uri
import strutils, strformat, options, json
import sequtils, algorithm
import logging
import error_handler
import cligen

#import streams, tables


proc getFileTimepoint(filename: string) :int =
  parseInt(filename[^7..^5])
           
proc getImages*(dir_path: string, fil_ext = "nd2") : seq[string] =

  #var files: seq[string] = @[]
  let files = toSeq( walkFiles(dir_path / "*." & fil_ext))
  let filtfiles = files.filterIt(it[^7..^5].allIt(it in {'0'..'9'}))
    
  filtfiles.sortedByIt(getFileTimepoint(it))

proc queryDDM*(address      = "http://localhost:4445",
            sync_path    = "sync.txt",
            response_path = "response.txt",
            logging_path = "log.txt",
            root_dir     = getCurrentDir(),
            queryString  = "",
            queryPath = ""
          ): int =
  
  errorHandling(root_dir, logging_path, sync_path):
    var query = if isEmptyOrWhitespace(queryPath):
      queryString
    else:
      readFile(root_dir / queryPath)
    query.stripLineEnd

    let client = newHttpClient()
    let queryAddress = address & "?query=" & query.replace(" ", by="%20")
    info(queryAddress)
    let response = client.getContent($queryAddress).parseJson
    info(fmt"Wrote response to: {response_path} ")
    info(fmt"Response: {response}")

    writeFile(root_dir / response_path, $response)
    writeFile(root_dir / sync_path, "1")
    

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


