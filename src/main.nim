#import strutils, strformat, options
#import httpClient, os, system, uri
#import cligen
import os
import logging
import error_handler
import utils
import cligen
import strformat

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

proc demoSend(address     = "http://localhost/4443",
              dir_path    = "demo/",
              root_dir    = getCurrentDir(),
              sync_path   = "sync.txt",
              logging_path = "log.txt",
              ) : int =

  errorHandling(root_dir, logging_path, sync_path):
    # -- GETTING IMAGES
    let path = root_dir / dir_path

    info(fmt"Getting images from directory {path}.")
    let images = getImages(path, "nd2")
    
    info(fmt"Got {images.len} images from {dir_path}.")
    # -- SENDING IMAGES
    info("Sending images to server.")
    for img in images:
      info(fmt"Sending image {img}...")
      discard sendImage(address, img, root_dir, sync_path)
      info(fmt"Sent image {img}.")
    info("Done sending images to server.")


if isMainModule:
  dispatchMulti([send, help  = {"address"       : "Server address, e.g 'http://localhost:4443'.",
                                "img_path"      : "Filename of the image to be sent.",
                                "root_dir"      : "Path to root directory.",
                                "sync_path"     : "Filename for sync-status."}],
             [queryDDM, help = {"address"       : "Server address.",
                                "sync_path"     : "Filename for sync-status.",
                                "response_path" : "Filename of response-dump.",
                                "logging_path"  : "Filename for logging.",
                                "root_dir"      : "Path to root directory.",
                                "queryString"   : "Query as argument",
                                "queryPath"     : "Query as txt file (overrides queryString)"
                        }],
              [demoSend, help = {"address"      : "Server address, e.g 'http://localhost:4443'.",
                                 "dir_path"     : "Directory where test-files are stored.",
                                 "root_dir"     : "Path to root directory.",
                                 "sync_path"    : "Filename for sync-status."
                        }]
            )
  
