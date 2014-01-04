#!/bin/sh

# This script will build the Mac OS X native app used to install firmware on a Printrbot
# Requirements:
#  * Platypus: http://sveinbjorn.org/platypus
#  Install the GUI app and also the command-line tool (from within the app's Preferences window)
#
#  * cocoaDialog: http://mstratman.github.io/cocoadialog/
#  This must be installed in /Applications, a copy will be bundled into the finished app
#
#  * dfu-programmer: http://dfu-programmer.sourceforge.net
#  A pre-built copy is provided along with this script and will be bundled into the finished app
#  Specify the location on your system in the PATH_TO_DFU variable below, this should be the
#  top-level directory which was given as a PREFIX to the 'make' command used to build dfu-programmer.
#  In other words it will contain bin/, lib/, etc. sub-directories
#

PATH_TO_DFU=./dfu/
VERSION="2.0"

if [ ! -e dfu/bin/dfu-programmer ]
then
    cd dfu
    ./build.sh
    cd ..
fi
cp myterm.py dfu/bin/
/usr/local/bin/platypus -P 'Printrbot Firmware Updater.platypus' -y -f $PATH_TO_DFU -V $VERSION 'Printrbot Firmware Updater.app'

