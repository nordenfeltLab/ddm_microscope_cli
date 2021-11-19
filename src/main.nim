#import strutils, strformat, options
#import httpClient, os, system, uri
#import cligen
import os
import logging
import error_handler
import utils
import cligen

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

if isMainModule:
  dispatchMulti([send, help  = {"address"       : "Server address, e.g 'http://localhost:4444'.",
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
                        }]
            )
  
