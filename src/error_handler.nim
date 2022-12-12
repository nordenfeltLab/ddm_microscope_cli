import logging
proc initLogger(logging_path : string) =
    const logging_format = "[$datetime] - $levelname: "
    try:
      var logger = newFileLogger(logging_path, fmtStr = logging_format, bufsize = 0)
      addHandler(logger)
      info("Initialized logger...")

    except IOError:
      var logger = newFileLogger(fmtStr = logging_format)
      addHandler(logger)
      #error(getCurrentExceptionMsg())

template errorHandling*(root_dir : string,
                        logging_path : string,
                        sync_path: string,
                        body: untyped
                        ) =
  initLogger(root_dir / logging_path)
  try:
    body

  except IOError:
    # Write 3 to file for stop
    #error(getCurrentExceptionMsg())
    writeFile(root_dir / sync_path, "-1")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1

  except OSError:
    # Write 3 to file for stop
    #error(getCurrentExceptionMsg())
    writeFile(root_dir / sync_path, "-1")
    stderr.writeLine(getCurrentExceptionMsg())
    return 1


