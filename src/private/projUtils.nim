import os, strutils, times
import logging
export logging

const
  VERSION* = "0.1.4"
  NAME* = "nibolo"
  LONGNAME* = "Nim Booru Loader"
  NAMEVER* = "$1 $2" % [NAME, VERSION]
  LINK* = "https://github.com/Senketsu/" & NAME
  TWITTER* = "https://twitter.com/Senketsu_dev"
  LICENSE* = LINK & "/blob/devel/LICENSE"

  dbugStrDefault* = "[$levelname]: "
  dbugStrVerbose* = "$levelid [$date] ($time): "


proc getPath*(name: string): string =
  result = ""
  var
    dirHome = getHomeDir()
    dirMain = joinPath(getConfigDir(), NAME)
  case name
  of "dirHome":
    result = dirHome
  of "dirMain":
    result = dirMain
  of "dirData":
    result = joinPath(dirMain, "data")
  of "dirConf":
    result = joinPath(dirMain, "cfg")
  of "dirLog":
    result = joinPath(dirMain, "logs")
  of "dirPic":
    result = joinPath(getHomeDir(), "Pictures")
  of "response":
    result = joinPath(dirMain, joinPath("data", "respFile.html"))
  of "profiles":
    result = joinPath(dirMain, joinPath("cfg", "profiles.ini"))
  else:
    discard


proc createLoggers*() =
  when not defined(release):
    var dcLogger = newConsoleLogger(lvlAll, fmtStr = dbugStrDefault)
    addHandler(dcLogger)
    var dfLogger = newFileLogger(joinPath(getPath("dirLog"), "Debug.log"), levelThreshold =lvlDebug, fmtStr = dbugStrVerbose)
    addHandler(dfLogger)
  else:
    var cLogger = newConsoleLogger(lvlWarn, fmtStr = dbugStrDefault)
    addHandler(cLogger)
  
  var efLogger = newFileLogger(joinPath(getPath("dirLog"), "Error.log"), levelThreshold = lvlWarn, fmtStr = dbugStrVerbose)
  addHandler(efLogger)


proc checkDirectories*(): bool =
  try:
    if not existsDir(projUtils.getPath("dirMain")):
      createDir(projUtils.getPath("dirMain"))
    if not existsDir(projUtils.getPath("dirData")):
      createDir(projUtils.getPath("dirData"))
    if not existsDir(projUtils.getPath("dirConf")):
      createDir(projUtils.getPath("dirConf"))
    if not existsDir(projUtils.getPath("dirLog")):
      createDir(projUtils.getPath("dirLog"))
  except:
    echo("$1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
  result = true

