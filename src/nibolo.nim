import os, strutils, streams, strtabs, httpclient , parsexml , parsecfg , browsers
import gtk2 , gdk2pixbuf , glib2  , dialogs
from math import random

const VERSION = "v0.1a"

type
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
 actProfile: PBooruProf
 dirCfg,dirSaveTo: string = ""
 stopME: bool = false
 fpResponse,fpProfiles,fpPicMain: string = ""

new actProfile

proc isNumber* (s: string): bool =
 var i = 0
 while s[i] in {'0'..'9'}: inc(i)
 result = i == s.len and s.len > 0

proc destroy(widget: PWidget, data: Pgpointer) {.cdecl.} =
 stopME = true
 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()
 main_quit()

proc chooseFolder(widget: PWidget, data: Pgpointer) =
 var
  fullPath: cstring = ""
  folderName: string = ""
  fcDialog: PDialog

 fcDialog = file_chooser_dialog_new ("Select Folder", mainWin,
  FILE_CHOOSER_ACTION_SELECT_FOLDER , STOCK_CANCEL, RESPONSE_CANCEL,
  STOCK_APPLY, RESPONSE_ACCEPT, nil)

 if run(fcDialog) == RESPONSE_ACCEPT:
  fullPath = get_filename(FILE_CHOOSER(fcDialog))
  folderName = $fullPath
  folderName.delete(0,rfind(folderName,'/'))
  set_label(PButton(widget),folderName)
  set_tooltip_text(widget,fullPath)
  dirSaveTo = $fullPath
  destroy(fcDialog)
  while gtk2.events_pending () > 0:
   discard gtk2.main_iteration()
 else:
  destroy(fcDialog)

proc protoDownload(curProf: PBooruProf,folder: string, data: TLinkData): bool =
 var
  acceptTypes: seq[string] = @[".png",".jpeg",".jpg",".jpe",".bmp",".tiff",".tif"]
  fileName,filePath,dlLink: string = ""
  sExt,sName,buff: string = ""
  imPreview: PPixbuf
  splitLink: seq[string]

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
   imPreview = pixbuf_new_from_file_at_size(filePath, 400,350,nil)
   set_from_pixbuf(PImage(pwMain),imPreview)
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
     filePath = joinPath(folder,fileName)
     if fileExists(filePath):
      return
     downloadFile(dlLink ,filePath)
     imPreview = pixbuf_new_from_file_at_size(filePath, 400,350,nil)
     set_from_pixbuf(PImage(pwMain),imPreview)
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
      # Sometimes parser breaks (e.g: sankaku complex
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
 dirCfg = joinPath(getHomeDir(), ".config/Nibolo")
 fpResponse = joinPath(dirCfg,"response.html")
 fpProfiles = joinPath(dirCfg,"profiles.ini")
 fpPicMain = joinPath(dirCfg,"nibolo.png")
 if existsDir(dirCfg) == false:
  try:
   createDir(dirCfg)
   createDefaultProfiles()
  except:
   mainWin.error("***Error: Failed to create directory $1" % [dirCfg])
 if existsFile(fpProfiles) == false:
   createDefaultProfiles()
 # Fuck off , this is special case for me, cuz mama said im special
 # I need to look at muh shinobu while i 'code'
 if existsFile(fpPicMain) == false:
  fpPicMain = "/home/senketsu/Coding/Nim/Projects/nibolo/WiP/data/nibolo.png"


proc fillProfileComboBox() =
 var
  fileStream = newFileStream(fpProfiles, fmRead)

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
     cbProf.append_text(event.section)
    of cfgError:
     mainWin.error(event.msg)
    else: discard
  close(cfgParser)

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

 set_relief(PButton(widget),RELIEF_NONE)
 protoSearch(entryString,dirSaveTo,actProfile)
 stopMe = false
 removeFile(fpResponse)
 set_relief(PButton(widget),RELIEF_HALF)
 discard push(sbInfo, 1, "Status: Idle...")
 set_from_pixbuf(PImage(pwMain),imMain)

# For early draft .. dont judge me please
proc stopGrab(widget: PWidget, data: Pgpointer) =
 stopMe = true

proc editProfiles(widget: PWidget, data: Pgpointer) =
 openDefaultBrowser(fpProfiles)

proc update(widget: PWidget, data: Pgpointer) =
 let i = random(11)
 case i
 of 0,3,6:
  mainWin.info("NOT YET !")
 of 1,7,9:
  mainWin.info("I SIAD, NTO FUCKIGN YET! $@#$*&*")
 of 2,4:
  mainWin.info("It will be soon..BUT NOT YET")
 of 5,8,10:
  mainWin.error("Fuck you !")
  main_quit()
 else:
  discard

proc startUp () =

 var
  hbMain,vbMain,vbSec,hbFill,fcDialog: PWidget
  cbFolder,bStart,bStop,bQuit,bUpdate,bProFile: PButton
  labDummy: PLabel

 nimrod_init()
 nibolo.setCfgPath()
 mainWin = window_new(WINDOW_TOPLEVEL)
 discard signal_connect(mainWin, "destroy", SIGNAL_FUNC(nibolo.destroy), nil)
 mainWin.set_title("Nibolo")
 mainWin.resize(700,380)
 mainWin.set_position(WIN_POS_CENTER)
 set_border_width(PContainer(mainWin),3)

 hbMain = hbox_new(false,5)
 vbMain = vbox_new(false,5)
 vbSec = vbox_new(false,5)
 add(mainWin, hbMain)
 pack_start(PBox(hbMain), vbMain, true, true, 0)
 pack_start(PBox(hbMain), vbSec, true, true, 0)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)

 labDummy = label_new("Source:")
 labDummy.set_size_request(50,15)
 pack_start(PBox(hbFill), labDummy, false, false, 0)
 cbProf = combo_box_text_new()
 set_tooltip_text(cbProf,"Select booru from list")
 pack_start(PBox(hbFill), cbProf, true, true, 0)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)
 labDummy = label_new("Tags:")
 labDummy.set_size_request(50,15)
 pack_start(PBox(hbFill), labDummy, false, false, 0)
 enTags = entry_new()
 set_tooltip_text(enTags,"Enter search tags here")
 pack_start(PBox(hbFill), enTags, true, true, 0)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)
 labDummy = label_new("Folder:")
 labDummy.set_size_request(50,15)
 pack_start(PBox(hbFill), labDummy, false, false, 0)
 cbFolder = button_new("Choose Folder")
 set_tooltip_text(cbFolder,"Select folder to save fetched images into")
 discard signal_connect(cbFolder, "clicked", SIGNAL_FUNC(nibolo.chooseFolder), nil)
 pack_start(PBox(hbFill), cbFolder, true, true, 0)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)
 bStart = button_new("Start")
 set_tooltip_text(bStart,"Start fetching images")
 discard signal_connect(bStart, "clicked", SIGNAL_FUNC(nibolo.startGrab), nil)
 pack_start(PBox(hbFill), bStart, true, true, 0)
 bStop = button_new("Stop")
 set_tooltip_text(bStop,"Stop fetching images")
 discard signal_connect(bStop, "clicked", SIGNAL_FUNC(nibolo.stopGrab), nil)
 pack_end(PBox(hbFill), bStop, true, true, 0)

 labDummy = label_new("Nibolo - Nim Booru Loader | $1" % [VERSION])
 labDummy.set_size_request(50,15)
 pack_start(PBox(vbMain), labDummy, false, false, 30)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)

 sbInfo = statusbar_new()
 set_tooltip_text(sbInfo,"Info status bar...")
 discard push(sbInfo, 1, "Status: Idle...")
 pack_end(PBox(hbFill), sbInfo, true, true, 0)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbMain), hbFill, false, true, 0)
 sbProgress = statusbar_new()
 set_tooltip_text(sbProgress,"Supposedly fetching status bar...")
 discard push(sbProgress, 1, "")
 pack_end(PBox(hbFill), sbProgress, true, true, 0)

 pwMain = image_new()
 set_tooltip_text(pwMain,"The ultimate donuts loving goddess !")
 pwMain.set_size_request(400,350)
 pack_start(PBox(vbSec), pwMain, false, false, 0)
 imMain = pixbuf_new_from_file_at_size(fpPicMain, 400,350,nil)
 set_from_pixbuf(PImage(pwMain),imMain)

 hbFill = hbox_new(false,5)
 pack_start(PBox(vbSec), hbFill, false, false, 0)

 bQuit = button_new("Quit")
 set_tooltip_text(bQuit,"Quit Nibolo")
 discard signal_connect(bQuit, "clicked", SIGNAL_FUNC(nibolo.destroy), nil)
 pack_end(PBox(hbFill), bQuit, true, true, 10)

 bUpdate = button_new("Update")
 set_tooltip_text(bUpdate,"Update Nibolo (soonTM)")
 discard signal_connect(bUpdate, "clicked", SIGNAL_FUNC(nibolo.update), nil)
 pack_end(PBox(hbFill), bUpdate, true, true, 5)

 bProFile = button_new("Edit Profiles.ini")
 set_tooltip_text(bProFile,"Opens your default editor.. maybe")
 discard signal_connect(bProFile, "clicked", SIGNAL_FUNC(nibolo.editProfiles), nil)
 pack_end(PBox(hbFill), bProFile, true, true, 5)

 fillProfileComboBox()
 mainWin.show_all()
 main()

when isMainModule: nibolo.startUp()
