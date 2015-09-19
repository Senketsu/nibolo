import os, strutils, parsecfg, streams, browsers
import net_fix/nib_httpC ,net_fix/nib_net
# import httpclient,net
import gtk2 , gdk2pixbuf , glib2  , dialogs
import nib_types , nib_cfg
from gdk2 import PRectangle,TRectangle
const
 VERSION = "v0.1.3"

var
 mainWin: PWindow
 enTags,pwMain: PWidget
 imMain: PPixbuf
 sbProgress,sbInfo: PStatusbar
 vmToggle,arToggle: PToggleButton
 cbFolder,bStart: PButton
 cbProf: PComboBoxText

 dirSaveTo,fpProfiles: string = ""
 profCount: int = 0
 pwW,pwH: gint = 0
 stopME,dontRapeME: bool = false
 viewMode,nextImg: bool = false
 chanSelf: ptr StringChannel
 chanDL: ptr StringChannel

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

proc isNewVersion(version: string,defSSLCont: SSLContext): bool =
 var
  respGet: Response
  httpCode,nextVer: string = ""
  gitUrl: string = "https://github.com/Senketsu/nibolo/releases/tag/"


 nextVer = getNextVersion(version)
 try:
  respGet = request( gitUrl & nextVer, httpHead,sslContext=defSSLCont)
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

proc updateWin(paths: TPaths,defSSLCont: SSLContext) =
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
   downloadFile( dlUrl ,fpNewVer,sslContext=defSSLCont)
  except:
   mainWin.error("Opps, failed to download Nibolo")
   return
 else:
  mainWin.info("Downloading canceled.")
  return

 mainWin.info("New installer downloaded")


proc updateNix(paths: TPaths,defSSLCont: SSLContext) =
 var
  nextVer = getNextVersion(VERSION)
  foldVer = nextVer
  fpMasterUrl = "https://github.com/Senketsu/nibolo/archive/"
  fpNewVer = joinPath(paths.dirCfg,"Nibolo_$1.zip" % [nextVer])
  homeDir: string = paths.dirHome
  userName: string = ""
  rv: int

 foldVer.delete(0,0)
 homeDir.delete(homeDir.len,homeDir.len)
 userName = homeDir
 userName.delete(0,rfind(userName,'/'))

 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

 try:
  downloadFile(fpMasterUrl & "$1.zip" % [nextVer] ,fpNewVer,sslContext=defSSLCont)
 except:
  mainWin.error("Opps, failed downloading Nibolo")

 rv = execShellCmd("unzip -o $1 -d $2" % [ fpNewVer, paths.dirCfg ])
 echo ($rv)
 if rv == 0:
  let pass = promptEntry("Enter sudo password for installation")
  if pass == "":
   mainWin.info("Installation canceled.")
   removeDir(joinPath(paths.dirCfg,"nibolo-$1" % [foldVer]))
   removeFile(fpNewVer)
   return
  else:
   rv = execShellCmd(" echo $1 | sudo -S $2 $3" % [pass,joinPath(paths.dirCfg,"nibolo-$1/install.sh"  % [foldVer]),userName])
   if rv == 0: # promt for restart
    removeDir(joinPath(paths.dirCfg,"nibolo-$1" % [foldVer]))
    removeFile(fpNewVer)
    if yesOrNo("Update successful ! Restart now ?"):
     discard execShellCmd("nibolo")
     quit()
    else:
     return
   else:
    mainWin.error("Download successful, installing failed..")
 else:
  mainWin.error("Extracting zip archive failed, please install unzip.")


proc updateCheck(paths: TPaths,arg: string) =
 when not defined(ssl):
  var defSSLCont: SSLContext = nil
 else:
  var defSSLCont = newContext(verifyMode = CVerifyNone)

 if isNewVersion(arg,defSSLCont):
  if yesOrNo("New version of Nibolo available ! Update ?"):
   when defined(Windows):
    paths.updateWin(defSSLCont)
   else:
    paths.updateNix(defSSLCont)
  else:
   discard push(sbProgress, 0, "New update available !")
 else:
  discard push(sbProgress, 0, "Your Nibolo is newest version.")

proc startGrab(widget: PWidget, data: Pgpointer)=
 var
  entryString,selProfile: string = ""
  chanBuff: string = ""
  imPreview: PPixbuf
  curFile: TSplitPath

 if get_active_text(cbProf) != nil:
  selProfile = $get_active_text(cbProf)

 entryString = $get_text(PEntry(enTags))

 if dirSaveTo == "" or entryString == "" or selProfile == "":
  mainWin.info("Please select profile, input tags and select folder to save into.")
  return
# TODO
 else:
  viewMode = get_active(vmToggle)
  dontRapeME = get_active(arToggle)

  chanDL[].send("saveTo $1" % dirSaveTo)
  chanDL[].send("tags $1" % entryString)
  chanDL[].send("profile $1" % selProfile)
  chanDL[].send("viewMode $1" % [if viewMode: "true" else: "false"])
  chanDL[].send("antiRape $1" % [if dontRapeME: "true" else: "false"])
  chanDL[].send("startGrab")
  set_relief(bStart,RELIEF_NONE)

  while true:
     let chanTryBuff = chanSelf[].tryRecv()
     if chanTryBuff.dataAvailable:
      chanBuff = chanTryBuff.msg

      if chanBuff.startsWith("newPreview"):
       chanBuff.delete(0,10)
       imPreview = pixbuf_new_from_file_at_size(chanBuff, pwW,pwH,nil)
       set_from_pixbuf(PImage(pwMain),imPreview)
       nextImg = true

       curFile = splitFile(chanBuff)
       discard push(sbProgress, 0, "File($1): $2" % [curFile.ext,curFile.name])

      elif chanBuff.startsWith("sbInfo"):
       chanBuff.delete(0,6)
       discard push(sbInfo, 0, chanBuff)

      elif chanBuff.startsWith("sbProg"):
       chanBuff.delete(0,6)
       discard push(sbProgress, 0, chanBuff)

      elif chanBuff.startsWith("***"):
       mainWin.error(chanBuff)

      else:
       echo ("Unknow command (startGrab) '$1'" % chanBuff)

     while gtk2.events_pending () > 0:
      discard gtk2.main_iteration()

     let mode = get_active(vmToggle)
     let rape = get_active(arToggle)

     if mode != viewMode:
      viewMode = mode
      chanDL[].send("viewMode $1" % [if viewMode: "true" else: "false"])
     if rape != dontRapeMe:
      dontRapeMe = rape
      chanDL[].send("antiRape $1" % [if dontRapeME: "true" else: "false"])


     if stopMe == true:
      break
     if not chanTryBuff.dataAvailable and not viewMode:
      sleep(1000)
     if not chanTryBuff.dataAvailable and viewMode:
      sleep(500)
  # cleanup

  set_from_pixbuf(PImage(pwMain),imMain)
  set_relief(bStart,RELIEF_HALF)
  nextImg = false
  stopMe = false
  discard push(sbInfo, 1, "Status: Idle...")
  # discard push(sbProgress, 1, "")
  # set_from_pixbuf(PImage(pwMain),imMain)

proc stopGrab(widget: PWidget, data: Pgpointer) =

 chanDL[].send("stopGrab")
 stopMe = true
 nextImg = false


proc vmSaveImgAs(widget: PWidget, data: Pgpointer) =
 if viewMode == false or nextImg == false:
  return

 let newPath = mainWin.chooseFileToSave(dirSaveTo)
 if newPath == "":
  return
 else:
  chanDL[].send("imgSaveAs $1" % newPath)
  nextImg = false

proc vmSaveImg(widget: PWidget, data: Pgpointer) =
 if viewMode == false or nextImg == false:
  return

 chanDL[].send("imgSave")
 nextImg = false

proc vmNextImg(widget: PWidget, data: Pgpointer) =
 if viewMode == false or nextImg == false:
  return

 chanDL[].send("imgNext")
 nextImg = false

## On some systems the ´allocation´ argument given by gtk is useless
proc pwMainGetSize(widget: PWidget,  allocation: PRectangle) =

 pwW = pwMain.allocation.width
 pwH = pwMain.allocation.height

proc chooseFolder(widget: PWidget, data: Pgpointer) =
 var
  getPath,folderName: string = ""

 getPath = mainWin.chooseDir()
 if getPath != "" and getPath != nil:
  folderName = getPath
  when defined(Windows):
   folderName.delete(0,rfind(folderName, '\\'))
  else:
   folderName.delete(0,rfind(folderName, '/'))
  set_label(cbFolder,folderName)
  set_tooltip_text(cbFolder,getPath)
  dirSaveTo = getPath
  chanDL[].send("saveTo $1" % dirSaveTo)

proc guiFillProfilesBox(pathProf: string,profBut: PComboBoxText) =
 var
  fileStream = newFileStream(pathProf, fmRead)
  index: int = 0

 for i in countUp(0,profCount):
  profBut.remove(gint(0))

 if fileStream != nil:
  var cfgParser: CfgParser
  open(cfgParser, fileStream, pathProf)
  while true:
    var
     event = next(cfgParser)
    case event.kind
    of cfgEof:
      break
    of cfgSectionStart:
     profBut.insert_text(gint(index),event.section)
     inc(index)
    of cfgError:
     mainWin.error(event.msg)
    else: discard
  close(cfgParser)
  profCount = index

proc downloadProfiles(widget: PWidget, data: Pgpointer) =
 let tempProf = joinPath(getTempDir(),"profiles.ini")
 let fpProfiles = joinPath(joinPath(getConfigDir(),"nibolo"),"profiles.ini")
 when not defined(ssl):
  var defSSLCont: SSLContext = nil
 else:
  var defSSLCont = newContext(verifyMode = CVerifyNone)

 try:
  downloadFile("https://raw.githubusercontent.com/Senketsu/nibolo/master/data/profiles.ini",
   tempProf,sslContext=defSSLCont)
  copyFile(tempProf,fpProfiles)
  guiFillProfilesBox(fpProfiles,cbProf)
  discard push(sbProgress, 0, "Your profiles have been updated.")
 except:
  mainWin.error("Failed to fetch profiles.ini from github")

proc promptResetProfiles(widget: PWidget, data: Pgpointer) =
 if yesOrNo("Do you want to reset your profiles.ini ?"):
  let fpProfiles = joinPath(joinPath(getConfigDir(),"nibolo"),"profiles.ini")

  if fpProfiles.createDefaultProfiles():
   fpProfiles.guiFillProfilesBox(cbProf)
   discard push(sbProgress, 0, "Your profiles have been reset.")
  else:
   echo "err resetProfiles"
 else:
  discard

proc updateProfilesList(widget: PWidget, data: Pgpointer) =
 let fpProfiles = joinPath(joinPath(getConfigDir(),"nibolo"),"profiles.ini")
 fpProfiles.guiFillProfilesBox(cbProf)

proc editProfiles(widget: PWidget, data: Pgpointer) =
 let fpProfiles = joinPath(joinPath(getConfigDir(),"nibolo"),"profiles.ini")
 echo fpProfiles
 openDefaultBrowser(fpProfiles)

proc guiDestroy(widget: PWidget, data: Pgpointer) {.cdecl.} =

 chanDL[].send("quit")
 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()
 main_quit()

proc guiStartUp* (paths: TPaths,nibCtrl: TControl,
                   chanGui,chanDler: ptr StringChannel) =

 var
  vbMain,hbMain,vbSec1,vbSec2,hbFill: PWidget
  bStop,bQuit,bProfEdit,bProfReset,bProfUpdate,bProfDl: PButton
  bSaveImg,bSaveImgAs,bNextImg: PButton
  labDummy: PLabel

 chanSelf = chanGui
 chanDL = chanDler

 nimrod_init()
 mainWin = window_new(WINDOW_TOPLEVEL)
 mainWin.set_position(WIN_POS_MOUSE)
 mainWin.set_title("Nibolo")
 mainWin.set_default_size(700,400)
 discard signal_connect(mainWin, "destroy", SIGNAL_FUNC(nib_gui.guiDestroy), nil)

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
 discard signal_connect(cbFolder, "clicked", SIGNAL_FUNC(nib_gui.chooseFolder), nil)
 pack_start(BOX(hbFill), cbFolder, true, true, 0)

 hbFill = hbox_new(true,0)
 pack_start(BOX(vbSec1), hbFill, false,false,0)

 bStart = button_new("Start")
 set_tooltip_text(bStart,"Start fetching images")
 discard signal_connect(bStart, "clicked", SIGNAL_FUNC(nib_gui.startGrab), nil)
 pack_start(BOX(hbFill), bStart, true, true, 0)
 bStop = button_new("Stop")
 set_tooltip_text(bStop,"Stop fetching images")
 discard signal_connect(bStop, "clicked", SIGNAL_FUNC(nib_gui.stopGrab), nil)
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

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false, false, 0)

 vmToggle = toggle_button_new("View mode")
 set_tooltip_text(vmToggle,"Browse trough your search and pick images to save manualy")
 pack_start(BOX(hbFill), vmToggle, false, false, 0)

 arToggle = toggle_button_new("Anti Rape")
 set_tooltip_text(arToggle,"Add small pause (1.5s) between downloads to not overload servers.")
 pack_start(BOX(hbFill), arToggle, false, false, 0)

 hbFill = hbox_new(false,0)
 pack_start(BOX(vbSec1), hbFill, false, false, 0)

 bSaveImg = button_new_from_stock(STOCK_SAVE)
 set_tooltip_text(bSaveImg,"Save Image (View Mode)")
 discard signal_connect(bSaveImg, "clicked", SIGNAL_FUNC(nib_gui.vmSaveImg), nil)
 pack_start(BOX(hbFill), bSaveImg, false, false, 0);

 bSaveImgAs = button_new_from_stock(STOCK_SAVE_AS)
 set_tooltip_text(bSaveImgAs,"Save Image As (View Mode)")
 discard signal_connect(bSaveImgAs, "clicked", SIGNAL_FUNC(nib_gui.vmSaveImgAs), nil)
 pack_start(BOX(hbFill), bSaveImgAs, false, false, 0);

 bNextImg = button_new_from_stock(STOCK_MEDIA_NEXT)
 set_tooltip_text(bNextImg,"Next Image (View Mode)")
 discard signal_connect(bNextImg, "clicked", SIGNAL_FUNC(nib_gui.vmNextImg), nil)
 pack_start(BOX(hbFill), bNextImg, false, true, 0);

 # right side
 vbSec2 = vbox_new(false,0)
 pack_start(BOX(hbMain), vbSec2, true,true,0)

 pwMain = image_new()
 set_tooltip_text(pwMain,"The ultimate donuts loving goddess !")
 discard signal_connect(pwMain, "size-allocate", SIGNAL_FUNC(nib_gui.pwMainGetSize), nil)
 pack_start(BOX(vbSec2), pwMain, true, true, 0)

 hbFill = hbox_new(false,2)
 pack_end(BOX(vbSec2), hbFill, false, false, 0)

 bQuit = button_new("Quit")
 set_tooltip_text(bQuit,"Quit Nibolo")
 discard signal_connect(bQuit, "clicked", SIGNAL_FUNC(nib_gui.guiDestroy), nil)
 pack_end(PBox(hbFill), bQuit, true, false, 0)

 bProfDl = button_new("DL Profiles")
 set_tooltip_text(bProfDl,"Downloads Profiles.ini from nib_gui.github page...")
 discard signal_connect(bProfDl, "clicked", SIGNAL_FUNC(nib_gui.downloadProfiles),nil)
 pack_start(PBox(hbFill), bProfDl, true, false, 0)

 bProfUpdate = button_new("Refresh 'source'")
 set_tooltip_text(bProfUpdate,"Refresh source list")
 discard signal_connect(bProfUpdate, "clicked",
  SIGNAL_FUNC(nib_gui.updateProfilesList), nil)
 pack_end(PBox(hbFill), bProfUpdate, true, false, 0)

 bProfEdit = button_new("Edit Profiles")
 set_tooltip_text(bProfEdit,"Opens your default editor.. maybe")
 discard signal_connect(bProfEdit, "clicked", SIGNAL_FUNC(nib_gui.editProfiles),nil)
 pack_end(PBox(hbFill), bProfEdit, true, false, 0)

 bProfReset = button_new("Reset Profiles")
 set_tooltip_text(bProfReset,"Resets your Profiles.ini...")
 discard signal_connect(bProfReset, "clicked",
  SIGNAL_FUNC(nib_gui.promptResetProfiles), nil)
 pack_start(PBox(hbFill), bProfReset, true, false, 0)

 paths.fpProfiles.guiFillProfilesBox(cbProf)
 mainWin.show_all()

 echo "$1x$2" % [$pwW,$pwH]
 if existsFile(paths.fpPicMain):
  imMain = pixbuf_new_from_file_at_size(paths.fpPicMain, pwW, pwH,nil)
  set_from_pixbuf(PImage(pwMain),imMain)

 while gtk2.events_pending () > 0:
  discard gtk2.main_iteration()

 when defined(ssl):
  paths.updateCheck(VERSION)

 main()
