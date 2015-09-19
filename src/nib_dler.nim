import os,strutils, streams , parsexml , md5
import nib_types , nib_cfg
import net_fix/nib_httpC , net_fix/nib_net
# import httpclient,net
import gtk2 , dialogs

var
 viewMode: bool
 dontRapeMe: bool
 stopMe: bool


proc downloadFile(url: string, outputFilename: string,eHeaders: string) =
 var f: File
 when not defined(ssl):
  var defSSLCont: SSLContext = nil
 else:
  var defSSLCont = newContext(verifyMode = CVerifyNone)

 if open(f, outputFilename, fmWrite):
  f.write(getContent(url= url, extraHeaders=eHeaders,sslContext=defSSLCont))
  f.close()
 else:
  var e: ref IOError
  new(e)
  e.msg = "Unable to open file"
  raise e

proc protoDownload(paths: TPaths,curProf: PBooruProf, folder: string,
   chanGui,chanDler: ptr StringChannel, data: TLinkData,defSSLCont: SSLContext): bool =
 var
  acceptTypes: seq[string] = @[".png",".jpeg",".jpg",".jpe",".bmp",".tiff",".tif"]
  fileName,filePath,dlLink: string = ""
  sExt,sName,buff: string = ""
  chanBuff: string = ""
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
  sName = getMD5(dlLink)
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

 # Generate filename/path, if exists, skip (names are now generated from url by md5)
 fileName = "$1$2" % [sName ,sExt]
 if viewMode:
  filePath = joinPath(paths.dirTemp,fileName)
 else:
  filePath = joinPath(folder,fileName)
  if fileExists(filePath):
   return

 var
  respGet: Response
  httpCode: string = ""

 try:
  respGet = request(dlLink, httpHead , extraHeaders=
   if curProf.cookie != "": curProf.cookie else: "",sslContext=defSSLCont)
  httpCode = respGet.status
 except:
  return
 if dontRapeME:
  sleep(1500)
 # Checks, checks, checks , trying to avoid downloading invalid files
 if httpCode.startsWith("200"):
  echo "Downloading: $1" % [dlLink]
  try:
   if curProf.cookie != "":
    downloadFile(dlLink ,filePath, curProf.cookie)
   else:
    downloadFile(dlLink ,filePath, eHeaders = "")

   chanGui[].send("newPreview $1" % filePath)
   if viewMode:
    ## view mode choices
    while true:
     chanBuff = chanDler[].recv()
     case chanBuff
     of "imgSave":
      let savePath = joinPath(folder,fileName)
      copyFile(filePath,savePath)
      break
     of "imgNext":
      break
     of "stopGrab":
      stopMe = true
      break
     of "quit":
      quit(0)
     of "reqFileName":
      chanGui[].send("fileName $1" % filePath)
     else:
      if chanBuff.startsWith("imgSaveAs"):
       chanBuff.delete(0,9)
       copyFile(filePath,chanBuff)
       break;
      elif chanBuff.startsWith("viewMode"):
       chanBuff.delete(0,8)
       if chanBuff == "true":
        viewMode = true
       else:
        viewMode = false
       if viewMode == false:
        break
      elif chanBuff.startsWith("antiRape"):
       chanBuff.delete(0,8)
       if chanBuff == "true":
        dontRapeMe = true
       else:
        dontRapeMe = false
      else:
       chanGui[].send("*** Error: Unknow command $1" % chanBuff)
     chanBuff = ""
    ## asdasdasd
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
    respGet = request(dlLink, httpHead , extraHeaders=
     if curProf.cookie != "": curProf.cookie else: "",sslContext = defSSLCont)
    httpCode = respGet.status
   except:
    break
   if httpCode.startsWith("200"):
    try:
     fileName = "$1[$2]$3" % [curProf.name ,sName ,sExt]
     if viewMode:
      filePath = joinPath(paths.dirTemp,fileName)
     else:
      filePath = joinPath(folder,fileName)
      if fileExists(filePath):
       return
     if curProf.cookie != "":
      downloadFile(dlLink ,filePath, curProf.cookie)
     else:
      downloadFile(dlLink ,filePath, "")

     chanGui[].send("newPreview $1" % filePath)
     if viewMode:
      while true:
       chanBuff = chanDler[].recv()
       case chanBuff
       of "imgSave":
        let savePath = joinPath(folder,fileName)
        copyFile(filePath,savePath)
        break
       of "imgNext":
        break
       of "stopGrab":
        stopMe = true
        break
       of "quit":
        quit(0)
       of "reqFileName":
        chanGui[].send("fileName $1" % filePath)
       else:
        if chanBuff.startsWith("imgSaveAs"):
         chanBuff.delete(0,9)
         copyFile(filePath,chanBuff)
         break;
        elif chanBuff.startsWith("viewMode"):
         chanBuff.delete(0,8)
         if chanBuff == "true":
          viewMode = true
         else:
          viewMode = false
         if viewMode == false:
          break
        elif chanBuff.startsWith("antiRape"):
         chanBuff.delete(0,8)
         if chanBuff == "true":
          dontRapeMe = true
         else:
          dontRapeMe = false
        else:
         chanGui[].send("*** Error: Unknow command $1" % chanBuff)
      chanBuff = ""
     removeFile(filePath)
     result = true
     echo "*** Success"
    except: # Shouldn't happen .. i hope ..
     removeFile(filePath)
     echo "Debug: Download exception"
    finally:
     break


proc protoSearch(paths: TPaths,searchTag, saveFolder: string, curProf: PBooruProf,
                  chanGui,chanDler: ptr StringChannel) =
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

 when not defined(ssl):
  var defSSLCont: SSLContext = nil
 else:
  var defSSLCont = newContext(verifyMode = CVerifyNone)

 linkData.url = ""
 linkData.name = ""
 linkData.ext = ""

 if curProf.sUrlOpt1 == "" and curProf.sUrlOpt2 == "":
  chanGui[].send("*** Error: At least one search option is needed. Check your profiles.")
  return
 elif curProf.sUrlOpt1.endsWith("[s]") == false and curProf.sUrlOpt2.endsWith("[s]") == false:
  chanGui[].send("*** Error: Cannot determine where to input search tags. Check your profiles.")
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

  let chanTryBuff = chanDler[].tryRecv()
  if chanTryBuff.dataAvailable:
   var chanBuff = chanTryBuff.msg
   case chanBuff
   of "stopGrab":
    stopMe = true
   of "quit":
    quit(0)
   else:
    if chanBuff.startsWith("viewMode"):
     chanBuff.delete(0,8)
     if chanBuff == "true":
      viewMode = true
     else:
      viewMode = false
    elif chanBuff.startsWith("antiRape"):
     chanBuff.delete(0,8)
     if chanBuff == "true":
      dontRapeMe = true
     else:
      dontRapeMe = false
    else:
     discard

  if stopME:
   return
  chanGui[].send("sbInfo Status: Searching for images..")

  if searchOpt2 != "":
   requestURL = "$1$2$3&$4$5" %
    [curProf.sUrl,searchOpt1,(if optLoop1: $iLoop1 else: ""), searchOpt2,(if optLoop2: $iLoop2 else: "")]
  else:
   requestURL = "$1$2" % [curProf.sUrl,searchOpt1]

  echo ("Looking trough $1 ..." % [requestURL])
  respGet = request(requestURL, httpGet , extraHeaders=
   if curProf.cookie != "": curProf.cookie else: "",sslContext = defSSLCont)

  if respGet.status.startsWith("200") == false:
   return

  if respFile.open( paths.fpResponse ,fmWrite):
    respFile.writeLine(respGet.body)
    respFile.flushFile()
    respFile.close()
  else:
   return

  # We got some response, lets check it
  var s = newFileStream(paths.fpResponse, fmRead)
  if s == nil:
   chanGui[].send("*** Error: Cannot open the file '$1' " % paths.fpResponse)
   return
  var x: XmlParser
  open(x, s, paths.fpResponse)
  # Loops and loops and loops..
  while true:

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
        let chanTryBuff2 = chanDler[].tryRecv()
        if chanTryBuff2.dataAvailable:
          var chanBuff2 = chanTryBuff2.msg
          case chanBuff2
          of "stopGrab":
           stopMe = true
           return
          of "quit":
           quit(0)
          else:
           if chanBuff2.startsWith("viewMode"):
            chanBuff2.delete(0,8)
            if chanBuff2 == "true":
             viewMode = true
            else:
             viewMode = false
           elif chanBuff2.startsWith("antiRape"):
            chanBuff2.delete(0,8)
            if chanBuff2 == "true":
             dontRapeMe = true
            else:
             dontRapeMe = false
           else:
            discard
        chanGui[].send("sbInfo Status: Downloading images..")
        if protoDownload(paths,curProf,saveFolder,chanGui,chanDler,linkData,defSSLCont):
         inc(iDL)
         chanGui[].send("sbProg Status: Downloaded $1 images" % [$iDL])
         tryNextPage = true
        # We are at the end of element we were parsing from, we can break the loop
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

proc dlerStartUp* (paths: TPaths,chanGui,chanDler: ptr StringChannel) =
 var
  chanBuff: string = ""
  tags,saveTo: string = ""
  activeProfile: PBooruProf

 new activeProfile

 while true:
  chanBuff = ""
  chanBuff = chanDler[].recv()
  case chanBuff
  of "startGrab":
   paths.protoSearch(tags,saveTo,activeProfile,chanGui,chanDler)
   stopMe = false
   removeFile(paths.fpResponse)
   chanGui[].send("sbInfo Status: Idle...")

  of "quit":
   quit(0)

  else:
   if chanBuff.startsWith("profile"):
    chanBuff.delete(0,7)
    discard paths.loadProfile(chanBuff,activeProfile)

   elif chanBuff.startsWith("tags"):
    chanBuff.delete(0,4)
    tags = chanBuff

   elif chanBuff.startsWith("saveTo"):
    chanBuff.delete(0,6)
    saveTo = chanBuff

   elif chanBuff.startsWith("viewMode"):
    chanBuff.delete(0,8)
    if chanBuff == "true":
     viewMode = true
    else:
     viewMode = false

   elif chanBuff.startsWith("antiRape"):
    chanBuff.delete(0,8)
    if chanBuff == "true":
     dontRapeMe = true
    else:
     dontRapeMe = false

   else:
    echo "Unwanted message arrived on channel chanDler '$1'" % chanBuff

  chanBuff = ""





