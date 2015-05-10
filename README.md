# **nibolo - Nim Booru Loader**
## Current version 0.1a
###
------------------------
### About nibolo
A little afternoon project while waiting for a bug fix on Nim
Since i couldn't install the Boorupy_loadr and not felt like fu*king with python.
Had to satisfy my need for more oshino images.

### Features:
------------------------
* Download images from boorus
* Download images from chans
* Who the hell knows ? Its first draft.

### Notes:
------------------------
The *profiles.ini* contains some explanation how to add more boorus
Its very simple and most boorus have pretty much same patter.
I don't know many boorus so the default list is pretty slim.
If you want booru added to defaults (or you can't manage to include some yourself) contact me on [twitter](https://twitter.com/Senketsu_Dev)
 (also contact me if you know some highly populated booru)
 (gotta fetch em all)
Sankaku Complex (IDOL) doesn't work (CHAN) Partially works
* Reason is the response html is very shitty and parser breaks on it
* **ssl** is only needed for sankaku, read below


### Install:
------------------------
**Requirements**
* gtk2 wrapper (nimble install gtk2)
* gtk2 runtime libraries (use your package manager to find one or for [windows](http://www.gtk.org/download/)
* **optional** openssl (leave out the compiler define -d:ssl)

[Linux]
Run install.sh with 'sudo' and pass 'username' as param
e.g: 'sudo ./install.sh senketsu'
The username is needed for compiling without root privilage while installing does need it

[Windows]
1st: Compile with 'nim c -d:ssl -d:release ./src/nibolo.nim'
(NOTE: again ssl is optional and is only required for Sankaku which is broken)
2nd: Get the gtk2 lib from link above (if you don't have yet)
3rd: Unpack somewhere and add it to your env variable PATH
  **OR** Unpack it to folder with nibolo.exe
Make shortcut on desktop duh.. i will provide installers later

### Contact
* Feedback , thoughts , bug reports ?
* Feel free to contact me on [twitter](https://twitter.com/Senketsu_Dev) ,or visit [stormbit IRC network](https://kiwiirc.com/client/irc.stormbit.net/?nick=Guest|?#cute)
* Or create [issue](https://github.com/Senketsu/nibolo/issues) on Nibolo Github page.
