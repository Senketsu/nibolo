
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
   cfgFile.writeLine("#   [t] for tags (WARNING: possibly too long filenames)")
   cfgFile.writeLine("#   [s] for searched tags")
   cfgFile.writeLine("#   Feel free to combine or not use them at all.")
   
 
   cfgFile.writeLine("[safebooru]")
   cfgFile.writeLine("uri=\"https://safebooru.org\"")
   cfgFile.writeLine("api=\"https://safebooru.org/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"https:[u]\"")
   cfgFile.writeLine("custName=\"[[b]] [h]\"")
 
 
   cfgFile.writeLine("[gelbooru]")
   cfgFile.writeLine("uri=\"https://gelbooru.com/\"")
   cfgFile.writeLine("api=\"https://gelbooru.com/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"[u]\"")
   cfgFile.writeLine("custName=\"\"")
 
   cfgFile.writeLine("[rule34]")
   cfgFile.writeLine("uri=\"https://rule34.xxx/\"")
   cfgFile.writeLine("api=\"https://rule34.xxx/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"[u]\"")
   cfgFile.writeLine("custName=\"\"")
 
   cfgFile.writeLine("[xbooru]")
   cfgFile.writeLine("uri=\"https://xbooru.com/\"")
   cfgFile.writeLine("api=\"https://xbooru.com/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"[u]\"")
   cfgFile.writeLine("custName=\"\"")
 
 
   cfgFile.writeLine("[realbooru]")
   cfgFile.writeLine("uri=\"https://realbooru.com/\"")
   cfgFile.writeLine("api=\"https://realbooru.com/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"[u]\"")
   cfgFile.writeLine("custName=\"\"")
 
 
   cfgFile.writeLine("[furrybooru]")
   cfgFile.writeLine("uri=\"https://furry.booru.org/\"")
   cfgFile.writeLine("api=\"https://furry.booru.org/index.php?page=dapi&s=post&q=index&limit=10\"")
   cfgFile.writeLine("searchOpt=\"&pid=[i]&tags=[st]\"")
   cfgFile.writeLine("parseKey=\"file_url\"")
   cfgFile.writeLine("parseEle=\"post\"")
   cfgFile.writeLine("parseUriFix=\"[u]\"")
   cfgFile.writeLine("custName=\"\"")
 
   cfgFile.flushFile()
   cfgFile.close()
  else:
   error("Failed creating file:\n\t$1 ?" % getPath("profiles") )


proc clean*(prof: var NdlProfile) =
  prof.name = ""
  prof.uri = ""
  prof.api = ""
  prof.searchOpt = ""
  prof.parseKey = ""
  prof.parseEle = ""
  prof.parseUriFix = ""
  prof.custName = ""

proc loadProfile*(ndl: Ndl, profile: string = ""): bool =
  var pathProfiles = getPath("profiles")
  var fpProfiles = newFileStream(pathProfiles, fmRead)
  var loadProf = profile
  if loadProf == "":
    loadProf = "safebooru"
  if fpProfiles != nil:
    var cfgParser: CfgParser
    open(cfgParser, fpProfiles, pathProfiles)
    var event = next(cfgParser)
    ndl.prof.clean()

    while true:
      case event.kind
      of cfgEof:
        break
      of cfgSectionStart:
        if event.section == loadProf:
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
              of "custName":
                ndl.prof.custName = event.value
              else:
                discard
              event = next(cfgParser)
      of cfgError:
        error("$1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
      else:
        discard
      event = next(cfgParser)
    close(cfgParser)
    case ndl.prof.custName
    of "[n]", "":
      ndl.nameType = NntName
    of "[h]":
      ndl.nameType = NntHash
    of "[t]":
      ndl.nameType = NntTags
    else:
      ndl.nameType = NntCust
  else:
    createDefaultProfiles()
    result = ndl.loadProfile(loadProf)
  if not result:
    error("Couldn't load profile '$1' from file:\n\t$2" % [loadProf, getPath("profiles")])
  
