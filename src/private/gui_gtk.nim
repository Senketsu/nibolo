import os, strutils
import gtk2, glib2, gdk2pixbuf
import projTypes
import projUtils

var
  winMain*: gtk2.PWindow
  chanDler*: ptr StringChannel
  chanMain*: ptr StringChannel
  enTags: PEntry
  imMain: PPixbuf
  pwMain: PImage
  sbProg, sbInfo: PStatusbar
  isBrowsing, imgReady: bool 
  
 
proc destroy(widget: PWidget, data: Pgpointer) {.cdecl.} =
  chanDler[].send("NCQuit")
  while gtk2.events_pending() > 0:
    discard gtk2.main_iteration()
  main_quit()

proc dlerStart(widget: PWidget, data: Pgpointer) =
  var tags = $get_text(enTags)
  if tags != "":
    chanDler[].send("NCNewTags $1" % tags)
    chanDler[].send("NCStart")
  
proc dlerStop(widget: PWidget, data: Pgpointer) =
  chanDler[].send("NCStop")

proc togglePreview(widget: PWidget, data: Pgpointer) =
  let
    btn = CHECK_BUTTON(widget)
    active = get_active(btn)
  chanDler[].send("NCOptView $1" % $active)

proc toggleSlowmode(widget: PWidget, data: Pgpointer) =
  let
    btn = CHECK_BUTTON(widget)
    active = get_active(btn)
  chanDler[].send("NCOptSlow $1" % $active)

proc toggleBrowser(widget: PWidget, data: Pgpointer) =
  let
    btn = CHECK_BUTTON(widget)
    active = get_active(btn)
  chanDler[].send("NCOptBrowse $1" % $active)

include filechooser

proc imbSave(widget: PWidget, data: Pgpointer) =
  if isBrowsing and imgReady:
    chanDler[].send("NCSave")

proc imbSaveAs(widget: PWidget, data: Pgpointer) =
  if isBrowsing and imgReady:
    let filePaths = winMain.pfcOpen(PfcSave)
    if filePaths != @[]:
      chanDler[].send("NCSaveAs $1" % filePaths[0])
  
proc imbNext(widget: PWidget, data: Pgpointer) =
  if isBrowsing and imgReady:
    chanDler[].send("NCNext")
    imgReady = false


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
      logEvent(true, "***Error: $1\n$2" % [getCurrentExceptionMsg(), repr getCurrentException()])
    case cmd
    of "pv":
      echo "do preview:'$1'" % args
      echo ""
      var pv = pixbuf_new_from_file_at_size(args, 360, 340, nil)
      pwMain.set_from_pixbuf(pv)
      imgReady = true
    else:
      discard

proc createMainWin*(channelMain, channelDler:  ptr StringChannel) =
  var
    label: PLabel
    hbFill: PHBox
  nim_init()
  winMain = window_new(gtk2.WINDOW_TOPLEVEL)
  winMain.set_position(WIN_POS_MOUSE)
  winMain.set_title(NAMEVER)
  winMain.set_default_size(300, 370)
  discard winMain.signal_connect("destroy", SIGNAL_FUNC(gui_gtk.destroy), nil)

  var vbMain = vbox_new(false, 2)
  vbMain.set_size_request(-1, -1)
  winMain.add(vbMain)
  label = label_new("Nibolo | $1" % [VERSION])
  vbMain.pack_start(label, false, false, 5)
  var hbMain = hbox_new(false, 0)
  vbMain.pack_start(hbMain, false, false, 0)

  var vbSec = vbox_new(false, 0)
  vbSec.set_size_request(280, -1)
  hbMain.pack_start(vbSec, false, false, 0)
  var vbPreview = vbox_new(false, 0)
  vbPreview.set_size_request(360, -1)
  hbMain.pack_start(vbPreview, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Source:")
  label.set_tooltip_text("Website which will be used to download from.")
  label.set_size_request(80, 30)
  hbFill.pack_start(label, false, false, 10)

  var cbProf = combo_box_text_new()
  cbProf.set_size_request(180, 30)
  cbProf.set_tooltip_text("List of available sites to download from.")
  hbFill.pack_start(cbProf, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Tags:")
  label.set_tooltip_text("Keywords used to search for images.")
  label.set_size_request(80, 30)
  hbFill.pack_start(label, false, false, 10)
  
  enTags = entry_new()
  enTags.set_size_request(180, 30)
  enTags.set_tooltip_text("Write in desired keyword(s) separated by space [e.g:'thighs 1boy']")
  hbFill.pack_start(enTags, false, false, 0)

  hbFill = hbox_new(false, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  label = label_new("Folder:")
  label.set_size_request(80, 30)
  label.set_tooltip_text("Folder used to save found images")
  hbFill.pack_start(label, false, false, 10)

  var btnChooser = button_new("Choose Folder")
  discard OBJECT(btnChooser).signal_connect("clicked",
   SIGNAL_FUNC(pfcStart), cast[pointer](PfcFolder))
  btnChooser.set_size_request(180, 30)
  btnChooser.set_tooltip_text("Pick folder where to save images.")
  hbFill.pack_start(btnChooser, false, false, 0)
  

  hbFill = hbox_new(true, 10)
  vbSec.pack_start(hbFill, false, false, 10)
  var btnStart = button_new("Start")
  discard OBJECT(btnStart).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.dlerStart), nil)
  btnStart.set_tooltip_text("Starts / Resumes downloading process..")
  hbFill.pack_start(btnStart, true, true, 0)
  
  var btnStop = button_new("Stop")
  discard OBJECT(btnStop).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.dlerStop), nil)
  btnStop.set_tooltip_text("Pauses / Aborts the downloading process..")
  hbFill.pack_start(btnStop, true, true, 0)

  sbInfo = statusbar_new()
  sbInfo.set_tooltip_text("Here you can see how it's going eh ?")
  vbSec.pack_start(sbInfo, false, false, 0)

  sbProg = statusbar_new()
  sbProg.set_tooltip_text("Here you can see the progress of your downloads.")
  vbSec.pack_start(sbProg, false, false, 0)
  
  var vbTest = vbox_new(false, 5)
  vbSec.pack_start(vbTest, false, false, 0)
  
  var btOptShow = check_button_new("Show image preview")
  discard OBJECT(btOptShow).signal_connect("toggled",
   SIGNAL_FUNC(gui_gtk.togglePreview), nil)
  btOptShow.set_tooltip_text("Whether to show a prieview of downloaded image.")
  vbTest.pack_start(btOptShow, false, false, 0)
  var btOptSlow = check_button_new("Slower request mode")
  discard OBJECT(btOptSlow).signal_connect("toggled",
   SIGNAL_FUNC(gui_gtk.toggleSlowmode), nil)
  btOptSlow.set_tooltip_text("Gives the server a room to breathe.")
  vbTest.pack_start(btOptSlow, false, false, 0)
  var btOptBrowse = check_button_new("Interactive mode")
  discard OBJECT(btOptBrowse).signal_connect("toggled",
   SIGNAL_FUNC(gui_gtk.toggleBrowser), btOptShow)
  btOptBrowse.set_tooltip_text("You can control the downloading process with buttons bellow.")
  vbTest.pack_start(btOptBrowse, false, false, 0)
  

  hbFill = hbox_new(true, 0)
  vbSec.pack_start(hbFill, false, false, 0)
  var btnSave = button_new_from_stock(STOCK_SAVE)
  discard OBJECT(btnSave).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.imbSave), nil)
  btnSave.set_tooltip_text("Saves image as is.")
  hbFill.pack_start(btnSave, true, true, 0)

  var btnSaveAs = button_new_from_stock(STOCK_SAVE_AS)
  discard OBJECT(btnSaveAs).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.imbSaveAs), nil)
  btnSaveAs.set_tooltip_text("Saves file with custom name..duh!")
  hbFill.pack_start(btnSaveAs, true, true, 0)

  var btnNext = button_new_from_stock(STOCK_MEDIA_NEXT)
  discard OBJECT(btnNext).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.imbNext), nil)
  btnNext.set_tooltip_text("Proceed to next image..")
  hbFill.pack_start(btnNext, true, true, 0)
  
  pwMain = image_new()
  pwMain.set_tooltip_text("The looking glass into your tastes..")
  # pwMain.set_size_request(90, 30)
  vbPreview.pack_start(pwMain, true, true, 0)


  var hboxBottom = hbox_new(false, 10)
  vbMain.pack_end(hboxBottom, false, false, 10)
  hboxBottom.set_size_request(-1, 30)

  var btnQuit = button_new("Quit")
  discard OBJECT(btnQuit).signal_connect("clicked",
   SIGNAL_FUNC(gui_gtk.destroy), nil)
  btnQuit.set_size_request(90, 30)
  hboxBottom.pack_end(btnQuit, false, false, 20)


  chanDler = channelDler
  chanMain = channelMain
  
  discard g_timeout_add(333, gui_gtk.update, nil)

  winMain.show_all()
  vbPreview.hide()
  main()


