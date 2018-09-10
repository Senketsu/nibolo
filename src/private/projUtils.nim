import os, strutils, times

const
  VERSION* = "v0.2.0-alpha"
  NAME* = "nibolo"
  NAMEVER* = "$1 $2" % [NAME, VERSION]
  LINK* = "https://github.com/Senketsu/pomfit"
  TWITTER* = "https://twitter.com/Senketsu_dev"
  LICENSE* = LINK & "/blob/devel/LICENSE.txt"


# macro for cOut
let
  cOut*: bool = true
  logEvents*: bool = true
  logError*: bool = true
  logDebug*: bool = false
  logPM*: bool = false
  logMsg*: bool = false
  logAllMsg*:bool = false


proc isNumber*(s: string): bool =
  var i = 0
  while s[i] in {'0'..'9'}: inc(i)
  result = i == s.len and s.len > 0


proc `|`*(x: int, d: int): string =
  result = $x
  let pad = spaces(d.abs-len(result))
  if d >= 0:
    result = pad & result
  else:
    result = result & pad


proc `|`*(s: string, d: int): string =
  let pad = spaces(d.abs-len(s))
  if d >= 0:
    result = pad & s
  else:
    result = s & pad


proc `|`*(f: float, d: tuple[w,p: int]): string =
  result = formatFloat(f, ffDecimal, d.p)
  let pad = spaces(d.w.abs-len(result))
  if d.w >= 0:
    result = pad & result
  else:
    result = result & pad


proc `|`*(f: float, d: int): string =
  $f | d

  
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

proc echoInfo*(msg: string) =
  var
    isWorker,isMain,isManager,isDebug,isUnk,isPrompt: bool = false

  if msg.startsWith("Worker"):
    isWorker = true
  elif msg.startsWith("Main"):
    isMain = true
  elif msg.startsWith("Manager"):
    isManager = true
  elif msg.startsWith("Debug"):
    isDebug = true
  elif msg[0] == '*':
    isPrompt = true
  else:
    isUnk = true

  when defined(Windows):
    stdout.writeLine("[Info]: $1" % msg)
  else:
    if cOut:
      if isManager:
        stdout.writeLine("[Info]: \27[0;35m$1\27[0m" % [msg])
      elif isMain:
        stdout.writeLine("[Info]: \27[0;94m$1\27[0m" % [msg])
      elif isWorker:
        stdout.writeLine("[Info]: \27[0;95m$1\27[0m" % [msg])
      elif isDebug:
        stdout.writeLine("[Info]: \27[0;92m$1\27[0m" % [msg])
      elif isPrompt:
        stdout.writeLine("\27[0;96m$1\27[0m" % [msg])
      else:
        stdout.writeLine("[Info]: \27[0;93m$1\27[0m" % msg)
    else:
      stdout.writeLine("[Info]: $1" % msg)


proc logEvent*(logThis: bool, msg: string) =
  var
    isError,isDebug,isWarn,isNotice,isUnk: bool = false
    fileName: string = ""
    logPath: string = getPath("dirLog")

  if msg.startsWith("***Error"):
    isError = true
    fileName = "Error.log"
  elif msg.startsWith("*Notice"):
    isNotice = true
  elif msg.startsWith("**Warning"):
    isWarn = true
    fileName = "Error.log"
  elif msg.startsWith("*Debug"):
    isDebug = true
    fileName = "Debug.log"
  else:
    isUnk = true

  if cOut:
    if isError:
      stdout.writeLine("\27[1;31m$1\27[0m" % [msg])
    elif isNotice:
      stdout.writeLine("\27[0;34m$1\27[0m" % [msg])
    elif isWarn:
      stdout.writeLine("\27[0;33m$1\27[0m" % [msg])
    elif isDebug:
      stdout.writeLine("\27[0;32m$1\27[0m" % [msg])
    else:
      stdout.writeLine(msg)
  else:
    stdout.writeLine(msg)

  if logEvents and logThis and not isUnk: # TODO finish after config
    var
      tStamp: string = ""
      iTimeNow: int = (int)getTime()
    let timeNewTrackWhen = utc(fromUnix(iTimeNow))
    tStamp = format(timeNewTrackWhen,"[yyyy-MM-dd] (HH:mm:ss)")

    var eventFile: File
    if isError or isDebug or isWarn:
      if eventFile.open(joinPath(logPath,fileName) ,fmAppend):
        eventFile.writeLine("$1: $2" % [tStamp,msg])
        eventFile.flushFile()
        eventFile.close()


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
    logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
  result = true

