import os, strutils, streams , parsexml , parsecfg , browsers
import net_fix/nib_net , net_fix/nib_httpC
# import httpclient, net
import nib_types , nib_cfg ,nib_gui , nib_dler

var
 chanGui: StringChannel
 chanDler: StringChannel
 thrGui: Thread[int]
 thrDler: Thread[int]

proc dlerStartThread(thrID: int) {.thread.} =
 var
  paths: TPaths

 let chGui = chanGui.addr
 let chDler = chanDler.addr

 paths.setPaths()
 paths.dlerStartUp(chGui,chDler)


proc guiStartThread(thrID: int) {.thread.} =
 var
  paths: TPaths
  nibCtrl: TControl

 let chGui = chanGui.addr
 let chDler = chanDler.addr

 paths.setPaths()
 paths.guiStartUp(nibCtrl,chGui,chDler)


proc main() =

 chanGui.open()
 createThread(thrGui, guiStartThread, 0)

 chanDler.open()
 createThread(thrDler, dlerStartThread, 1)

 joinThreads(thrGui,thrDler)

 chanGui.close()
 chanDler.close()

when isMainModule: main()
