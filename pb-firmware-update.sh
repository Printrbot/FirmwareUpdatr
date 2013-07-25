#!/bin/sh 

PATH=/bin:/sbin:/usr/bin

CDL="CocoaDialog.app/Contents/MacOS/CocoaDialog"

tempfoo=`basename $0`
DL=`mktemp -q "/tmp/${tempfoo}.XXXXXX"`
if [ $? -ne 0 ]; then
	$CDL msgbox --icon hazard --text "Error" --informative-text "Can't create temp file" --button1 "Quit"
	exit 1
fi

trap on_exit EXIT

function on_exit() { 
	if [ -z "$1" ]
	then
		rm -f "$DL"
	fi

}

if [ ! -z "$1" ]
then
	# A file was dropped on the app icon
	trap - EXIT
	DL=$1
	extension=`echo "$DL" | awk -F. '{print $NF}'`
	if [[ "$extension" != "hex" ]]
	then
		$CDL msgbox --icon hazard --text "Error" --informative-text "Filename must end in .hex" --button1 "Quit"
		exit
	fi
else 

	echo "PROGRESS:10"  # Platypus

	echo "Checking printer type"
	declare -a modelResponse
	modelResponse=(`$CDL standard-dropdown --icon gear --string-output --title "Printer Type" --text "Please select the model of your printer" --items "Printrbot Junior" "Printrbot LC/Original" "Printrbot Plus" "Printrbot Simple" | tr '\n' ' '`)

	if [[ "${modelResponse[0]}" == "Cancel" ]]
	then
		exit
	fi

	case ${modelResponse[2]} in
	Junior)
		URL='https://raw.github.com/PxT/Marlin/master/PBJuniorFirmware.cpp.hex'
		;;
	LC/Original)
		URL=LC URL
		;;
	Plus)
		URL=Plus URL
		;;
	Simple)
		URL=Simple URL
		;;
	*)
		$CDL msgbox --icon hazard --text "Error" --informative-text "An unexpected error occurred" --button1 "Quit"
		exit
		;;
	esac
	MD5URL="${URL}.md5"

	echo "PROGRESS:20"  # Platypus

	echo "Downloading"
	curl -s -o "$DL" "$URL" | $CDL progressbar --indeterminate --title "Download" --text "Downloading latest firmware from github"
	if [ -z "$DL" ]
	then
		$CDL msgbox --icon hazard --text "Error" --informative-text "There was an error downloading the firmware file" --button1 "Quit"
		exit
	fi
	DLMD5=`curl -s "$MD5URL"`
	if [ $? -ne 0 ]
	then
		$CDL msgbox --icon hazard --text "Error" --informative-text "There was an error retrieving the MD5 checksum" --button1 "Quit"
		exit
	fi
	MD5=`md5 -q "$DL"`
	if [[ "$MD5" != "$DLMD5" ]]
	then
		$CDL msgbox --icon hazard --text "Error" --informative-text "Could not verify the firmware checksum" --button1 "Quit"
		exit
	fi

fi  # Dropped file

echo "PROGRESS:45"  # Platypus
echo "Setup"
response=`$CDL msgbox --icon computer --text "Step 1" --informative-text "Connect the Printrbot to your computer using a USB cable" --button1 "Next"`
echo "PROGRESS:50"  # Platypus
response=`$CDL msgbox --icon computer --text "Step 2" --informative-text "Connect power to the Printrbot and ensure it is on." --button1 "Next"`
echo "PROGRESS:55"  # Platypus
response=`$CDL msgbox --icon computer --text "Step 3" --informative-text "If your Printrboard is Revision C or earlier then please remove the jumper on the BOOT pins now.  

If it is a Revision D or later then place a jumper on the BOOT pins." --button1 "Next"`
response=`$CDL msgbox --icon computer --text "Step 4" --informative-text "Push the Reset button (do not power down the board)." --button1 "Next"`

# Turns out it's not possible to use dfu-programmer to read back the firmware
# in any reliable way, unfortunately.
#echo "Backing up existing firmware"
#BACKUPFILE="/tmp/Printrbot_firmware_`date +%Y%m%d`.hex"
#./lib/bin/dfu-programmer at90usb1286 dump > $BACKUPFILE
#if [ -e $BACKPUFILE && ! -z $BACKUPFILE ]
#then
#	CURRENTMD5=`md5 -q $BACKUPFILE`
#	$CDL msgbox --icon computer --text "Backup complete" --informative-text "Your existing firmware has been backed up to $BACKUPFILE."
#else
#	rm -f $BACKUPFILE
#	response=`$CDL msgbox --icon hazard --text "Error" --informative-text "Failed to backup current firmware. You may proceed at your own risk" --button1 "Quit" --button2 "Next"`
#	if [ $response -eq "1" ]
#	then
#		exit
#	fi
#fi
#
#if [[ "$CURRENTMD5" == "$DLMD5" ]]
#then
#	$CDL msgbox --icon heart --text "Info" --informative-text "Your current firmware is up to date" --button1 "Quit"
#	exit
#fi

response=`$CDL ok-msgbox --icon hazard --text "Proceed?" --informative-text "About to start the firmware update process. Do not disconnect the USB or power cables until complete."`
if [[ "$response" -eq "2" ]]
then
	exit
fi

echo "PROGRESS:60"  # Platypus
echo "Erasing existing firmware"
export DYLD_LIBRARY_PATH=./dfu/lib
response=`./dfu/bin/dfu-programmer at90usb1286 erase 2>&1`
if [ $? -ne 0 ]; then
	$CDL msgbox --icon hazard --text "Error" --informative-text "$response" --button1 "Quit"
	exit
fi
echo "PROGRESS:75"  # Platypus
echo "Flashing new firmware"
response=`./dfu/bin/dfu-programmer at90usb1286 flash "$DL" 2>&1`
if [ $? -ne 0 ]; then
	$CDL msgbox --icon hazard --text "Error" --informative-text "$response" --button1 "Quit"
	exit
fi

echo "Done"
echo "PROGRESS:100"  # Platypus
$CDL ok-msgbox --no-cancel --icon heart --text Success --informative-text "Firmware successfully updated. If you removed the BOOT jumper please replace it now (Printrboard Revision C and earlier) otherwise remove it (Printrboard Revision D or later), then push the Reset button to boot the board normally." 

