import strutils, tables, strformat, options
import httpClient, streams, os, system
import logging
import json
import yaml/serialization
import options

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

  ServerResponse = object
    status : int


proc initParametersOut(e : Parameters, stage_pos_x : float, 
                      stage_pos_y : float, exp_id : int) : ParametersOut =

  ParametersOut(cell_line: e.cell_line,
                passage: e.passage,
                media: e.media,
                dish_type: e.dish_type,
                coating: e.coating,
                coating_level: e.coating_level,
                stage_pos_x: stage_pos_x,
                stage_pos_y: stage_pos_y,
                experiment_id : exp_id)

proc initParamsOut(experiment : Experiment, channels: seq[IndexedChannel],
                  exp_id : int, stage_pos_x : float, 
                  stage_pos_y : float) : ParamsOut =
  let
    e = experiment.experiment_parameters
    po = initParametersOut(e, stage_pos_x, stage_pos_y, exp_id)
  ParamsOut(channels: channels, experiment_parameters: po, system_parameters: experiment.system_parameters)

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

proc loadLatestImage*(img_path : string): TaintedString =
  var latest = none(string)
  for fname in walkFiles(img_path / "*"):
    if latest.isNone or fileNewer(fname, get(latest)):
      latest = some(fname)

  if latest.isSome:
    return readFile(get(latest))
  return readFile(img_path)

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


proc write_positions(output_path : string, pos_x : openArray[JsonNode], pos_y : openArray[JsonNode], stage_x : openArray[JsonNode], stage_y : openArray[JsonNode]) =
    let f = open(output_path, fmWrite)
    defer: close(f)
    for i in low(pos_x)..high(pos_x):
      let lines = [fmt"x={pos_x[i]}", fmt"y={pos_y[i]}", fmt"stage_x={stage_x[i]}", fmt"stage_y={stage_y[i]}"]
      for line in lines:
        f.writeLine(line)

proc write_sync_status*(sync_path : string, status : string) = 
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
      #error(getCurrentExceptionMsg())


template errorHandling*(root_dir : string, logging_path : string, sync_path: string, body: untyped) =
  init_logger(root_dir / logging_path)
  try:
    body

  except IOError:
    # Write 3 to file for stop
    #error(getCurrentExceptionMsg())
    write_sync_status(root_dir / sync_path, "3")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1

  except OSError:
    # Write 3 to file for stop
    #error(getCurrentExceptionMsg())
    write_sync_status(root_dir / sync_path, "3")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1
  


proc fetch*(address = "http://localhost:4443", exp_id_path = "exp_id.txt",
          sync_path = "sync.txt", output_path = "output_file.txt",
          logging_path = "log.txt", root_dir = getCurrentDir()): int = 

  errorHandling(root_dir, logging_path, sync_path):
    echo address & "/get_objects"
    var client = newHttpClient()
    
    let response = client.getContent(address & "/get_objects").parseJson
    echo response
    
    #fix this line 
    write_positions(root_dir / output_path, 
                    response["centroid_x"].getElems,
                    response["centroid_y"].getElems,
                    response["stage_pos_x"].getElems,
                    response["stage_pos_y"].getElems)
    info("Wrote coordinates to position txt.")
    write_sync_status(root_dir / sync_path, "2")
    info("Wrote 2 (proceed) to sync.")




proc loadParams*(root_dir : string, yaml_path = "experiment_params.yml", channels_path = "channels.txt",
               stage_path = "stage_pos.txt", exp_id_path = "exp_id.txt",
               output_path = "output_file.txt", sync_path = "sync.txt",
               logging_path = "log.txt",  
               stg_pos = none((float, float)) ) : JsonNode =
  let
    experiment = loadExperiment(root_dir / yaml_path)
    channels = load_channels(root_dir / channels_path, experiment)
    exp_id = parseInt(readFile(root_dir / exp_id_path))
    
    (stage_pos_x, stage_pos_y) = if stg_pos.isSome:
      stg_pos.get
    else:
      load_stage_pos(root_dir / stage_path)
    params_out = initParamsOut(experiment, channels, exp_id, stage_pos_x, stage_pos_y)
    
  %* params_out

proc sendImageParams*(address : string, img : TaintedString , params_json : JsonNode) : JsonNode =
      var client = newHttpClient()
      var data  = newMultipartData()
      data["image"] = img
      data["params"] = $params_json
      info("Loaded image and params.")

      client.postContent(address, multipart=data).parseJson

# NIS-macro
proc callSendHelper(address : string, root_dir : string, stage_pos_x : float, stage_pos_y : float) : int =
  init_logger(root_dir / "log.txt")
  let
    img_path = "images"
    img = loadLatestImage(root_dir / img_path)
    params_json = loadParams(root_dir = root_dir, stg_pos = some((stage_pos_x, stage_pos_y)))
    response = sendImageParams(address, img, params_json).to(ServerResponse)
  response.status

proc callSend(address : WideCString, root_dir : WideCString, stage_pos_x : float, stage_pos_y : float) : cint {.exportc, dynlib.} =
  cint(callSendHelper($address, $root_dir, stage_pos_x, stage_pos_y))

proc test_myself(i : WideCString) : WideCString {.exportc, dynlib.} = 
    let f = open(getHomeDir() / "log.txt", fmWrite)
    defer: close(f)
    f.writeLine($i)
    let
        d = getHomeDir()
        p = newWideCString(d)
    copyMem(cast[pointer](i), cast[pointer](p), len(d)*2)