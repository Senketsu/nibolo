import os, parseopt, strutils, terminal
import asyncdispatch
import private/projTypes
import private/projUtils
import private/gui_gtk
import private/downloader

var
  channelMain: StringChannel
  channelDler: StringChannel
  threadMain: Thread[int]
  threadDler: Thread[int]
 
proc handleAbort() {.noconv.} =
  debug("Received Ctrl-C, aborting..")
  styledWriteLine(stdout, fgBlue, "[Info]: ", resetStyle, "Received Ctrl-C, exiting..")
  channelDler.send("NCQuit")

proc writeVersion() =
  styledWriteLine(stdout, fgGreen, LONGNAME, styleDim, " [$1] " % NAME, resetStyle, fgCyan, VERSION, resetStyle)
  echo("Copyright Senketsu (@Senketsu_Dev) [$1]" % LINK)
  var update = checkForUpdates()
  if update.available:
    styledWriteLine(stdout, fgYellow, "\tNewer version of $1 available: $2" %  [NAME, update.version], resetStyle)
  else:
    styledWriteLine(stdout, fgYellow, "\tYou are running newest version of $1: $2" % [NAME, update.version], resetStyle)

proc writeHelp() =
  styledWriteLine(stdout, fgGreen, "Usage: ", resetStyle, "$1 [options]:[value] .. [arguments]" % NAME)
  echo("  Running nibolo without any arguments or options will launch the GUI version.")
  styledWriteLine(stdout, fgCyan, "\nOptions:", resetStyle)
  echo("  -h, --help\t\t Shows this help screen.")
  echo("  -v, --version\t\t Will print version information including the newest version available.")
  echo("  -p, --profile\t\t Specify profile to use. Defaults to 'safebooru'.")
  echo("  -f, --folder\t\t Specify full path to folder in which save downloaded files. Defaults to home !")
  echo("  -t, --tags\t\t Specify search tags. One / multiple separated by space or none.")
  echo("  -d, --delay\t\t Whether to use slow mode. (Puts 3 second pause between requests).")
  styledWriteLine(stdout, fgCyan, "\nExample: ", resetStyle)
  styledWriteLine(stdout, fgYellow, "\t$1 -p='gelbooru' -df:\"/home/senketsu/Pics\" --tags='ass thighs 1boy'" % NAME, resetStyle)
  echo("  This will launch search for those 3 tags specified on gelbooru with additional")
  echo("  pauses between download requests and saves files into specified folder.")
  styledWriteLine(stdout, styleDim, "\nThis is free software, see LICENSE file for licensing information.", resetStyle)
  styledWriteLine(stdout, styleDim, "Copyright Senketsu [@Senketsu_Dev] [$1]\n" % LINK, resetStyle)


proc threadDlerStart(threadID: int) {.thread.} =
  projUtils.createLoggers()
  notice("Thread: worker initializing..")
  var ndl = downloader.new(channelDler.addr, channelMain.addr)
  ndl.idle()
  channelMain.send("Quit")
  debug("End of thread worker")

proc threadMainStart(threadID: int) {.thread.} =
  projUtils.createLoggers()
  notice("Thread: gui initializing..")
  let chanMain = channelMain.addr
  let chanDler = channelDler.addr
  gui_gtk.createMainWin(chanMain, chanDler)
  debug("End of thread main")

proc launch() =
  var iArgs: int = paramCount()
  if not checkDirectories():
    quit()

  if not fileExists(getPath("profiles")):
    createDefaultProfiles()
  
  projUtils.createLoggers()
  if iArgs > 0:
    # Open channel to queue up commands
    setControlCHook(handleAbort)
    addQuitProc(resetAttributes)
    channelDler.open()
    channelMain.open()
    for kind, key, val in getopt():
      case kind
      of cmdArgument:
        debug("Argument: $1" % $key)
      of cmdLongOption, cmdShortOption:
        debug("Option: '$1' Value: '$2'" % [key, val])
        case key
        of "version", "v":
          writeVersion()
          return
        of "help", "h":
          writeHelp()
          return
        of "profile", "p":
          channelDler.send("NCProfile $1" % val)
        of "folder", "f":
          channelDler.send("NCSaveFol $1" % val)
        of "tags", "t":
          channelDler.send("NCNewTags $1" % val)
        of "delay", "d":
          channelDler.send("NCOptSlow true")
        else:
          warn("Unknown option '$1'" % key)
      of cmdEnd:
        discard
    
    channelDler.send("NCStart")
    var ndl = downloader.new(channelDler.addr, channelMain.addr)
    ndl.idle()
  else:
    channelMain.open()
    channelDler.open()
    
    createThread(threadMain, threadMainStart, 0)
    createThread(threadDler, threadDlerStart, 1)
    joinThreads(threadMain, threadDler)

    channelMain.close()
    channelDler.close()

when isMainModule: nibolo.launch()
