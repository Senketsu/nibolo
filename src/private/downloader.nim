import strutils, os, streams, httpclient, parsexml, md5, parsecfg
import asyncdispatch
import projUtils
import projTypes

type
  NdlChans = tuple
    dl, main: ptr StringChannel
  
  NdlStatus = enum
    NdlRunning,
    NdlPaused,
    NdlStopped,
    NdlQuit

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
    NCStart     = ("NCStart")
    NCStop      = ("NCStop")
    NCSave      = ("NCSave")
    NCSaveAs    = ("NCSaveAs")
    NCSaveFol   = ("NCSaveFol")
    NCOptSlow   = ("NCOptSlow")
    NCOptView   = ("NCOptView")
    NCOptBrowse = ("NCOptBrowse")
    NCProfile   = ("NCProfile")
    NCNewTags   = ("NCNewTags")
    NCNext      = ("NCNext")
    NCNone      = ("NCNone")
    NCQuit      = ("NCQuit")

  NdlCmd = tuple
    cmd, args: string

  NdlOpt = tuple
    slow, view, browse: bool

  NdlObj = object
    chan: NdlChans
    chanBuffer: string
    status: NdlStatus
    event: NdlEvent
    eventArgs: string
    prof: NdlProfile
    activeProf: string
    nameType: NdlNameType
    searchTags: string
    saveFolder: string
    option: NdlOpt

  Ndl* = ref NdlObj


include profiles

proc new*(chanDler, chanMain: ptr StringChannel): Ndl =
  result = new(Ndl)
  result.chan.dl = chanDler
  result.chan.main = chanMain
  result.chanBuffer = ""
  result.status = NdlStopped
  result.event = NCNone
  result.eventArgs = ""  
  result.activeProf = ""
  result.searchTags = ""
  result.saveFolder = getPath("dirPic")
  result.prof.name = ""
  result.prof.uri = ""
  result.prof.api = ""
  result.prof.searchOpt = ""
  result.prof.parseKey = ""
  result.prof.parseEle = ""
  result.prof.parseUriFix = ""
  result.prof.custName = ""


proc handleEvent(ndl: Ndl) =
    if ndl.event != NCNone:
      case ndl.event
        of NCQuit:
          ndl.status = NdlQuit
        of NCStart:
          case ndl.status
          of NdlStopped:
            ndl.status = NdlRunning
            ndl.chan.main[].send("")
          of NdlPaused:
            ndl.status = NdlRunning
            ndl.chan.main[].send("")
          of NdlRunning:
            ndl.status = NdlPaused
            ndl.chan.main[].send("NdlStatus Paused")
          else: discard
        of NCStop:
          ndl.status = NdlStopped
        
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
          else:
            ndl.option.browse = false
        of NCProfile:
          ndl.activeProf = ndl.eventArgs
          if not ndl.profilesLoad():
            ndl.chan.main[].send("ERR")
        else:
          echoInfo("*Debug: Coudn't handle event '$1'" & $ndl.event)
          discard

proc processCmd(ndl: Ndl) =
  var
    cmd = ""
    args = ""
  try:
    var splitCMD = ndl.chanBuffer.split(" ")
    for i in 0..splitCMD.high:
      if i == 0: cmd = splitCMD[i]
      if i > 0:
        args.add(splitCMD[i])
        args.add(" ")
    args.delete(args.len, args.len)
    ndl.eventArgs = args
    ndl.chanBuffer = ""
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
  of "NCNext": ndl.event = NCNext
  of "NCQuit": ndl.event = NCQuit
  else: ndl.event = NCNone


proc update(ndl: Ndl, blocking: bool = false): NdlStatus =

  if blocking:
    ndl.chanBuffer = ndl.chan.dl[].recv()
  else:
    var buff = ndl.chan.dl[].tryRecv()
    if buff.dataAvailable:
      ndl.chanBuffer = buff.msg
  ndl.processCmd()
  ndl.handleEvent()
  return ndl.status


proc download(ndl: Ndl, fileURI, fileName, fileTags, fileHash: string) =
  var
    savePath = ""
    respGet: Response
    client = newHttpClient()

  case ndl.nameType
  of NntName:
    savePath = joinPath(ndl.saveFolder, fileName)
  of NntTags:
    savePath = joinPath(ndl.saveFolder, fileTags)
  of NNtHash:
    savePath = joinPath(ndl.saveFolder, fileHash)
  of NntCust:
    var name = ndl.prof.custName
    name = name.replace("[b]", ndl.prof.name)
    name = name.replace("[h]", fileHash)
    name = name.replace("[n]", fileName)
    name = name.replace("[t]", fileTags)
    savePath = joinPath(ndl.saveFolder, name)
  else:
    discard
  ## TODO maybe some actual duplicate check ?
  if fileExists(savePath):
    echo "skipped duplicate file"
    return
  
  ## TODO Interactive mode
  
  
  try:
    client.downloadFile(fileURI, savePath)
  except:
    logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
  
  if ndl.option.view or ndl.option.browse:
    ndl.chan.main[].send("pv $1" % savePath)


proc searchCleanup(parser: var XmlParser, stream: var FileStream, fp: string) =
  parser.close()
  stream.close()
  removeFile(fp)


proc search(ndl: Ndl) =
  var
    acceptTypes: seq[string] = @[".png",".jpeg",".jpg",".jpe",".bmp",".tiff",".tif"]
    fpRespFile = getPath("response")
    client = newHttpClient()
    respGet: Response
    respFile: File
    searchURI: string = ""
    pageInt: int = 0
    stream: FileStream
    xmlParser: XmlParser
    elementFound: bool
    fileUri, fileTags, fileName, fileHash: string = ""
  
  while ndl.status == NdlRunning:
    searchURI = ndl.prof.api & ndl.prof.searchOpt
    searchURI = searchURI.replace("[i]", $pageInt)
    searchURI = searchURI.replace("[st]", ndl.searchTags)
    
    respGet = request(client, searchURI, HttpGet)
    if respGet.status.startsWith("200"):
      try:
        respFile = open(fpRespFile, fmWrite)
        respFile.writeLine(respGet.body)
        respFile.flushFile()
        respFile.close()
      except:
        logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
        return
    else:
      logEvent(true, "***Error: Unwanted response: $1" % respGet.status)
      return
    
    stream = newFileStream(fpRespFile, fmRead)
    if stream == nil:
      logEvent(true, "***Error: cound't open filestream")
      return
    var hasData = false
    xmlParser.open(stream, fpRespFile)
    
    
    ## XML Parsing
    while ndl.status != NdlStopped or ndl.status != NdlQuit:
      # Good place to check on new updates
      if ndl.update(false) != NdlRunning:
        while ndl.update(true) != NdlQuit:
          case ndl.status
          of NdlStopped, NdlQuit:
            echoInfo("*Debug: Canceling search by user request..")
            searchCleanup(xmlParser, stream, fpRespFile)
            return
          of NdlRunning:
            break
          else:
            discard
      if ndl.status == NdlQuit:
        return
      
      xmlParser.next()
      case xmlParser.kind
      of xmlElementOpen, xmlElementStart:
        if cmpIgnoreCase(xmlParser.elementName, ndl.prof.parseEle) == 0:
          elementFound = true
      of xmlAttribute:
        if (xmlParser.attrKey == ndl.prof.parseKey):
          ## TODO: add extensions either here or in dl path construct
          var uri = ndl.prof.parseUriFix.replace("[u]", xmlParser.attrValue)
          var spFile = uri.splitFile()
          fileName = (spFile.name & spFile.ext)
          fileUri = uri
          hasData = true
        elif xmlParser.attrKey == "tags":
          fileTags = xmlParser.attrValue
        elif xmlParser.attrKey == "md5":
          fileHash = xmlParser.attrValue
        else:
          discard
      of xmlElementEnd, xmlElementClose:
        if elementFound:
          echoInfo("*Debug: Downloading image..")
          elementFound = false
          if ndl.option.slow:
            sleep(1500)
          ndl.download(fileUri, fileName, fileTags, fileHash)
      of xmlEof:
        echo "xmlEof page $1" % $pageInt
        searchCleanup(xmlParser, stream, fpRespFile)
        if not hasData:
          echoInfo("*Debug: No more images found, exiting search..")
          return
        pageInt += 1
        break
      else:
        echoInfo("*Debug: Unwanted xml parser kind: $1" % repr xmlParser.kind)
  
            
  searchCleanup(xmlParser, stream, fpRespFile)

proc idle*(ndl:Ndl) =
  while ndl.update(true) != NdlQuit:
    if ndl.event == NCStart:
      ndl.search()
      echoInfo("*Debug: Idling...")




