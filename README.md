# **nibolo - Nim Booru Loader**
## Current version 0.1.2
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
* 'Self updater' (*nix)

### Notes:
------------------------
* Currently due to Nim's limitations, threading is not possible within nibolo
*   Therefore expect nibolo's gui to be somewhat unresponsible at times
* The *profiles.ini* contains some explanation how to add more boorus
* Its very simple and most boorus have pretty much same patter.
* Sankaku Complex (IDOL) doesn't work (CHAN) Partially works
*   Reason is the response html is very shitty and parser breaks on it
* Small wiki article with guide how to add profiles will be added later

## Install:
------------------------
**Requirements for compiling/using**
* **Compiling** gtk2 wrapper (nimble install gtk2)
* **Runtime** gtk2 runtime libraries (use your package manager or for [Windows 32bit](http://downloads.sourceforge.net/gtk-win/gtk2-runtime-2.24.10-2012-10-10-ash.exe?download) or [Windows 64bit](http://lvserver.ugent.be/gtk-win64/gtk2-runtime/gtk2-runtime-2.24.25-2015-01-21-ts-win64.exe)
* **Runtime** openssl library
**(Windows installation is shipped with openssl dll's & only needs GTK runtime)**

### Linux
* Run install.sh with 'sudo' and pass 'username' as param
* e.g: **'sudo ./install.sh senketsu'**
* The username is needed for compiling without root privilage while installing does need it

### Windows
* Get gtk2 runtime libraries [Windows 32bit](http://www.gtk.org/download/) or [Windows 64bit](http://lvserver.ugent.be/gtk-win64/gtk2-runtime/gtk2-runtime-2.24.25-2015-01-21-ts-win64.exe)
* Download **Nibolo** from the [release](https://github.com/Senketsu/nibolo/releases) page
* Enjoy !

### Contact
* Feedback , thoughts , bug reports ?
* Feel free to contact me on [twitter](https://twitter.com/Senketsu_Dev) ,or visit [stormbit IRC network](https://kiwiirc.com/client/irc.stormbit.net/?nick=Guest|?#cute)
* Or create [issue](https://github.com/Senketsu/nibolo/issues) on Nibolo Github page.
