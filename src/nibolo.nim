import os
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

proc threadDlerStart(threadID: int) {.thread.} =
  echoInfo("Downloader\t- initializing..")
  var ndl = downloader.new(channelDler.addr, channelMain.addr)
  ndl.idle()
  channelMain.send("Quit")
  echoInfo("Debug: End of thread dler")

proc threadMainStart(threadID: int) {.thread.} =
  echoInfo("Nibolo gui\t- initializing..")
  let chanMain = channelMain.addr
  let chanDler = channelDler.addr
  gui_gtk.createMainWin(chanMain, chanDler)
  echoInfo("Debug: End of thread main")

proc launch() =
  echoInfo("\t*** Nibolo starting***")
  if not checkDirectories():
    echoInfo("Quitting...")
    quit()

  if not fileExists(getPath("profiles")):
    createDefaultProfiles()
  
  channelMain.open()
  createThread(threadMain, threadMainStart, 0)

  channelDler.open()
  createThread(threadDler, threadDlerStart, 1)

  joinThreads(threadMain, threadDler)

  channelMain.close()
  channelDler.close()

when isMainModule: nibolo.launch()
