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
**Requirements for compiling manualy**  
`nimble install gtk2`  
`nim c --threads:on -d:ssl -d:release nibolo.nim`  
On Windows you might want to add --app:gui to hide console when launching the gui.  

### Runtime depends:
------------------------
You will need GTK2 runtime library and Open SSL  
On most linux systems those two are probably already installed or you can use your package manager to install them.  
** Windows **  
For 32 bit, please use either msys to install your GTK 2 runtime or download nibolo with gtk packed inside.  
Any other runtime libraries are very likely either outdated or buggy af.  
For 64 bit, there is well maintained repository on github linked below where you can grab installers.  
* **32bit** [MSYS2](http://www.msys2.org/)
* **64bit** [GTK2 Runtime 64bit](https://github.com/tschoonj/GTK-for-Windows-Runtime-Environment-Installer/releases)
* **OpenSSL** is packed in every installer of nibolo