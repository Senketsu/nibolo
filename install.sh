#!/bin/bash
path="$(dirname "$(realpath "$0")")";
username=$1
cd path
echo "Trying to compile 'nibolo' "
sudo -u $username nim c -d:ssl -d:release $path/src/nibolo.nim

echo "Installing files"
mkdir /usr/local/share/doc/nibolo
cp $path/src/nibolo /usr/local/bin/nibolo
cp $path/data/nibolo.png /usr/local/share/pixmaps/nibolo.png
cp $path/data/nibolo.desktop /usr/local/share/applications/nibolo.desktop
cp $path/LICENSE /usr/local/share/doc/nibolo/LICENSE
cp $path/README.md /usr/local/share/doc/nibolo/README.md
cp $path/ChangeLog /usr/local/share/doc/nibolo/ChangeLog

echo "Cleaning..."
rm -r ./src/nimcache
rm ./src/nibolo

echo "All done~"
