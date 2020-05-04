import sugar
import strutils, tables, sequtils, strformat
import httpClient, streams, os
import logging
import json
import yaml/serialization, cligen


type
  StagePos = object
    x : float
    y : float
  Channel = object
    name : string
    staining : string
    definition : string
    fluorophore : string

  IndexedChannel = object
    name : string
    staining : string
    definition : string
    fluorophore : string
    index : int

  Parameters = object
    cell_line : string
    passage : int
    media : string
    dish_type : string
    coating : string
    coating_level : int

  SysParameters = object
    microscope : string
    magnification : string

  ParametersOut = object
    cell_line : string
    passage : int
    media : string
    dish_type : string
    coating : string
    coating_level : int
    stage_pos_x : float
    stage_pos_y : float
    experiment_id : int

  Experiment = object
    channels : seq[Channel]
    experiment_parameters : Parameters
    system_parameters : SysParameters

  ParamsOut = object
    channels : seq[IndexedChannel]
    experiment_parameters : ParametersOut
    system_parameters : SysParameters

proc load_experiment(yaml_path : string) : Experiment =
    var s = openFileStream(yaml_path)
    defer: close(s)
    load(s, result)

proc load_channels(channels_path : string, experiment : Experiment) : seq[IndexedChannel] =
    var count = 0
    for line in lines(channels_path):
      inc(count)
      for c in experiment.channels:
        if contains(c.name, line):
          let ic = IndexedChannel(name: c.name, staining:c.staining, definition:c.definition, fluorophore:c.fluorophore, index:count)
          result.add(ic)


proc load_stage_pos(stage_path : string) : (float, float) =
    let raw_txt = readFile(stage_path)
    let str_len = len(raw_txt) div 2
    var txt = newString(str_len)

    var j = 0
    for i in 0..<txt.len:
        let c = raw_txt[2*i]
        if ord(c) in {26..126, 13}:
            txt[j] = c
            inc(j)

    let tmpData = to(parseJson(txt), StagePos)
    return (tmpData.x, tmpData.y)


proc write_positions(output_path : string, pos_x : openArray[JsonNode], pos_y : openArray[JsonNode]) =
    let f = open(output_path, fmWrite)
    defer: close(f)
    for pos in zip(pos_x, pos_y):
        let lines = [fmt"x={pos.a}", fmt"y={pos.b}"]
        for line in lines:
            f.writeLine(line)

proc write_sync_status(sync_path : string, status : string) = 
    writefile(sync_path, status)

proc init_logger(logging_path : string) = 
    const logging_format = "[$datetime] - $levelname: "
    try:
      var logger = newFileLogger(logging_path, fmtStr = logging_format)
      addHandler(logger)
      info("Initialized logger...")

    except IOError:
      var logger = newFileLogger(fmtStr = logging_format)
      addHandler(logger)
      error(getCurrentExceptionMsg())


template errorHandling(root_dir : string, logging_path : string, sync_path: string, body: untyped) =
  init_logger(root_dir / logging_path)
  try:
    body

  except IOError:
    # Write 3 to file for stop
    error(getCurrentExceptionMsg())
    write_sync_status(root_dir / sync_path, "3")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1

  except OSError:
    # Write 3 to file for stop
    error(getCurrentExceptionMsg())
    write_sync_status(root_dir / sync_path, "3")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1
  


proc fetch(address = "http://localhost:4443", exp_id_path = "exp_id.txt",
          sync_path = "sync.txt", output_path = "output_file.txt",
          logging_path = "log.txt", root_dir = getCurrentDir()): int = 

  errorHandling(root_dir, logging_path, sync_path):
    echo address & "/get_objects"
    var client = newHttpClient()
    
    let response = client.getContent(address & "/get_objects").parseJson
    echo response
    
    #fix this line 
    #write_positions(root_dir / output_path, response["centroid_x"].getElems, response["centroid_y"].getElems)


proc send(address = "http://localhost:4443", img_path = "color.tif",
         yaml_path = "experiment_params.yml", channels_path = "channels.txt",
         stage_path = "stage_pos.txt", exp_id_path = "exp_id.txt",
         output_path = "output_file.txt", sync_path = "sync.txt",
         logging_path = "log.txt", root_dir = getCurrentDir()) : int =
  
    errorHandling(root_dir, logging_path, sync_path):
      let
        experiment = loadExperiment(root_dir / yaml_path) #info("Loaded experiment parameters.")
        channels = load_channels(root_dir / channels_path, experiment) #info("Loaded channels.")
        (stage_pos_x, stage_pos_y) = load_stage_pos(root_dir / stage_path) #info("Loaded stage positions.")
        
        exp_id = parseInt(readFile(root_dir / exp_id_path)) #info("Loaded experiment id.")
        e = experiment.experiment_parameters
        po = ParametersOut(cell_line: e.cell_line,
                          passage: e.passage,
                          media: e.media,
                          dish_type: e.dish_type,
                          coating: e.coating,
                          coating_level: e.coating_level,
                          stage_pos_x: stage_pos_x,
                          stage_pos_y: stage_pos_y,
                          experiment_id : exp_id)
        params_out = ParamsOut(channels: channels, experiment_parameters: po, system_parameters: experiment.system_parameters)
        
        params_json = %* params_out


      var client = newHttpClient()
      var data  = newMultipartData()
      let img = readFile(root_dir / img_path)
      data["image"] = img
      data["params"] = $params_json
      info("Loaded image and params.")

      let response = client.postContent(address, multipart=data).parseJson
      info("Got response from server.")
    
      info("Wrote coordinates to position txt.")
      write_sync_status(root_dir / sync_path, "2")
      info("Wrote 2 (proceed) to sync.")



dispatchMulti([send, help = {"address": "Server address", "img_path": "Path to the image to be analysed"}], [fetch])
