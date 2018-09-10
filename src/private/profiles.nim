
proc createDefaultProfiles*() =
  var
   cfgFile: File
  if cfgFile.open(getPath("profiles") ,fmWrite):
   cfgFile.writeLine("# Explanation:")
   cfgFile.writeLine("# [searchOpt]: additional paramts for searches")
   cfgFile.writeLine("#   [i] indicated page counter parameter")
   cfgFile.writeLine("#   [st] your search tags will go here")
   cfgFile.writeLine("# [parseUriFix]:  If you need to manipulate parsed uri")
   cfgFile.writeLine("#   [u] holds the parsed uri, prepend or append as you wish")
   cfgFile.writeLine("# [custName]:     Custom file names")
   cfgFile.writeLine("#   [b] for booru name (as used in profile)")
   cfgFile.writeLine("#   [n] for filename extracted from the link")
   cfgFile.writeLine("#   [h] for md5 hash supplied by website")
   cfgFile.writeLine("#   [t] for tags (WARNING: possibly too long filenames")
   cfgFile.writeLine("#   Feel free to combine or not use thme at all.")
   
 
   cfgFile.writeLine("[safebooru]")
   cfgFile.writeLine("uri=\"https://safebooru.org\"")
   cfgFile.writeLine("api=\"https://safebooru.org/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"https:[u]\"")
   cfgFile.writeLine("custName=\"[b][h]\"")
 
 
   cfgFile.flushFile()
   cfgFile.close()
  else:
   echo "no write permission ?"


proc resetProfiles(ndl: Ndl) =
  ndl.prof.name = ""
  ndl.prof.uri = ""
  ndl.prof.api = ""
  ndl.prof.searchOpt = ""
  ndl.prof.parseKey = ""

proc profilesLoad*(ndl: Ndl): bool =
  var pathProfiles = getPath("profiles")
  var fpProfiles = newFileStream(pathProfiles, fmRead)
  if ndl.activeProf == "":
    ndl.activeProf = "safebooru"
  if fpProfiles != nil:
    var cfgParser: CfgParser
    open(cfgParser, fpProfiles, pathProfiles)
    var event = next(cfgParser)
    ndl.resetProfiles()

    while true:
      case event.kind
      of cfgEof:
        break
      of cfgSectionStart:
        if event.section == ndl.activeProf:
          result = true
          ndl.prof.name = event.section
          event = next(cfgParser)

          while event.kind == cfgKeyValuePair or event.kind == cfgOption:
            if event.kind == cfgKeyValuePair:
              case event.key
              of "uri":
                ndl.prof.uri = event.value
              of "api":
                ndl.prof.api = event.value
              of "searchOpt":
                ndl.prof.searchOpt = event.value
              of "parseKey":
                ndl.prof.parseKey = event.value
              of "parseEle":
                ndl.prof.parseEle = event.value
              of "parseUriFix":
                ndl.prof.parseUriFix = event.value
              else:
                discard
              event = next(cfgParser)
      of cfgError:
        logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
      else:
        discard
      event = next(cfgParser)
    close(cfgParser)
  else:
    createDefaultProfiles()
    result = ndl.profilesLoad()
  if not result:
    logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
  
