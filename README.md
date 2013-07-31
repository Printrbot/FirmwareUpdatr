FirmwareUpdatr
==============

Printrbot Firmware Updater for Mac OS X

**NOTE:** If you just want the pre-built app, get it from http://www.printrbottalk.com/wiki/index.php?title=User:PxT


Build Requirements:
  * Platypus: http://sveinbjorn.org/platypus<br>
  Install the GUI app and also the command-line tool (from within the app's Preferences window)

  * cocoaDialog: http://mstratman.github.io/cocoadialog/<br>
  This must be installed in /Applications, a copy will be bundled into the finished app

  * dfu-programmer: http://dfu-programmer.sourceforge.net<br>
  A copy is provided along with this script and will be bundled into the finished app

  * Xcode command line tools (make, gcc, etc.):  https://developer.apple.com/xcode/

Build Process:
  * Build the dfu-programmer binary and libraries:<br>
     cd dfu ; ./build.sh
  * Edit the build-firmware-app.sh script if necessary to adjust the version number and path to your dfu files
  * ./build-firmware-app.sh<br>
  The app will be built and written into the current directory

