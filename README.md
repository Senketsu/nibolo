# **nibolo - Nim Booru Loader**
## Current version 0.1.4
### Why are we still here ?
------------------------
### About nibolo
A little old crappy tool revived because I don't value my time enough..

### Features:
------------------------
* Download images from boorus
* Preview of downloaded images
* Manual mode - for the picky ones
* Update check

### Compiling:
------------------------
Make sure you have the gtk2 wrappers installed by nimble:  
`nimble install gtk2`  
Compile with:  
`nim c --threads:on -d:ssl -d:release nibolo.nim`  
On Windows you might want to add `--app:gui` to hide console.  

### Runtime depends:
------------------------
You will need GTK2 runtime library and Open SSL  
  
**Linux**  
Use your distros package manager to install gtk2 and/or openssl.  
**Windows**  
*Note: you can alternatively use [MSYS2](http://www.msys2.org/) to install gtk runtime* 
* **32bit** [GTK2 Runtime 32bit](http://downloads.sourceforge.net/gtk-win/gtk2-runtime-2.24.10-2012-10-10-ash.exe?download)
* **64bit** [GTK2 Runtime 64bit](https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases)
* **OpenSSL** is packed in every installer of nibolo or can be downloaded from [Nim](https://nim-lang.org/install_windows.html)'s website