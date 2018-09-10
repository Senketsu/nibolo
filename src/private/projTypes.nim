type
  TDlgEnum* = enum
    DlgINFO = 0
    DlgWARN = 1
    DlgERR = 3
  
  PfcMode* = enum
    PfcSelect = (0, "select")
    PfcSave = (1, "save")
    PfcFolder = (2, "folder")

  StringChannel* = Channel[string]
  TSplitFile* = tuple
    dir,name,ext: string
  TLinkData* = tuple
    url,ext,name: string