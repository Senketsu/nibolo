import strutils, os, streams, httpclient, parsexml, parsecfg
import asyncdispatch
import projUtils
import projTypes

type
  NdlChans = tuple
    dl, main: ptr StringChannel
    buffer: string

  NdlProfile = tuple
    name, uri, api: string
    searchOpt: string
    parseEle: string
    parseKey: string
    parseUriFix: string
    custName: string

  NdlNameType = enum
    NntName,
    NntHash,
    NntTags,
    NntCust

  NdlEvent = enum
    NCStart       = ("NCStart")
    NCStop        = ("NCStop")
    NCSave        = ("NCSave")
    NCSaveAs      = ("NCSaveAs")
    NCSaveFol     = ("NCSaveFol")
    NCOptSlow     = ("NCOptSlow")
    NCOptView     = ("NCOptView")
    NCOptBrowse   = ("NCOptBrowse")
    NCProfile     = ("NCProfile")
    NCNewTags     = ("NCNewTags")
    NCNext        = ("NCNext")
    NCCheckUpdates= ("NCCheckUpdates")
    NCNone        = ("NCNone")
    NCUnkn        = ("NCUnkn")
    NCQuit        = ("NCQuit")

  NdlOpt = tuple
    slow, view, browse, blocking: bool

  NdlSes = tuple
    iPage, iDownloads: int
    iDuplicates, iDelay: int
    iRetry: int
    hasData: bool
    profile: NdlProfile
    search, folder: string
    
  NdlObj = object
    chan: NdlChans
    status: NdlStatus
    event: NdlEvent
    eventArgs: string
    prof: NdlProfile
    nameType: NdlNameType
    searchTags: string
    saveFolder: string
    savePath: string
    option: NdlOpt
    session: NdlSes

  Ndl* = ref NdlObj

proc getNextVersionNumber(curVer: string): string =
  var
    vM,vS,vT: int = 0
    split = curVer.split(".")

  vM = parseInt(split[0])
  vS = parseInt(split[1])
  vT = parseInt(split[2])
 
  inc(vT)
  if vT > 9:
   vT = 0
   inc(vS)
   if vS > 9:
    vS = 0
    inc(vM)
 
  result = "$1.$2.$3" % [$vM,$vS,$vT]

proc checkForUpdates(): tuple[available: bool, version: string] =
  var
   nextVer: string = ""
   client = newHttpClient()
   response: Response
   version = VERSION
  
  while true:
    try:
      nextVer = getNextVersionNumber(version)
      response = request(client, "$1/releases/tag/v$2" % [LINK, nextVer], HttpGet)
    except:
      logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
 
    if response.status.startsWith("200"):
      result.available = true
      result.version = nextVer
      version = nextVer
    else:
      break
    
include profiles

proc new*(chanDler, chanMain: ptr StringChannel): Ndl =
  result = new(Ndl)
  result.chan.dl = chanDler
  result.chan.main = chanMain
  result.chan.buffer = ""
  result.status = NdlStopped
  result.event = NCNone
  result.eventArgs = ""
  result.searchTags = ""
  result.saveFolder = getPath("dirPic")
  result.savePath = ""
  result.prof.clean()
  result.session.profile.clean()
  result.session.folder = ""
  result.session.search = ""


proc handleEvent(ndl: Ndl) =
    if ndl.event != NCUnkn:
      case ndl.event
        of NCQuit:
          ndl.status = NdlQuit
          ndl.chan.main[].send("NdlQuit")
        of NCStart:
          case ndl.status
          of NdlStopped:
            ndl.status = NdlRunning
            ndl.option.blocking = ndl.option.browse
            ndl.chan.main[].send("NdlRunning")
            ndl.chan.main[].send("smsg Search running..")
          of NdlPaused:
            ndl.status = NdlRunning
            ndl.option.blocking = ndl.option.browse
            ndl.chan.main[].send("NdlRunning")
            ndl.chan.main[].send("smsg Search running..")
          of NdlRunning:
            ndl.status = NdlPaused
            ndl.option.blocking = true
            ndl.chan.main[].send("NdlPaused")
            ndl.chan.main[].send("smsg Search paused..")
          else: discard
        of NCStop:
          ndl.status = NdlStopped
          ndl.chan.main[].send("NdlStopped")
          ndl.chan.main[].send("smsg Search stopped..")
        
        of NCSaveFol:
          ndl.saveFolder = ndl.eventArgs
        of NCNewTags:
          ndl.searchTags = ndl.eventArgs
        of NCOptSlow:
          if ndl.eventArgs == "true":
            ndl.option.slow = true
          else:
            ndl.option.slow = false
        of NCOptView:
          if ndl.eventArgs == "true":
            ndl.option.view = true
          else:
            ndl.option.view = false
        of NCOptBrowse:
          if ndl.eventArgs == "true":
            ndl.option.browse = true
            ndl.option.blocking = true
          else:
            ndl.option.browse = false
            ndl.option.blocking = (ndl.status == NdlPaused)
        of NCProfile:
          if not ndl.loadProfile(ndl.eventArgs):
            ndl.chan.main[].send("ERR Loading profile '$1' failed." % ndl.eventArgs)
        of NCSave, NCSaveAs, NCNext:
          discard # We handle those externally
        of NCCheckUpdates:
          var update = checkForUpdates()
          if update.available:
            ndl.chan.main[].send("UpdatePrompt " & update.version)
            echoInfo("Debug: Update check: Newer version found")
          else:
            echoInfo("Debug: Update check: Running newest version")
        else:
          echoInfo("Debug: Coudn't handle event '$1'" % $ndl.event)
          discard

proc processCmd(ndl: Ndl) =
  var
    cmd = ""
    args = ""
  try:
    var splitCMD = ndl.chan.buffer.split(" ")
    for i in 0..splitCMD.high:
      if i == 0: cmd = splitCMD[i]
      if i > 0:
        args.add(splitCMD[i])
        args.add(" ")
    args.delete(args.len, args.len)
    ndl.eventArgs = args
    ndl.chan.buffer = ""
  except:
    logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
    return
  
  case cmd
  of "NCStart": ndl.event = NCStart
  of "NCStop": ndl.event = NCStop
  of "NCSave": ndl.event = NCSave
  of "NCSaveAs": ndl.event = NCSaveAs
  of "NCSaveFol": ndl.event = NCSaveFol
  of "NCNewTags": ndl.event = NCNewTags
  of "NCProfile": ndl.event = NCProfile
  of "NCOptSlow": ndl.event = NCOptSlow
  of "NCOptView": ndl.event = NCOptView
  of "NCOptBrowse": ndl.event = NCOptBrowse
  of "NCCheckUpdates" : ndl.event = NCCheckUpdates
  of "NCNext": ndl.event = NCNext
  of "NCQuit": ndl.event = NCQuit
  else: ndl.event = NCUnkn


proc update(ndl: Ndl, blocking: bool = false): NdlEvent =

  if blocking:
    ndl.chan.buffer = ndl.chan.dl[].recv()
    ndl.processCmd()
    ndl.handleEvent()
  else:
    var buff = ndl.chan.dl[].tryRecv()
    if buff.dataAvailable:
      ndl.chan.buffer = buff.msg
      ndl.processCmd()
      ndl.handleEvent()
    else:
      ndl.event = NCNone
      ndl.eventArgs = ""
  return ndl.event


proc download(ndl: Ndl, fileURI, fileName, fileExt, fileTags, fileHash: string) =
  var
    client = newHttpClient()
  ndl.savePath = ""

  case ndl.nameType
  of NntName:
    ndl.savePath = joinPath(ndl.session.folder, fileName & fileExt)
  of NntTags:
    ndl.savePath = joinPath(ndl.session.folder, fileTags & fileExt)
  of NntHash:
    ndl.savePath = joinPath(ndl.session.folder, fileHash & fileExt)
  of NntCust:
    var name = ndl.session.profile.custName
    name = name.replace("[b]", ndl.session.profile.name)
    name = name.replace("[h]", fileHash)
    name = name.replace("[n]", fileName)
    name = name.replace("[t]", fileTags)
    name = name.replace("[s]", ndl.session.search)
    name = name & fileExt
    ndl.savePath = joinPath(ndl.session.folder, name)
    # We don't handle stupid, not my problem if someone fucks up custom naming
  else:
    # Shouldn't happen, we default to NntName in profiles
    discard 
  
  try:
    ## TODO maybe some actual duplicate check ? P.S: Do I care ?
    if not fileExists(ndl.savePath):
      if ndl.option.slow:
        sleep(ndl.session.iDelay)
      echoInfo("Debug: Downloading..\n\t$1" % [fileURI])
      client.downloadFile(fileURI, ndl.savePath)
      ndl.session.iDownloads += 1
      ndl.chan.main[].send("pmsg Downloaded $1 files .." % $ndl.session.iDownloads)
    else:
      echoInfo("Debug: Skipped downloading duplicate file..\n\t$1" % fileURI)
      ndl.session.iDuplicates += 1
      ndl.chan.main[].send("pmsg Skipped downloading $1 files.." % $ndl.session.iDuplicates)          
      
    if ndl.option.view or ndl.option.browse:
      ndl.chan.main[].send("pv $1" % ndl.savePath)
    
  except:
    logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])


proc searchCleanup(parser: var XmlParser, stream: var FileStream, fp: string) =
  parser.close()
  stream.close()
  removeFile(fp)

proc clean(session: var NdlSes) =
  session.iPage = 0
  session.iDownloads = 0
  session.iDuplicates = 0
  session.iDelay = 3000
  session.iRetry = 0
  session.hasData = false
  session.search = ""
  session.folder = ""
  session.profile.clean()

proc search(ndl: Ndl) =
  var
    fpRespFile = getPath("response")
    client = newHttpClient()
    respGet: Response
    respFile: File
    searchURI: string = ""
    stream: FileStream
    xmlParser: XmlParser
    elementFound: bool
    fileUri, fileTags, fileName, fileExt, fileHash: string = ""
  
  ndl.session.clean()
  ndl.session.profile = ndl.prof
  ndl.session.search = ndl.searchTags
  ndl.session.folder = ndl.saveFolder
  
  while ndl.status == NdlRunning:
    ndl.session.hasData = false
    searchURI = ndl.session.profile.api & ndl.session.profile.searchOpt
    searchURI = searchURI.replace("[i]", $ndl.session.iPage)
    searchURI = searchURI.replace("[st]", ndl.session.search)
    
    while true:
      try:
        echoInfo("Debug: Requesting $1" % searchURI)
        respGet = request(client, searchURI, HttpGet)
        if respGet.status.startsWith("200"):
          respFile = open(fpRespFile, fmWrite)
          respFile.writeLine(respGet.body)
          respFile.flushFile()
          respFile.close()
          ndl.session.iRetry = 0
          break
        else:
          logEvent(true, "***Error: Unwanted response: $1" % respGet.status)
          return
      except ProtocolError:
        # This should handle server burps..hopefuly (throws ProtocolError)
        if ndl.session.iRetry >= 3:
          ndl.chan.main[].send("smsg Search canceled, server error")     
          return
        ndl.session.iRetry += 1
        ndl.chan.main[].send("smsg Server error, retrying .. $1 / 3" % $ndl.session.iRetry)
        sleep(3000)
        continue        
      except:
        logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
        ndl.chan.main[].send("smsg Search canceled, error occured")
        return
    
    stream = newFileStream(fpRespFile, fmRead)
    if stream == nil:
      logEvent(true, "***Error: cound't open filestream")
      return
    
    ndl.chan.main[].send("smsg Search running..")
    xmlParser.open(stream, fpRespFile)
    while true:
      xmlParser.next()
      case xmlParser.kind
      of xmlElementOpen, xmlElementStart:
        if cmpIgnoreCase(xmlParser.elementName, ndl.session.profile.parseEle) == 0:
          elementFound = true
      of xmlAttribute:
        if (xmlParser.attrKey == ndl.session.profile.parseKey):
          ## TODO: add extensions either here or in dl path construct
          var uri = ndl.session.profile.parseUriFix.replace("[u]", xmlParser.attrValue)
          var splitFile = uri.splitFile()
          fileName = splitFile.name
          fileExt = splitFile.ext
          fileUri = uri
          ndl.session.hasData = true
        elif xmlParser.attrKey == "tags":
          fileTags = xmlParser.attrValue
        elif xmlParser.attrKey == "md5":
          fileHash = xmlParser.attrValue
        else:
          discard
      of xmlElementEnd, xmlElementClose:
        if elementFound:
          elementFound = false
          ndl.download(fileUri, fileName, fileExt, fileTags, fileHash)
          
          while true:
              case ndl.update(ndl.option.blocking)
              of NCSave:
                break
              of NCSaveAs:
                moveFile(ndl.savePath, ndl.eventArgs)
                break
              of NCNext:
                removeFIle(ndl.savePath)
                break
              of NCStop, NCQuit:
                echoInfo("Debug: Canceling search by user request..")
                searchCleanup(xmlParser, stream, fpRespFile)
                return
              of NCNone:
                break
              else:
                continue
      
      of xmlEof:
        echoInfo("Debug: End of page $1" % $ndl.session.iPage)
        searchCleanup(xmlParser, stream, fpRespFile)
        if not ndl.session.hasData:
          echoInfo("Debug: No more files found in this request, exiting search..")
          ndl.chan.dl[].send("NCStop")
          ndl.chan.main[].send("pmsg No more files found..")
          return
        ndl.session.iPage += 1
        break
      else:
        echoInfo("Debug: Unwanted xml parser kind: $1" % repr xmlParser.kind)
  
            
  searchCleanup(xmlParser, stream, fpRespFile)

proc idle*(ndl:Ndl) =
  while ndl.update(true) != NCQuit:
    if ndl.event == NCStart:
      ndl.search()
      if ndl.status == NdlQuit:
        return
    echoInfo("Worker: Waiting for new command...")
    




