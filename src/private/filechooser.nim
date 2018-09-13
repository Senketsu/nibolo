proc yesOrNo*(window: PWindow, question: string): bool =
  let label = label_new(question)
  let ynDialog = dialog_new_with_buttons(question, window,
    DIALOG_DESTROY_WITH_PARENT, STOCK_NO, RESPONSE_NO,
    STOCK_YES, RESPONSE_YES,nil)
  ynDialog.vbox.pack_start(label, true, true, 30)
  ynDialog.show_all()

  if ynDialog.run() == RESPONSE_YES:
    result = true
  ynDialog.destroy()


proc infoUser*(window: PWindow, msgType: TDlgEnum, msg: string) =
  var dialog = message_dialog_new(window,
      DIALOG_MODAL or DIALOG_DESTROY_WITH_PARENT,
      cast[TMessageType](int(msgType)), BUTTONS_OK, "%s", cstring(msg))
  dialog.setTitle("Info")
  discard dialog.run()
  dialog.destroy()


proc pfcUpdate(widget: PWidget, data: Pgpointer) =
  var dialog = FILE_CHOOSER(widget)
  let pvPath = get_preview_filename(dialog)
  if pvPath == nil or pvPath == "":
    return

  var
    acceptTypes: seq[string] = @[".png", ".jpeg", ".jpg",
     ".jpe", ".bmp", ".tiff", ".tif", ".gif"]
    pvWidget = IMAGE(dialog.get_preview_widget())
    spFile: TSplitFile = splitFile($pvPath)

  for ext in acceptTypes:
    if ext == spFile.ext:
      if ext == ".gif":
        var pvImage = pixbuf_animation_new_from_file(pvPath, nil)
        pvWidget.set_from_animation(pvImage)
      else:
        var pvImage = pixbuf_new_from_file_at_size(pvPath, 224, -1, nil)
        pvWidget.set_from_pixbuf(pvImage)
      dialog.set_preview_widget_active(true)
      return
  dialog.set_preview_widget_active(false)


proc pfcCreateSelect(window: PWindow, curDir: string = ""): PFileChooser =
  var preview = image_new()
  preview.set_size_request(224, 224)

  var filterAll = file_filter_new()
  filterAll.add_pattern("*")
  filterAll.set_name("All files")
  var filterImg = file_filter_new()
  filterImg.add_mime_type("image/*")
  filterImg.set_name("Images")
  var filterAud = file_filter_new()
  filterAud.add_mime_type("audio/*")
  filterAud.set_name("Audio")
  var filterVid = file_filter_new()
  filterVid.add_mime_type("video/*")
  filterVid.set_name("Video")

  result = file_chooser_dialog_new("Upload file(s)", window,
    FILE_CHOOSER_ACTION_OPEN,
    "Cancel", RESPONSE_CANCEL,
    "Select", RESPONSE_ACCEPT, nil)
  discard result.set_current_folder_uri(getHomeDir())
  result.set_use_preview_label(false)
  result.add_filter(filterAll)
  result.add_filter(filterImg)
  result.add_filter(filterAud)
  result.add_filter(filterVid)
  result.set_select_multiple(true)
  result.set_preview_widget(preview)
  discard result.g_signal_connect("update-preview",
   G_CALLBACK(gui_gtk.pfcUpdate), nil)


proc pfcCreateFolder(window: PWindow, curDir: string = ""): PFileChooser =
  result = file_chooser_dialog_new("Select folder", window,
    FILE_CHOOSER_ACTION_SELECT_FOLDER,
    "Cancel", RESPONSE_CANCEL,
    "Select", RESPONSE_ACCEPT, nil)
  discard result.set_current_folder_uri(getHomeDir())

proc pfcCreateSave(window: PWindow, curDir: string = ""): PFileChooser =
  result = file_chooser_dialog_new("Save file as..", window,
    FILE_CHOOSER_ACTION_SAVE,
    "Cancel", RESPONSE_CANCEL,
    "Save", RESPONSE_ACCEPT, nil)
  discard result.set_current_folder_uri(getHomeDir())


proc pfcOpen*(window: PWindow, mode: PfcMode, root: string = ""): seq[string] =
  var dialog: PFileChooser
  case mode
  of PfcSelect:
    dialog = pfcCreateSelect(window)
  of PfcFolder:
    dialog = pfcCreateFolder(window)
  of PfcSave:
    dialog = pfcCreateSave(window)

  if root.len > 0:
    discard dialog.set_current_folder_uri(root)

  result = @[]
  if dialog.run() == cint(RESPONSE_ACCEPT):
    var uriList = dialog.get_filenames()
    while uriList != nil:
      result.add($cast[cstring](uriList.data))
      g_free(uriList.data)
      uriList = uriList.next
    free(uriList)
  dialog.destroy()

proc pfcStart*(widget: PWidget, data: Pgpointer){.procvar.} =
  var
    mode: PfcMode = cast[PfcMode](data)
  let filePaths = pfcOpen(WINDOW(nil), mode)
  if filePaths != @[]:
    case mode
    of PfcSelect:
      discard
    of PfcFolder:
      var spPath = splitPath(filePaths[0])
      BUTTON(widget).set_label(spPath[1])
      BUTTON(widget).set_tooltip_text(filePaths[0])
      chanDler[].send("NCSaveFol $1" % filePaths[0])
    of PfcSave:
      discard
    else: discard