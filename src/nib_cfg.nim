import os, strutils, parsecfg, streams
import nib_types



proc parseInt* (c: char): int =
 if c in {'0'..'9'}:
  result = int(c) - int('0')

proc isNumber* (s: string): bool =
 var i = 0
 while s[i] in {'0'..'9'}: inc(i)
 result = i == s.len and s.len > 0

proc isNumber* (c: char): bool =
 if c in {'0'..'9'}:
  result = true


proc createDefaultProfiles* (pathProfile: string): bool =
 var
  cfgFile: File
 echo pathProfile
 if cfgFile.open(pathProfile ,fmWrite):
  cfgFile.writeLine("# Search option params (sUrlOpt):")
  cfgFile.writeLine("#  [i] for integer, for loop purpose ( e.g: page=[i] )")
  cfgFile.writeLine("#  [s] for string, for search string ( e.g: tags=[s] )")
  cfgFile.writeLine("#  !!! One [s] option is compulsory for 'tags' field input")
  cfgFile.writeLine("#   e.g: for boorus - [tags], chans - [board/thread/id], etc..")
  cfgFile.writeLine("# iBase - starting point of [i]")
  cfgFile.writeLine("# iStep - next loop step")
  cfgFile.writeLine("# iStep - set to 0 = no loop (for chans)")
  cfgFile.writeLine("# --\"string\":\"string\" string replacement in parsed URLs")
  cfgFile.writeLine("#  If not defined, mainUrl & parseUrl = dl URL (e.g: danbooru)")
  cfgFile.writeLine("# If site requires cookies(e.g: pixiv) use 'cookie=' option")
  cfgFile.writeLine("# If you leave parseName empty,md5 value will be generated")
  cfgFile.writeLine("# These options should cover most of boorus/chans/etc..")

  cfgFile.writeLine("[danbooru]")
  cfgFile.writeLine("mainUrl=\"http://danbooru.donmai.us\"")
  cfgFile.writeLine("searchUrl=\"http://danbooru.donmai.us/posts?\"")
  cfgFile.writeLine("sUrlOpt1=\"page=[i]\"")
  cfgFile.writeLine("sUrlOpt2=\"tags=[s]\"")
  cfgFile.writeLine("iBase=\"1\"")
  cfgFile.writeLine("iStep=\"1\"")
  cfgFile.writeLine("parseElement=\"article\"")
  cfgFile.writeLine("parseUrl=\"data-file-url\"")
  cfgFile.writeLine("parseExt=\"data-file-ext\"")
  cfgFile.writeLine("parseName=\"data-md5\"")

  cfgFile.writeLine("[gelbooru]")
  cfgFile.writeLine("mainUrl=\"http://gelbooru.com/\"")
  cfgFile.writeLine("searchUrl=\"http://gelbooru.com/index.php?page=post&s=list&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"42\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeLine("--\"/thumbnail_\":\"/\"")

  cfgFile.writeLine("[safebooru]")
  cfgFile.writeLine("mainUrl=\"http://safebooru.org/\"")
  cfgFile.writeLine("searchUrl=\"http://safebooru.org/index.php?page=post&s=list&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"40\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeLine("--\"/thumbnail_\":\"/\"")

  cfgFile.writeLine("[rule34]")
  cfgFile.writeLine("mainUrl=\"http://rule34.xxx\"")
  cfgFile.writeLine("searchUrl=\"http://rule34.xxx/index.php?page=post&s=list&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"42\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeLine("--\"/thumbnail_\":\"/\"")

  cfgFile.writeLine("[Drawfriends]")
  cfgFile.writeLine("mainUrl=\"http://drawfriends.booru.org/\"")
  cfgFile.writeLine("searchUrl=\"http://drawfriends.booru.org/index.php?page=post&s=list&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"20\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"thumbs.booru.org\":\"img.booru.org\"")
  cfgFile.writeLine("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeLine("--\"/thumbnail_\":\"/\"")

  cfgFile.writeLine("[Realbooru]")
  cfgFile.writeLine("mainUrl=\"http://rb.booru.org/\"")
  cfgFile.writeLine("searchUrl=\"http://rb.booru.org/index.php?page=post&s=list&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"20\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"thumbs.booru.org\":\"img.booru.org\"")
  cfgFile.writeLine("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeLine("--\"/thumbnail_\":\"/\"")

  cfgFile.writeLine("[4chan]")
  cfgFile.writeLine("mainUrl=\"http://4chan.org\"")
  cfgFile.writeLine("searchUrl=\"https://boards.4chan.org/\"")
  cfgFile.writeLine("sUrlOpt1=\"[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"0\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"//i.\":\"http://i.\"")
  cfgFile.writeLine("--\"s.\":\".\"")

  cfgFile.writeLine("[8chan]")
  cfgFile.writeLine("mainUrl=\"https://8ch.net\"")
  cfgFile.writeLine("searchUrl=\"https://8ch.net/\"")
  cfgFile.writeLine("sUrlOpt1=\"[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"\"")
  cfgFile.writeLine("iBase=\"0\"")
  cfgFile.writeLine("iStep=\"0\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"/thumb/\":\"/src/\"")

  cfgFile.writeLine("# Responses breaks parser but at least something gets thru")
  cfgFile.writeLine("[sankakuChan]")
  cfgFile.writeLine("mainUrl=\"http://cs.sankakucomplex.com/data/\"")
  cfgFile.writeLine("searchUrl=\"https://chan.sankakucomplex.com/?commit=Search&\"")
  cfgFile.writeLine("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeLine("sUrlOpt2=\"page=[i]\"")
  cfgFile.writeLine("iBase=\"1\"")
  cfgFile.writeLine("iStep=\"1\"")
  cfgFile.writeLine("parseElement=\"img\"")
  cfgFile.writeLine("parseUrl=\"src\"")
  cfgFile.writeLine("parseExt=\"\"")
  cfgFile.writeLine("parseName=\"\"")
  cfgFile.writeLine("--\"/preview\":\"\"")
  cfgFile.writeLine("--\"//c.\":\"http://cs.\"")

  cfgFile.flushFile()
  cfgFile.close()
  result = true
 else:
  echo "no write permission ?"
  # mainWin.error("***Error: Couldn't create file '$1'" % [fpProfiles])

proc resetCurProfile* (curProf: PBooruProf) =
 curProf.name = ""
 curProf.mUrl = ""
 curProf.sUrl = ""
 curProf.sUrlOpt1 = ""
 curProf.sUrlOpt2 = ""
 curProf.parEle = ""
 curProf.parUrl = ""
 curProf.parName = ""
 curProf.parExt = ""
 curProf.iMult = ""
 curProf.iBase = ""
 curProf.cookie = ""

 for i in 0..curProf.repStr.high():
  curProf.repStr[i][0] = ""
  curProf.repStr[i][1] = ""

proc loadProfile* (paths: TPaths,profName: string,curProf: PBooruProf): bool =
 var
  fileStream = newFileStream(paths.fpProfiles, fmRead)
  foundProfile: bool = false

 if fileStream != nil:
  var cfgParser: CfgParser
  open(cfgParser, fileStream, paths.fpProfiles)
  var event = next(cfgParser)
  curProf.resetCurProfile()

  while true:
    case event.kind
    of cfgEof:
      break
    of cfgSectionStart:
     if event.section == profName:
       foundProfile = true
       curProf.name = event.section
       event = next(cfgParser)
       var i: int = 0
       while event.kind == cfgKeyValuePair or event.kind == cfgOption:
        if event.kind == cfgKeyValuePair:
         case event.key
         of "mainUrl":
          curProf.mUrl = event.value
         of "searchUrl":
          curProf.sUrl = event.value
         of "sUrlOpt1":
          curProf.sUrlOpt1 = event.value
         of "sUrlOpt2":
          curProf.sUrlOpt2 = event.value
         of "parseElement":
          curProf.parEle = event.value
         of "parseUrl":
          curProf.parUrl = event.value
         of "parseExt":
          curProf.parExt = event.value
         of "parseName":
          curProf.parName = event.value
         of "iStep":
          curProf.iMult = event.value
         of "iBase":
          curProf.iBase = event.value
         of "cookie":
          curProf.cookie = "Cookie: $1$2\c\L" % [event.value,
           if curProf.mUrl != "": "\L" & curProf.mUrl else: ""]
         else:
          discard

        if event.kind == cfgOption:
         if i <= curProf.repStr.high():
          curProf.repStr[i][0] = event.key
          curProf.repStr[i][1] = event.value
          inc(i)

        event = next(cfgParser)
    of cfgError:
     echo(event.msg)
    else: discard
    event = next(cfgParser)
  close(cfgParser)
 else:
  # mainWin.warning("**Warning: Cannot open $1. Creating default." % [fpProfiles])
  if createDefaultProfiles(paths.fpProfiles):
   return paths.loadProfile(profName,curProf)
 if foundProfile == false:
  # mainWin.warning("**Warning: Profile not found, check $1" % [fpProfiles])
  echo "warrning profile '$1' not found" % profName
 result = foundProfile


proc setPathsMain* (paths: var TPaths): bool =

 paths.dirHome = getHomeDir()
 paths.dirCfg = joinPath(getConfigDir(), "nibolo")
 paths.dirTemp = joinPath(getTempDir(), "nibolo")
 paths.fpResponse = joinPath(paths.dirCfg,"response.html")
 paths.fpProfiles = joinPath(paths.dirCfg,"profiles.ini")
 when defined(Linux):
  paths.fpPicMain = "/usr/local/share/pixmaps/nibolo.png"
 elif defined(Windows):
  paths.fpPicMain =joinPath(getAppDir(),"nibolo.png")
 else:
  paths.fpPicMain = joinPath(paths.dirCfg,"nibolo.png")

 if existsDir(paths.dirTemp) == false:
  try:
   createDir(paths.dirTemp)
  except:
   # logEvent(true,"***Error Msg: @manGetQueueLenStr '$1'" % getCurrentExceptionMsg())
   paths.dirTemp = getTempDir()

 if existsDir(paths.dirCfg) == false:
  try:
   createDir(paths.dirCfg)
   if not createDefaultProfiles(paths.fpProfiles):
    echo "***Err: createDefaultProfiles: $1" % getCurrentExceptionMsg()
  except:
   echo "***Err: setPathsMain: $1" % getCurrentExceptionMsg()
   # mainWin.error("***Error: Failed to create directory '$1'" % [paths.dirCfg])

 if existsFile(paths.fpProfiles) == false:
   if not createDefaultProfiles(paths.fpProfiles):
    echo "***Err: createDefaultProfiles: $1" % getCurrentExceptionMsg()
 result = true


proc setPaths* (paths: var TPaths) =

 paths.dirHome = getHomeDir()
 paths.dirCfg = joinPath(getConfigDir(), "nibolo")
 paths.dirTemp = joinPath(getTempDir(), "nibolo")
 paths.fpResponse = joinPath(paths.dirCfg,"response.html")
 paths.fpProfiles = joinPath(paths.dirCfg,"profiles.ini")
 when defined(Linux):
  paths.fpPicMain = "/usr/local/share/pixmaps/nibolo.png"
 elif defined(Windows):
  paths.fpPicMain =joinPath(getAppDir(),"nibolo.png")
 else:
  paths.fpPicMain = joinPath(paths.dirCfg,"nibolo.png")

