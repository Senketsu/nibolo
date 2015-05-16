import os, strutils, streams, httpclient , parsexml , parsecfg , browsers
import gtk2 , gdk2pixbuf , glib2  , dialogs

const
 VERSION = "v0.1.1"

type
 TSplitPath = tuple
  dir,name,ext: string
 TLinkData* = tuple
  url,ext,name: string
 TBooruProf* = tuple
  name,mUrl,sUrl,sUrlOpt1,sUrlOpt2,parEle,parUrl,parExt,parName,iMult,iBase: string
  repStr: array[0..3, array[0..1,string]]
 PBooruProf* = ref TBooruProf

var
 mainWin: PWindow
 enTags,pwMain: PWidget
 imMain: PPixbuf
 cbProf: PComboBoxText
 sbProgress,sbInfo: PStatusbar
 vmToggle: PToggleButton
 cbFolder,bStart: PButton
 actProfile: PBooruProf
 dirCfg,dirSaveTo,dirTemp: string = ""
 stopME,restartME,viewMode: bool = false
 waitChoice = true
 profCount: int = 0
 pwW,pwH: gint = 0
 fpResponse,fpProfiles,fpPicMain,fpViewMode: string = ""

new actProfile

proc isNumber* (s: string): bool =
 var i = 0
 while s[i] in {'0'..'9'}: inc(i)
 result = i == s.len and s.len > 0

proc isNumber* (c: char): bool =
 if c in {'0'..'9'}:
  result = true

proc destroy(widget: PWidget, data: Pgpointer) {.cdecl.} =
 stopME = true
 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()
 main_quit()

proc chooseFolder(widget: PWidget, data: Pgpointer) =
 var
  getPath,folderName: string = ""

 getPath = mainWin.chooseDir()
 if getPath != "":
  folderName = getPath
  echo getPath
  when defined(Windows):
   folderName.delete(0,rfind(folderName, '\\'))
  else:
   folderName.delete(0,rfind(folderName, '/'))
  set_label(cbFolder,folderName)
  set_tooltip_text(cbFolder,getPath)
  dirSaveTo = getPath

proc protoDownload(curProf: PBooruProf,folder: string, data: TLinkData): bool =
 var
  acceptTypes: seq[string] = @[".png",".jpeg",".jpg",".jpe",".bmp",".tiff",".tif"]
  fileName,filePath,dlLink: string = ""
  sExt,sName,buff: string = ""
  imPreview: PPixbuf
  splitLink: seq[string]
 viewMode = get_active(vmToggle)
 # Seems like simplest solution for now
 if curProf.repStr[0][0] != "":
  buff = data.url
  for i in 0..curProf.repStr.high():
   if curProf.repStr[i][0] != "":
    buff = buff.replace(curProf.repStr[i][0],curProf.repStr[i][1])
  # Some boorus add ?[numbers] at the end , not webdev no idea why so get rid of it
  if buff.rfind('?') > -1:
   splitLink = buff.split('?')
   if splitLink.high() == 1:
    dlLink = splitLink[0]
   else:
    dlLink = buff
    dlLink = dlLink.replace(splitLink[splitLink.high()],"")
    dlLink.delete(dlLink.len,dlLink.len)
  else:
   dlLink = buff
 else:
  dlLink = curProf.mUrl & data.url

 # Get filename from parsed url
 if curProf.parName == "" or data.name == "":
  buff = dlLink
  buff.delete(buff.rfind('.'),buff.len)
  buff.delete(0,buff.rfind('/'))
  sName = buff
 else:
  sName = data.name
 # Get extension from parsed url - Note: ext might be different for the original file
 # we are aiming for ( thats deal with later )
 if curProf.parExt == "" or data.ext == "":
  buff = dlLink
  buff.delete(0, buff.rfind('.')-1)
  sExt = buff
 else:
  sExt = "." & data.ext

 # Generate filename/path, if exists, skip (assuming names are unique [for now])
 fileName = "$1[$2]$3" % [curProf.name ,sName ,sExt]
 if viewMode:
  filePath = joinPath(dirTemp,fileName)
 else:
  filePath = joinPath(folder,fileName)
  if fileExists(filePath):
   return

 # Request header for generated link, if file is not found, change ext and try again
 var
  respGet: Response
  httpCode: string = ""

 try:
  respGet = request(dlLink, httpHead)
  httpCode = respGet.status
 except:
  return

 # Checks, checks, checks , trying to avoid downloading invalid files
 if httpCode.startsWith("200"):
  echo "Downloading: $1" % [dlLink]
  try:
   downloadFile(dlLink ,filePath)
   imPreview = pixbuf_new_from_file_at_size(filePath, pwW,pwH,nil)
   set_from_pixbuf(PImage(pwMain),imPreview)
   if viewMode:
    waitChoice = true
    fpViewMode = filePath
    while waitChoice:
     discard gtk2.main_iteration()
    waitChoice = true
    removeFile(filePath)
   result = true
  except: # failed dl, delete file
   removeFile(filePath)
   echo "Download exception"
 # Some sources differs in file type than their sample/thumbnail
 else:
  buff = dlLink
  for ext in acceptTypes:
   dlLink.delete(dlLink.rfind('.')+1,dlLink.len)
   dlLink = dlLink & ext
   sExt = ext
   echo "Trying: $1" % [dlLink]
   try:
    respGet = request(dlLink, httpHead)
    httpCode = respGet.status
   except:
    break
   if httpCode.startsWith("200"):
    try:
     fileName = "$1[$2]$3" % [curProf.name ,sName ,sExt]
     if viewMode:
      filePath = joinPath(dirTemp,fileName)
     else:
      filePath = joinPath(folder,fileName)
      if fileExists(filePath):
       return
     downloadFile(dlLink ,filePath)
     imPreview = pixbuf_new_from_file_at_size(filePath, pwW,pwH,nil)
     set_from_pixbuf(PImage(pwMain),imPreview)
     if viewMode:
      waitChoice = true
      fpViewMode = filePath
      while waitChoice:
       discard gtk2.main_iteration()
      waitChoice = true
      removeFile(filePath)
     result = true
     echo "*** Success"
    except: # Shouldn't happen .. i hope ..
     removeFile(filePath)
     echo "Debug: Download exception"
    finally:
     break



proc protoSearch(searchTag, saveFolder: string, curProf: PBooruProf) =
 var
  acceptTypes: seq[string] = @[".png",".jpeg",".jpg",".jpe",".bmp",".tiff",".tif"]
  requestURL: string = ""
  respGet: Response
  respFile: File
  linkData: TLinkData
  iLoop1,iLoop2: int = parseInt(curProf.iBase)
  iLoopMult: int = parseInt(curProf.iMult)
  iDL: int = 0
  tryNextPage,gotLink,optLoop1,optLoop2: bool
  searchOpt1,searchOpt2: string = ""

 linkData.url = ""
 linkData.name = ""
 linkData.ext = ""

 if curProf.sUrlOpt1 == "" and curProf.sUrlOpt2 == "":
  mainWin.error("At least one search option is needed. Check your profiles.")
  return
 elif curProf.sUrlOpt1.endsWith("[s]") == false and curProf.sUrlOpt2.endsWith("[s]") == false:
  mainWin.error("Cannot determine where to input search tags. Check your profiles.")
  return
 else:
  if curProf.sUrlOpt1.endsWith("[s]"):
   searchOpt1 = replace(curProf.sUrlOpt1 , "[s]",searchTag)
  elif curProf.sUrlOpt1.endsWith("[i]"):
   searchOpt1 = replace(curProf.sUrlOpt1 , "[i]", "")
   optLoop1 = true
  else:
   searchOpt1 = curProf.sUrlOpt1

  if curProf.sUrlOpt2.endsWith("[s]"):
   searchOpt2 = replace(curProf.sUrlOpt2 , "[s]",searchTag)
  elif curProf.sUrlOpt2.endsWith("[i]"):
   searchOpt2 = replace(curProf.sUrlOpt2 , "[i]", "")
   optLoop2 = true
  else:
   searchOpt2= curProf.sUrlOpt2


 # Yo dawg i herd u lik loops
 while true:
  tryNextPage = false
  if stopME:
   return
  discard push(sbInfo, 2, "Status: Searching for images..")
  if searchOpt2 != "":
   requestURL = "$1$2$3&$4$5" %
    [curProf.sUrl,searchOpt1,(if optLoop1: $iLoop1 else: ""), searchOpt2,(if optLoop2: $iLoop2 else: "")]
  else:
   requestURL = "$1$2" % [curProf.sUrl,searchOpt1]

  echo ("Looking trough $1 ..." % [requestURL])
  respGet = request(requestURL,httpGet)

  if respFile.open( fpResponse ,fmWrite):
    respFile.writeln(respGet.body)
    respFile.flushFile()
    respFile.close()
  else:
   return

  # We got some response, lets check it
  var s = newFileStream(fpResponse, fmRead)
  if s == nil:
   mainWin.error("Cannot open the file " & fpResponse)
   return
  var x: XmlParser
  open(x, s, fpResponse)
  # Loops and loops and loops..
  while true:

   while gtk2.events_pending () > 0:
    discard gtk2.main_iteration()
   if stopME:
    x.close()
    return
   x.next()

   case x.kind
   of xmlElementOpen,xmlElementStart:
    if cmpIgnoreCase(x.elementName, curProf.parEle) == 0:
     # Begin inner loop trough element
     while true:
      x.next()
      if stopME:
       x.close()
       return

      case x.kind
      of xmlAttribute:
       if x.attrKey == curProf.parUrl:
        linkData.url = x.attrValue
       if x.attrKey == curProf.parExt:
        linkData.ext = x.attrValue
       if x.attrKey == curProf.parName:
        linkData.name = x.attrValue
       else:
        discard # discard all the junk

      of xmlElementEnd, xmlElementClose:
       # To eliminate some invalid links, shitty but better then nothing for now
       for imgType in acceptTypes:
        if linkData.url.contains(imgType):
         gotLink = true
         break
       if gotLink:
        discard push(sbInfo, 3, "Status: Downloading images..")
        if protoDownload(curProf,saveFolder,linkData):
         inc(iDL)
         discard sbProgress.push(1,"Downloaded $1 images" % [$iDL])
        while gtk2.events_pending () > 0:
         discard gtk2.main_iteration()
        # We are at the end of element we were parsing from, we can break the loop
        tryNextPage = true
        gotLink = false
        linkData.url = ""
        linkData.ext = ""
        linkData.name = ""
        break
      # Sometimes parser breaks (e.g: sankaku complex)
      of xmlEof:
       break
      # We need only key-value pairs
      else:
       discard
    # Its not the element you are looking for (no pun intended)
    else:
      continue
   of xmlEof:
    # No valid link found on this page , stop looping
    if tryNextPage == false:
     x.close()
     return
    else:
     break
   # Discard any other event we dont need work with
   else:
    discard
  # Out of loops
  x.close()
  if iLoopMult == 0:
   return
  if optLoop1:
   iLoop1 = iLoop1+iLoopMult
  if optLoop2:
   iLoop2 = iLoop2+iLoopMult
  # Perhaps do some check if more loops needed
  if tryNextPage == false:
   return


proc createDefaultProfiles()=
 var
  cfgFile: File

 if cfgFile.open(fpProfiles ,fmWrite):
  cfgFile.writeln("# Search option params (sUrlOpt):")
  cfgFile.writeln("#  [i] for integer, for loop purpose ( e.g: page=[i] )")
  cfgFile.writeln("#  [s] for string, for search string ( e.g: tags=[s] )")
  cfgFile.writeln("#  !!! One [s] option is compulsory for 'tags' field input")
  cfgFile.writeln("#   e.g: for boorus - [tags], chans - [board/thread/id], etc..")
  cfgFile.writeln("# iBase - starting point of [i]")
  cfgFile.writeln("# iStep - next loop step")
  cfgFile.writeln("# iStep - set to 0 = no loop (for chans)")
  cfgFile.writeln("# --\"string\":\"string\" string replacement in parsed URLs")
  cfgFile.writeln("#  If not defined, mainUrl & parseUrl = dl URL (e.g: danbooru)")

  cfgFile.writeln("[danbooru]")
  cfgFile.writeln("mainUrl=\"http://danbooru.donmai.us\"")
  cfgFile.writeln("searchUrl=\"http://danbooru.donmai.us/posts?\"")
  cfgFile.writeln("sUrlOpt1=\"page=[i]\"")
  cfgFile.writeln("sUrlOpt2=\"tags=[s]\"")
  cfgFile.writeln("iBase=\"1\"")
  cfgFile.writeln("iStep=\"1\"")
  cfgFile.writeln("parseElement=\"article\"")
  cfgFile.writeln("parseUrl=\"data-file-url\"")
  cfgFile.writeln("parseExt=\"data-file-ext\"")
  cfgFile.writeln("parseName=\"data-md5\"")

  cfgFile.writeln("[safebooru]")
  cfgFile.writeln("mainUrl=\"http://safebooru.org/images/\"")
  cfgFile.writeln("searchUrl=\"http://safebooru.org/index.php?page=post&s=list&\"")
  cfgFile.writeln("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeln("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeln("iBase=\"0\"")
  cfgFile.writeln("iStep=\"40\"")
  cfgFile.writeln("parseElement=\"img\"")
  cfgFile.writeln("parseUrl=\"src\"")
  cfgFile.writeln("parseExt=\"\"")
  cfgFile.writeln("parseName=\"\"")
  cfgFile.writeln("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeln("--\"/thumbnail_\":\"/\"")

  cfgFile.writeln("[rule34]")
  cfgFile.writeln("mainUrl=\"http://rule34.xxx\"")
  cfgFile.writeln("searchUrl=\"http://rule34.xxx/index.php?page=post&s=list&\"")
  cfgFile.writeln("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeln("sUrlOpt2=\"pid=[i]\"")
  cfgFile.writeln("iBase=\"0\"")
  cfgFile.writeln("iStep=\"42\"")
  cfgFile.writeln("parseElement=\"img\"")
  cfgFile.writeln("parseUrl=\"src\"")
  cfgFile.writeln("parseExt=\"\"")
  cfgFile.writeln("parseName=\"\"")
  cfgFile.writeln("--\"/thumbnails/\":\"/images/\"")
  cfgFile.writeln("--\"/thumbnail_\":\"/\"")

  cfgFile.writeln("[4chan]")
  cfgFile.writeln("mainUrl=\"http://4chan.org\"")
  cfgFile.writeln("searchUrl=\"https://boards.4chan.org/\"")
  cfgFile.writeln("sUrlOpt1=\"[s]\"")
  cfgFile.writeln("sUrlOpt2=\"\"")
  cfgFile.writeln("iBase=\"0\"")
  cfgFile.writeln("iStep=\"0\"")
  cfgFile.writeln("parseElement=\"img\"")
  cfgFile.writeln("parseUrl=\"src\"")
  cfgFile.writeln("parseExt=\"\"")
  cfgFile.writeln("parseName=\"\"")
  cfgFile.writeln("--\"//i.\":\"http://i.\"")
  cfgFile.writeln("--\"s.\":\".\"")

  cfgFile.writeln("[8chan]")
  cfgFile.writeln("mainUrl=\"https://8ch.net\"")
  cfgFile.writeln("searchUrl=\"https://8ch.net/\"")
  cfgFile.writeln("sUrlOpt1=\"[s]\"")
  cfgFile.writeln("sUrlOpt2=\"\"")
  cfgFile.writeln("iBase=\"0\"")
  cfgFile.writeln("iStep=\"0\"")
  cfgFile.writeln("parseElement=\"img\"")
  cfgFile.writeln("parseUrl=\"src\"")
  cfgFile.writeln("parseExt=\"\"")
  cfgFile.writeln("parseName=\"\"")
  cfgFile.writeln("--\"/thumb/\":\"/src/\"")

  cfgFile.writeln("# Responses breaks parser but at least something gets thru")
  cfgFile.writeln("[sankakuChan]")
  cfgFile.writeln("mainUrl=\"http://cs.sankakucomplex.com/data/\"")
  cfgFile.writeln("searchUrl=\"https://chan.sankakucomplex.com/?commit=Search&\"")
  cfgFile.writeln("sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeln("sUrlOpt2=\"page=[i]\"")
  cfgFile.writeln("iBase=\"1\"")
  cfgFile.writeln("iStep=\"1\"")
  cfgFile.writeln("parseElement=\"img\"")
  cfgFile.writeln("parseUrl=\"src\"")
  cfgFile.writeln("parseExt=\"\"")
  cfgFile.writeln("parseName=\"\"")
  cfgFile.writeln("--\"/preview\":\"\"")
  cfgFile.writeln("--\"//c.\":\"http://cs.\"")

  cfgFile.writeln("# Responses breaks parser - commented out for now")
  cfgFile.writeln("# [sankakuIdol]")
  cfgFile.writeln("# mainUrl=\"http://is.sankakucomplex.com/data/\"")
  cfgFile.writeln("# searchUrl=\"https://idol.sankakucomplex.com/?commit=Search&\"")
  cfgFile.writeln("# sUrlOpt1=\"tags=[s]\"")
  cfgFile.writeln("# sUrlOpt2=\"page=[i]\"")
  cfgFile.writeln("# iBase=\"1\"")
  cfgFile.writeln("# iStep=\"1\"")
  cfgFile.writeln("# parseElement=\"img\"")
  cfgFile.writeln("# parseUrl=\"src\"")
  cfgFile.writeln("# parseExt=\"\"")
  cfgFile.writeln("# parseName=\"\"")
  cfgFile.writeln("# --\"/preview\":\"\"")
  cfgFile.writeln("# --\"//i.\":\"http://is.\"")

  cfgFile.flushFile()
  cfgFile.close()
 else:
  mainWin.error("***Error: Couldn't create file '$1'" % [fpProfiles])

proc resetCurProfile(curProf: PBooruProf) =
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

 for i in 0..curProf.repStr.high():
  curProf.repStr[i][0] = ""
  curProf.repStr[i][1] = ""

proc loadProfile*(profName: string,curProf: PBooruProf): bool =
 var
  fileStream = newFileStream(fpProfiles, fmRead)
  foundProfile: bool = false

 if fileStream != nil:
  var cfgParser: CfgParser
  open(cfgParser, fileStream, fpProfiles)
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
  mainWin.warning("**Warning: Cannot open $1. Creating default." % [fpProfiles])
  createDefaultProfiles()
  return nibolo.loadProfile(profName,curProf)
 if foundProfile == false:
  mainWin.warning("**Warning: Profile not found, check $1" % [fpProfiles])
 result = foundProfile

proc setCfgPath() =

 dirCfg = joinPath(getConfigDir(), "nibolo")
 dirTemp = joinPath(getTempDir(), "nibolo")
 fpResponse = joinPath(dirCfg,"response.html")
 fpProfiles = joinPath(dirCfg,"profiles.ini")
 when defined(Linux):
  fpPicMain = "/usr/local/share/pixmaps/nibolo.png"
 elif defined(Windows):
  fpPicMain =joinPath(getAppDir(),"nibolo.png")
 else:
  fpPicMain = joinPath(dirCfg,"nibolo.png")
 if existsDir(dirTemp) == false:
  try:
   createDir(dirTemp)
  except:
   dirTemp = getTempDir()
 if existsDir(dirCfg) == false:
  try:
   createDir(dirCfg)
   createDefaultProfiles()
  except:
   mainWin.error("***Error: Failed to create directory $1" % [dirCfg])
 if existsFile(fpProfiles) == false:
   createDefaultProfiles()

proc fillProfileComboBox() =
 var
  fileStream = newFileStream(fpProfiles, fmRead)
  index: int = 0

 for i in countUp(0,profCount):
  cbProf.remove(gint(0))

 if fileStream != nil:
  var cfgParser: CfgParser
  open(cfgParser, fileStream, fpProfiles)
  while true:
    var
     event = next(cfgParser)
    case event.kind
    of cfgEof:
      break
    of cfgSectionStart:
     cbProf.insert_text(gint(index),event.section)
     inc(index)
    of cfgError:
     mainWin.error(event.msg)
    else: discard
  close(cfgParser)
  profCount = index

proc startGrab(widget: PWidget, data: Pgpointer)=
 var
  entryString,selProfile: string = ""

 if get_active_text(cbProf) != nil:
  selProfile = $get_active_text(cbProf)

 entryString = $get_text(PEntry(enTags))

 if dirSaveTo == "" or entryString == "" or selProfile == "":
  mainWin.info("Please select profile, input tags and select folder to save into.")
  return
# TODO
 if selProfile == "sankakuChan":
  mainWin.info("Sankaku Chan is not fully working. (for now)")

 if loadProfile(selProfile,actProfile) == false:
  return

 set_relief(bStart,RELIEF_NONE)
 protoSearch(entryString,dirSaveTo,actProfile)
 stopMe = false
 removeFile(fpResponse)
 set_relief(bStart,RELIEF_HALF)
 discard push(sbInfo, 1, "Status: Idle...")
 set_from_pixbuf(PImage(pwMain),imMain)

# For early draft .. dont judge me please
proc stopGrab(widget: PWidget, data: Pgpointer) =
 stopMe = true

proc yesOrNo(question: string): bool =
 var
  ynDialog: PDialog
  labDummy: PLabel = label_new(question)

 ynDialog = dialog_new_with_buttons (question, mainWin,
  DIALOG_DESTROY_WITH_PARENT , STOCK_NO, RESPONSE_NO,
  STOCK_YES, RESPONSE_YES,nil)

 pack_start(ynDialog.vbox, labDummy, true, true, 30)
 ynDialog.show_all()

 if run(ynDialog) == RESPONSE_YES:
  result = true
  destroy(ynDialog)
 else:
  destroy(ynDialog)

proc resetProfiles(widget: PWidget, data: Pgpointer) =
 if yesOrNo("Do you want to reset your profiles.ini ?"):
  createDefaultProfiles()
  fillProfileComboBox()
 else:
  discard

proc editProfiles(widget: PWidget, data: Pgpointer) =
 openDefaultBrowser(fpProfiles)

proc updateProfilesList() =
 fillProfileComboBox()

proc parseInt(c: char): int =
 if c in {'0'..'9'}:
  result = int(c) - int('0')

proc getNextVersion(curVer: string): string =
 var
  vM,vS,vT: int = 0

 vM = parseInt(curVer[1])
 vS = parseInt(curVer[3])
 vT = parseInt(curVer[5])

 inc(vT)
 if vT > 9:
  vT = 0
  inc(vS)
  if vS > 9:
   vS = 0
   inc(vM)

 result = "v$1.$2.$3" % [$vM,$vS,$vT]

proc isNewVersion(version: string): bool =
 var
  respGet: Response
  httpCode,nextVer: string = ""
  gitUrl: string = "https://github.com/Senketsu/nibolo/releases/tag/"

 nextVer = getNextVersion(version)
 try:
  respGet = request( gitUrl & nextVer, httpHead)
  httpCode = respGet.status
 except:
  discard

 if httpCode.startsWith("200"):
  result = true

proc promptEntry(question: string): string =
 var
  ynDialog: PDialog
  labDummy: PLabel = label_new(question)
  labDummy2: PLabel = label_new("*(This will write your password to stdin !!!)*")
  entry: PEntry = entry_new()

 entry.set_visibility(false);

 ynDialog = dialog_new_with_buttons (question, mainWin,
  DIALOG_DESTROY_WITH_PARENT , STOCK_NO, RESPONSE_NO,
  STOCK_YES, RESPONSE_YES,nil)

 pack_start(ynDialog.vbox, labDummy, true, true, 15)
 pack_start(ynDialog.vbox, labDummy2, true, true, 15)
 pack_start(ynDialog.vbox, entry, false, false, 5)
 ynDialog.show_all()

 if run(ynDialog) == RESPONSE_YES:
  result = $get_text(entry)
  destroy(ynDialog)
 else:
  result = ""
  destroy(ynDialog)
 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

proc promptCombo(question: string): string =
 var
  ynDialog: PDialog
  labDummy: PLabel = label_new(question)
  cbVer: PComboBoxText

 cbVer = combo_box_text_new()
 set_tooltip_text(cbVer,"Pick version to download, if not sure,pick ´x86´ (32bit)")
 cbVer.insert_text(gint(0),"x86")
 cbVer.insert_text(gint(1),"x86_64")

 ynDialog = dialog_new_with_buttons (question, mainWin,
  DIALOG_DESTROY_WITH_PARENT , STOCK_NO, RESPONSE_NO,
  STOCK_YES, RESPONSE_YES,nil)

 pack_start(ynDialog.vbox, labDummy, true, true, 15)
 pack_start(ynDialog.vbox, cbVer, false, false, 5)
 ynDialog.show_all()

 if run(ynDialog) == RESPONSE_YES:
  result = $get_active_text(cbVer)
  destroy(ynDialog)
 else:
  result = ""
  destroy(ynDialog)
 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

proc updateWin() =
 var
  nextVer = getNextVersion(VERSION)
  fpNewVer:string = ""
  dlUrl = "https://github.com/Senketsu/nibolo/releases/download/$1/" % [ nextVer]

 let arch = promptCombo("Pick version to download, if not sure,pick ´x86´ (32bit)")
 if arch != "":
  let dlPath = mainWin.chooseDir()
  if dlPath == "":
   mainWin.info("Downloading canceled.")
   return
  let dlName = "nibolo_setup_$1_$2.exe" % [nextVer,arch]
  fpNewVer = joinPath(dlPath,dlName)
  dlUrl = joinPath(dlUrl,dlName)
  echo dlUrl
  echo fpNewVer
  try:
   downloadFile( dlUrl ,fpNewVer)
  except:
   mainWin.error("Opps, failed to download Nibolo")
   return
 else:
  mainWin.info("Downloading canceled.")
  return

 mainWin.info("New installer downloaded")


proc updateNix() =
 var
  nextVer = getNextVersion(VERSION)
  fpMasterUrl = "https://github.com/Senketsu/nibolo/archive/"
  fpNewVer = joinPath(dirCfg,"Nibolo_$1.zip" % [nextVer])
  homeDir: string = getHomeDir()
  userName: string = ""
  rv: int

 homeDir.delete(homeDir.len,homeDir.len)
 userName = homeDir
 userName.delete(0,rfind(userName,'/'))

 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

 try:
  downloadFile(fpMasterUrl & "$1.zip" % [nextVer] ,fpNewVer)
 except:
  mainWin.error("Opps, failed downloading Nibolo")

 rv = execShellCmd("unzip -o $1 -d $2" % [ fpNewVer, dirCfg ])
 echo ($rv)
 if rv == 0:
  let pass = promptEntry("Enter sudo password for installation")
  if pass == "":
   mainWin.info("Installation canceled.")
   removeDir(joinPath(dirCfg,"nibolo-master"))
   return
  else:
   rv = execShellCmd(" echo $1 | sudo -S $2 $3" % [pass,joinPath(dirCfg,"nibolo-master/install.sh"),userName])
   if rv == 0: # promt for restart
    removeDir(joinPath(dirCfg,"nibolo-master"))
    if yesOrNo("Update successful ! Restart now ?"):
     discard execShellCmd("nibolo")
     quit()
    else:
     return
   else:
    mainWin.error("Download successful, installing failed..")
 else:
  mainWin.error("Extracting zip archive failed, please install unzip.")


proc updateCheck(arg: string) =
 if isNewVersion(arg):
  if yesOrNo("New version of Nibolo available ! Update ?"):
   when defined(Windows):
    updateWin()
   else:
    updateNix()
  else:
   discard
 else:
  discard

proc pwMainGetSize(widget: PWidget,  allocation: PAllocation) =
 pwW = allocation.width
 pwH = allocation.height


proc vmSaveImgAs() =
 if viewMode == false : return
 var
  name = fpViewMode
  curFile: TSplitPath = splitFile(name)
  sugPath: string = joinPath(joinPath(dirSaveTo,curFile.name),curFile.ext)
 let newPath = mainWin.chooseFileToSave(sugPath)
 if newPath == "":
  return
 else:
  try:
   copyFile(fpViewMode,newPath)
   waitChoice = false
  except:
   mainWin.error("Failed saving file to $1" % [newPath])

proc vmSaveImg() =
 if viewMode == false: return
 var
  name = fpViewMode
  newPath: string = ""
 when defined(Windows):
  name.delete(0,rfind(name, '\\'))
 else:
  name.delete(0,rfind(name, '/'))

 newPath = joinPath(dirSaveTo , name)
 try:
  copyFile(fpViewMode,newPath)
  waitChoice = false
 except:
  mainWin.error("Failed saving file to $1" % [newPath])

proc vmNextImg() =
 waitChoice = false

proc startUp()=
 var
  vbMain,hbMain,vbSec1,vbSec2,hbFill: PWidget
  bStop,bQuit,bUpdate,bProfEdit,bProfReset,bProfUpdate: PButton
  bSaveImg,bSaveImgAs,bNextImg: PButton
  labDummy: PLabel

 nibolo.setCfgPath()
 nimrod_init()
 mainWin = window_new(WINDOW_TOPLEVEL)
 mainWin.set_position(WIN_POS_MOUSE)
 mainWin.set_title("Nibolo")
 mainWin.set_default_size(700,400)
 discard signal_connect(mainWin, "destroy", SIGNAL_FUNC(nibolo.destroy), nil)

 vbMain = vbox_new(false,2)
 mainWin.add(vbMain)

 hbMain = hbox_new(false,2)
 pack_start(BOX(vbMain), hbMain, true, true,0)
 # Left side vbox
 vbSec1 = vbox_new(false,3)
 pack_start(BOX(hbMain), vbSec1, false, false,0)

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false, false,0)
 labDummy = label_new("Source:")
 labDummy.set_size_request(55,15)
 pack_start(BOX(hbFill), labDummy, false, false, 0)

 cbProf = combo_box_text_new()
 set_tooltip_text(cbProf,"Select booru from list")
 pack_start(BOX(hbFill), cbProf, true, true, 0)

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false,false,0)
 labDummy = label_new("Tags:")
 labDummy.set_size_request(55,15)
 pack_start(BOX(hbFill), labDummy, false, false, 0)

 enTags = entry_new()
 set_tooltip_text(enTags,"Enter search tags here")
 pack_start(BOX(hbFill), enTags, true, true, 0)

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false,false,0)
 labDummy = label_new("Folder:")
 labDummy.set_size_request(55,15)
 pack_start(BOX(hbFill), labDummy, false, false, 0)

 cbFolder = button_new("Choose Folder")
 set_tooltip_text(cbFolder,"Select folder to save fetched images into")
 discard signal_connect(cbFolder, "clicked", SIGNAL_FUNC(nibolo.chooseFolder), cbFolder)
 pack_start(BOX(hbFill), cbFolder, true, true, 0)

 hbFill = hbox_new(true,0)
 pack_start(BOX(vbSec1), hbFill, false,false,0)

 bStart = button_new("Start")
 set_tooltip_text(bStart,"Start fetching images")
 discard signal_connect(bStart, "clicked", SIGNAL_FUNC(nibolo.startGrab), nil)
 pack_start(BOX(hbFill), bStart, true, true, 0)
 bStop = button_new("Stop")
 set_tooltip_text(bStop,"Stop fetching images")
 discard signal_connect(bStop, "clicked", SIGNAL_FUNC(nibolo.stopGrab), nil)
 pack_end(BOX(hbFill), bStop, true, true, 0)

 labDummy = label_new("Nibolo - Nim Booru Loader | $1" % [VERSION])
 pack_start(BOX(vbSec1), labDummy, false, false, 20)

 sbInfo = statusbar_new()
 set_tooltip_text(sbInfo,"Info status bar...")
 discard push(sbInfo, 1, "Status: Idle...")
 pack_start(BOX(vbSec1), sbInfo, false, false, 5)

 sbProgress = statusbar_new()
 set_tooltip_text(sbProgress,"Supposedly fetching status bar...")
 discard push(sbProgress, 1, "")
 pack_start(BOX(vbSec1), sbProgress, false, false, 5)

 vmToggle = toggle_button_new("View mode toggle")
 set_tooltip_text(vmToggle,"Browse trough your search and pick images to save manualy")
 pack_start(BOX(vbSec1), vmToggle, false, false, 0)

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false, false, 0)

 bSaveImg = button_new_from_stock(STOCK_SAVE)
 set_tooltip_text(bSaveImg,"Save Image (View Mode)")
 discard signal_connect(bSaveImg, "clicked", SIGNAL_FUNC(nibolo.vmSaveImg), nil)
 pack_start(BOX(hbFill), bSaveImg, false, false, 0);

 bSaveImgAs = button_new_from_stock(STOCK_SAVE_AS)
 set_tooltip_text(bSaveImgAs,"Save Image As (View Mode)")
 discard signal_connect(bSaveImgAs, "clicked", SIGNAL_FUNC(nibolo.vmSaveImgAs), nil)
 pack_start(BOX(hbFill), bSaveImgAs, false, false, 0);

 bNextImg = button_new_from_stock(STOCK_MEDIA_NEXT)
 set_tooltip_text(bNextImg,"Next Image (View Mode)")
 discard signal_connect(bNextImg, "clicked", SIGNAL_FUNC(nibolo.vmNextImg), nil)
 pack_start(BOX(hbFill), bNextImg, false, true, 0);

 # right side
 vbSec2 = vbox_new(false,0)
 pack_start(BOX(hbMain), vbSec2, true,true,0)

 pwMain = image_new()
 set_tooltip_text(pwMain,"The ultimate donuts loving goddess !")
 discard signal_connect(pwMain, "size-allocate", SIGNAL_FUNC(nibolo.pwMainGetSize), nil)
 pack_start(BOX(vbSec2), pwMain, true, true, 0)

 hbFill = hbox_new(false,2)
 pack_end(BOX(vbSec2), hbFill, false, false, 0)

 bQuit = button_new("Quit")
 set_tooltip_text(bQuit,"Quit Nibolo")
 discard signal_connect(bQuit, "clicked", SIGNAL_FUNC(nibolo.destroy), nil)
 pack_end(PBox(hbFill), bQuit, true, false, 0)

 bProfUpdate = button_new("Refresh 'source'")
 set_tooltip_text(bProfUpdate,"Refresh source list")
 discard signal_connect(bProfUpdate, "clicked", SIGNAL_FUNC(nibolo.updateProfilesList), nil)
 pack_end(PBox(hbFill), bProfUpdate, true, false, 0)

 bProfEdit = button_new("Edit Profiles")
 set_tooltip_text(bProfEdit,"Opens your default editor.. maybe")
 discard signal_connect(bProfEdit, "clicked", SIGNAL_FUNC(nibolo.editProfiles), nil)
 pack_end(PBox(hbFill), bProfEdit, true, false, 0)

 bProfReset = button_new("Reset Profiles")
 set_tooltip_text(bProfReset,"Reset your Profiles.ini ...")
 discard signal_connect(bProfReset, "clicked", SIGNAL_FUNC(nibolo.resetProfiles), nil)
 pack_start(PBox(hbFill), bProfReset, true, false, 0)

 fillProfileComboBox()
 mainWin.show_all()

 imMain = pixbuf_new_from_file_at_size(fpPicMain, pwW, pwH,nil)
 set_from_pixbuf(PImage(pwMain),imMain)

 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

 when defined(ssl):
  updateCheck(VERSION)
 main()


when isMainModule: nibolo.startUp()
