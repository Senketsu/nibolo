type
 TSplitPath* = tuple
  dir,name,ext: string
 TLinkData* = tuple
  url,ext,name: string
 TBooruProf* = tuple
  name,mUrl,sUrl,sUrlOpt1,sUrlOpt2,parEle,parUrl,parExt,parName,iMult,iBase,cookie: string
  repStr: array[0..3, array[0..1,string]]
 PBooruProf* = ref TBooruProf

 StringChannel* = Channel[string]

 TPaths* = tuple
  dirHome, dirCfg, dirTemp, fpResponse, fpProfiles, fpPicMain: string

 PPaths* = ref TPaths

 TControl* = tuple
  stopME,restartME,viewMode,dontRapeME: bool
