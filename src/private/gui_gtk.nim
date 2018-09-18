import os, strutils, streams, parsecfg
import gtk2, glib2, gdk2pixbuf
from gdk2 import PRectangle
import projTypes
import projUtils

var
  winMain: gtk2.PWindow
  chanDler: ptr StringChannel
  chanMain: ptr StringChannel
  enTags: PEntry
  pwMain: PImage
  pwW, pwH: gint
  sbProg, sbInfo: PStatusbar
  btnStart, btnStop, btnChooser: PButton
  imgReady: bool
  ndlStatus: NdlStatus = NdlStopped
  cbProf: PComboBoxText
  btOptShow,btOptSlow,btOptBrowse: PCheckButton
 
proc quit() =
  while gtk2.events_pending() > 0:
    discard gtk2.main_iteration()
  main_quit()

proc requestQuit(widget: PWidget, data: Pgpointer) {.cdecl.} =
  chanDler[].send("NCQuit")

proc versionCheck() =
  chanDler[].send("NCCheckUpdates")

proc dlerStart(widget: PWidget, data: Pgpointer) =
  if ndlStatus == NdlStopped:
    var tags = $get_text(enTags)
    if tags != nil:
      chanDler[].send("NCNewTags $1" % tags)
  chanDler[].send("NCStart")
  
proc dlerStop(widget: PWidget, data: Pgpointer) =
  chanDler[].send("NCStop")

proc togglePreview(widget: PWidget, data: Pgpointer) =
  let active = get_active(btOptShow)
  chanDler[].send("NCOptView $1" % $active)

proc toggleSlowmode(widget: PWidget, data: Pgpointer) =
  let active = get_active(btOptSlow)
  chanDler[].send("NCOptSlow $1" % $active)

proc toggleBrowser(widget: PWidget, data: Pgpointer) =
  let active = get_active(btOptBrowse)
  chanDler[].send("NCOptBrowse $1" % $active)

include filechooser

proc chooseFolder(widget: PWidget, data: Pgpointer) =
  let paths = winMain.pfcOpen(PfcFolder)
  if paths != @[]:
    var spPath = splitPath(paths[0])
    btnChooser.set_label(spPath[1])
    btnChooser.set_tooltip_text(paths[0])
    chanDler[].send("NCSaveFol $1" % paths[0])

proc imbSave(widget: PWidget, data: Pgpointer) =
  if imgReady:
    chanDler[].send("NCSave")
    imgReady = false

proc imbSaveAs(widget: PWidget, data: Pgpointer) =
  if imgReady:
    let filePaths = winMain.pfcOpen(PfcSave)
    if filePaths != @[]:
      chanDler[].send("NCSaveAs $1" % filePaths[0])
      imgReady = false
  
proc imbNext(widget: PWidget, data: Pgpointer) =
  if imgReady:
    chanDler[].send("NCNext")
    imgReady = false

proc getProfileNames*(): seq[string] =
  result = @[]
  var pathProfiles = getPath("profiles")
  var fpProfiles = newFileStream(pathProfiles, fmRead)
  if fpProfiles != nil:
    var cfgParser: CfgParser
    open(cfgParser, fpProfiles, pathProfiles)
    var event = next(cfgParser)

    while true:
      case event.kind
      of cfgEof:
        break
      of cfgSectionStart:
        result.add(event.section)
      of cfgError:
        error("$1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
      else:
        discard
      event = next(cfgParser)
    close(cfgParser)

proc changedProfile(widget: PComboBox, data: gpointer) =
  var active = $get_active_text(cbProf)
  if active != "" or active != nil:
    chanDler[].send("NCProfile $1" % active)
  
proc fillProfiles(cb: PComboBoxText) =
  var profiles = getProfileNames()
  for i in 0..profiles.high:
    cbProf.insert_text(gint(i), profiles[i])
  set_active(PComboBox(cbProf), gint(0))

proc getWidgetDimension(widget: PWidget, allocation: PRectangle) =
  pwW = pwMain.allocation.width
  pwH = pwMain.allocation.height

proc update*(data: gpointer): bool =
  result = true
  var buff = chanMain[].tryRecv()
  if buff.dataAvailable:
    var
      cmd = buff.msg
      args = ""
    try:
      var splitCMD = buff.msg.split(" ")
      for i in 0..splitCMD.high:
        if i == 0: cmd = splitCMD[i]
        if i > 0:
          args.add(splitCMD[i])
          args.add(" ")
      args.delete(args.len, args.len)
    except:
      error("$1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
    case cmd
    of "pv":
      var pv = pixbuf_new_from_file_at_size(args, pwW, pwH, nil)
      pwMain.set_from_pixbuf(pv)
      if pv != nil:
        g_object_unref(pv)
      imgReady = true
    of "NdlRunning":
      ndlStatus = NdlRunning
      btnStart.set_relief(RELIEF_HALF)
      btnStart.set_label("Pause")
    of "NdlPaused":
      ndlStatus = NdlPaused
      btnStart.set_relief(RELIEF_HALF)
      btnStart.set_label("Resume")
    of "NdlStopped":
      ndlStatus = NdlStopped
      btnStart.set_relief(RELIEF_NORMAL)
      btnStart.set_label("Start")
    of "NdlQuit":
      ndlStatus = NdlQuit
      quit(0)
    of "UpdatePrompt":
      let msg = "Nibolo $1 has been released.\n\t(Your version: $2)" % [args, VERSION]
      infoUser(winMain, DlgINFO, "Update available !", msg)
    of "smsg":
      discard sbInfo.push(0,"\tInfo:\t $1" % args)
    of "pmsg":
      discard sbProg.push(0,"\tStats:\t $1" % args)
    of "ERR":
      infoUser(winMain, DlgERR, "Error !", args)
    else:
      discard


proc createMainWin*(channelMain, channelDler:  ptr StringChannel) =
  var
    label: PLabel
    hbFill: PHBox
  nim_init()
  winMain = window_new(gtk2.WINDOW_TOPLEVEL)
  winMain.set_position(WIN_POS_MOUSE)
  winMain.set_title(NAME)
  winMain.set_default_size(640, 370)
  discard winMain.g_signal_connect("destroy", G_CALLBACK(gui_gtk.requestQuit), nil)

  var vbMain = vbox_new(false, 2)
  winMain.add(vbMain)
  label = label_new("Nibolo $1" % [VERSION])
  vbMain.pack_start(label, false, false, 5)
  var hbMain = hbox_new(false, 0)
  vbMain.pack_start(hbMain, true, true, 0)

  var vbSec = vbox_new(false, 0)
  hbMain.pack_start(vbSec, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Source:")
  label.set_tooltip_text("Website which will be used to download from.")
  label.set_size_request(100, -1)
  hbFill.pack_start(label, false, false, 10)

  cbProf = combo_box_text_new()
  cbProf.set_size_request(200, -1)
  cbProf.set_tooltip_text("List of available sites to download from.")
  discard OBJECT(cbProf).g_signal_connect("changed",
   G_CALLBACK(gui_gtk.changedProfile), nil)
  hbFill.pack_start(cbProf, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Tags:")
  label.set_tooltip_text("Keywords used to search for images.")
  label.set_size_request(100, -1)
  hbFill.pack_start(label, false, false, 10)
  
  enTags = entry_new()
  enTags.set_size_request(200, -1)
  enTags.set_tooltip_text("Write in desired keyword(s) separated by space [e.g:'thighs 1boy']")
  hbFill.pack_start(enTags, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Folder:")
  label.set_size_request(100, -1)
  label.set_tooltip_text("Folder used to save found images")
  hbFill.pack_start(label, false, false, 10)

  btnChooser = button_new("Choose Folder")
  discard OBJECT(btnChooser).g_signal_connect("clicked",
   G_CALLBACK(chooseFolder), nil)
  btnChooser.set_size_request(200, -1)
  btnChooser.set_tooltip_text("Pick folder where to save images.")
  hbFill.pack_start(btnChooser, false, false, 0)
  
  hbFill = hbox_new(true, 10)
  vbSec.pack_start(hbFill, false, false, 10)
  btnStart = button_new("Start")
  discard OBJECT(btnStart).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.dlerStart), nil)
  btnStart.set_tooltip_text("Starts / Pauses / Resumes downloading process..")
  hbFill.pack_start(btnStart, true, true, 0)
  
  btnStop = button_new("Stop")
  discard OBJECT(btnStop).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.dlerStop), nil)
  btnStop.set_tooltip_text("Stops the downloading process..")
  hbFill.pack_start(btnStop, true, true, 0)

  sbInfo = statusbar_new()
  sbInfo.set_tooltip_text("Here you can see the status of nibolo..")
  vbSec.pack_start(sbInfo, false, true, 10)
  
  sbProg = statusbar_new()
  sbProg.set_tooltip_text("Here you can see the progress of your downloads and other information.")
  vbSec.pack_start(sbProg, false, false, 10)
  
  var vbTest = vbox_new(false, 5)
  vbSec.pack_start(vbTest, false, false, 0)
  
  btOptShow = check_button_new("Show image preview")
  discard OBJECT(btOptShow).g_signal_connect("toggled",
   G_CALLBACK(gui_gtk.togglePreview), nil)
  btOptShow.set_tooltip_text("Whether to show a prieview of downloaded image.")
  vbTest.pack_start(btOptShow, false, false, 0)
  btOptSlow = check_button_new("Slower request mode")
  discard OBJECT(btOptSlow).g_signal_connect("toggled",
   G_CALLBACK(gui_gtk.toggleSlowmode), nil)
  btOptSlow.set_tooltip_text("Gives the server a room to breathe.")
  vbTest.pack_start(btOptSlow, false, false, 0)
  btOptBrowse = check_button_new("Interactive mode")
  discard OBJECT(btOptBrowse).g_signal_connect("toggled",
   G_CALLBACK(gui_gtk.toggleBrowser), btOptShow)
  btOptBrowse.set_tooltip_text("You can control the downloading process with buttons bellow.")
  vbTest.pack_start(btOptBrowse, false, false, 0)
  
  hbFill = hbox_new(true, 0)
  vbSec.pack_start(hbFill, false, false, 20)
  var btnSave = button_new_from_stock(STOCK_SAVE)
  discard OBJECT(btnSave).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.imbSave), nil)
  btnSave.set_tooltip_text("Saves file as is.")
  hbFill.pack_start(btnSave, true, true, 0)

  var btnSaveAs = button_new_from_stock(STOCK_SAVE_AS)
  discard OBJECT(btnSaveAs).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.imbSaveAs), nil)
  btnSaveAs.set_tooltip_text("Saves file with custom name..duh!")
  hbFill.pack_start(btnSaveAs, true, true, 0)

  var btnNext = button_new_from_stock(STOCK_MEDIA_NEXT)
  discard OBJECT(btnNext).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.imbNext), nil)
  btnNext.set_tooltip_text("Skip to next image..")
  hbFill.pack_start(btnNext, true, true, 0)
  
  pwMain = image_new()
  pwMain.set_tooltip_text("The looking glass into your tastes..")
  discard pwMain.g_signal_connect("size-allocate",
    G_CALLBACK(gui_gtk.getWidgetDimension), nil)
  hbMain.pack_start(pwMain, true, true, 0)

  var hboxBottom = hbox_new(false, 10)
  vbMain.pack_end(hboxBottom, false, false, 10)
  hboxBottom.set_size_request(-1, 30)

  var btnQuit = button_new("Quit")
  discard OBJECT(btnQuit).g_signal_connect("clicked",
   G_CALLBACK(gui_gtk.requestQuit), nil)
  btnQuit.set_size_request(90, 30)
  hboxBottom.pack_end(btnQuit, false, false, 20)

  chanDler = channelDler
  chanMain = channelMain
  gui_gtk.versionCheck()
  discard g_timeout_add(333, gui_gtk.update, nil)
  
  cbProf.fillProfiles()
  winMain.show_all()
  main()


