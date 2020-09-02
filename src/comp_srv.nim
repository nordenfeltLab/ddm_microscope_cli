import srvcom
import strutils, tables, sequtils, strformat, options
import httpClient, streams, os
import logging
import json
import yaml/serialization, cligen
import options

# exe compilation
proc send(address = "http://localhost:4443", img_path = "images",
         yaml_path = "experiment_params.yml", channels_path = "channels.txt",
         stage_path = "stage_pos.txt", exp_id_path = "exp_id.txt",
         output_path = "output_file.txt", sync_path = "sync.txt",
         logging_path = "log.txt", root_dir = getCurrentDir(),
         analysis_flag : string) : int =
  
    errorHandling(root_dir, logging_path, sync_path):
      let
        img = loadLatestImage(root_dir / img_path)
        params_json = loadParams(
          root_dir, yaml_path, channels_path, stage_path, exp_id_path,
          output_path, sync_path, logging_path 
          )

      discard sendImageParams(address, img, params_json)
      info("Got response from server.")
      write_sync_status(root_dir / sync_path, "2")
      info("Wrote 2 (proceed) to sync.")

#
#proc initiate_experiment( analysis : string, address = "http://localhost:4443",exp_id_path = "exp_id.txt") : int = 
#    initExperiment(analysis, address, exp_id_path)

dispatchMulti([send, help = {"address": "Server address", 
                            "img_path": "Path to the image to be analysed",
                            "analysis_flag": "what analysis should be ran"}],
              [initExperiment, help = {}],
                      [fetch, help = {}])
