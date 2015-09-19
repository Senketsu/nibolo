# **nibolo - Nim Booru Loader**
## Current version 0.1.3
### Gotta view 'em all
------------------------
### About nibolo
A little afternoon project while waiting for a bug fix on Nim
Since i couldn't install the Boorupy_loadr and not felt like fu*king with python.
Had to satisfy my need for more oshino images.

### Features:
------------------------
* Download images from boorus
* Download images from chans
* Possibly from any image site
* Preview of downloaded images
* Anti server 'rape' toggle ( be nice and let the servers breath)
* View Mode - Preview images and choose which to download
* Update Check
* DL profiles from this repo
* 'Self updater' (*nix) __As of 0.1.3 might be not working , depending on your nim's devel executable name

### Notes:
------------------------
* **Due to nature of update 0.1.3, Nibolo is only compilable on the devel branch(0.11.3)**
* __Gui freezes can be noticable here and there, no better way to idle atm.__
* ~~Currently due to Nim's limitations, threading is not possible within nibolo~~
* ~~Therefore expect nibolo's gui to be somewhat unresponsible at times~~
* The *profiles.ini* contains some explanation how to add more boorus
      Its very simple and most boorus have pretty much same patter.
* Sankaku Complex (IDOL) doesn't work (CHAN) Partially works
      Reason is the response html is very shitty and parser breaks on it


## Install:
------------------------
### Windows
* Download **Nibolo** (***with_GTK2 recommended**)from the [release](https://github.com/Senketsu/nibolo/releases) page
* Enjoy !

### Notes:
**Any Nibolo's Windows installations are shipped with openssl dll's**
**Recommended to download Nibolo's Windows installation with all runtime requirements (*with_GTK2)**

### Linux
* Run install.sh with 'sudo' and pass 'username' as param
* e.g: **'sudo ./install.sh senketsu'**
* The username is needed for compiling without root privilage while installing does need it
* (0.1.3) - If your Nim's devel executable is named differently (e.g: nimdev) rename it in the install.sh or install it manualy as you see fit ;3


### Compiling Manualy:
------------------------
**Requirements for compiling manualy (Nibolo 0.1.2 or older)**
* GTK2 wrapper (nimble install gtk2) **if you compile on devel, 'dialogs' too**

**Requirements for compiling manualy (Nibolo 0.1.3)**
* Nim Compiler 0.11.3 (Currently devel branch)
* GTK2 wrapper & dialogs module (nimble install gtk2 | dialogs)

**Compile options**
* WIN: nim c --threads:on -d:ssl -d:release -d:nimOldDLLs --app:gui nibolo.nim
* NIX: nim c --threads:on -d:ssl -d:release nibolo.nim

### Runtime depends:
------------------------
**Requirements for using Nibolo (any version)**
* GTK2 runtime libraries
* **(Win):**  GTK2 Runtime Installations (not recommended) [Windows 32bit](http://downloads.sourceforge.net/gtk-win/gtk2-runtime-2.24.10-2012-10-10-ash.exe?download) or [Windows 64bit](http://lvserver.ugent.be/gtk-win64/gtk2-runtime/gtk2-runtime-2.24.25-2015-01-21-ts-win64.exe)
* OpenSSL library

### Contact
* Feedback , thoughts , bug reports ?
* Feel free to contact me on [twitter](https://twitter.com/Senketsu_Dev) ,or visit [stormbit IRC network](https://kiwiirc.com/client/irc.stormbit.net/?nick=Guest|?#Senketsu)
* Or create [issue](https://github.com/Senketsu/nibolo/issues) on Nibolo Github page.
