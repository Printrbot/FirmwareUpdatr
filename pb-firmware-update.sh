#!/bin/sh  -x

PATH=/bin:/sbin:/usr/bin
CDL="CocoaDialog.app/Contents/MacOS/CocoaDialog"
TMPDIR=${TMPDIR:-/tmp}

DROPPED="$1"
tempname=`basename $0`

# This is the configuration file for the app itself
export CONFDL=`mktemp -q "${TMPDIR}/${tempname}.conf.XXXXXX"`
if [ $? -ne 0 ]; then
    error_box  "Can't create temp config file"
fi

# This will hold the downloaded firmware file
DL=`mktemp -q "${TMPDIR}/${tempname}.XXXXXX"`
if [ $? -ne 0 ]; then
    error_box  "Can't create temp file"
fi

# The configuration file for the printer
export CONFIGDL=`mktemp -q "${TMPDIR}/${tempname}.gcode.XXXXXX"`
if [ $? -ne 0 ]; then
    error_box  "Can't create temp gcode file"
fi

trap on_exit EXIT

BOTNAMES=()

function on_exit() { 
    if [ -z "$DROPPED" ]
    then
        rm -f "$DL"
    fi
    rm -f "$CONFIGDL"
    rm -f "$CONFDL"
}

function progress_update() {
    msg=$1

    $CDL progressbar --indeterminate --title "Download" --text "$msg"
}

function progress_bar() {
    progress=$1

    # The platypus app recognizes this magic syntax and updates
    # the completion bar percentage to match
    echo "PROGRESS:${progress}"
}

function file_dropped() {
    trap - EXIT
    DL="$DROPPED"
    extension=`echo "$DL" | awk -F. '{print $NF}'`
    if [[ "$extension" != "hex" ]]
    then
        $CDL msgbox --icon hazard --text "Error" --informative-text "Filename must end in .hex" --button1 "Quit"
        exit
    fi
}
 
function curl_download() {
    output=$1
    url=$2
    
    curl -L -s -o "$output" "$url" || error_box "Unable to download $url. Please check your internet connectivity."
}

function get_config() {
    CONFIGURL="https://raw.githubusercontent.com/Printrbot/FirmwareUpdatr/master/Updatr.conf"
    
    curl_download "$CONFDL" "$CONFIGURL"
    while read line
    do
        # Read the config file one line at a time.  The first field is added to
        # an array to build the list of possible machines that the user will choose
        # Lines starting with a '#' are ignored
        IFS=';' read -a confLine <<< "$line"
        if [ ${line:0:1} == '#' ]
        then
            continue
        fi
        name="${confLine[0]}"
        # Convert spaces to underscores to make the quoting requirements less onerous later
        name=${name// /_}
        BOTNAMES+=($name)
    done < "$CONFDL"
}


function error_box() {
    msg="$1"

    $CDL msgbox --icon hazard --text "Error" --informative-text "$msg" --button1 "Quit"
    exit 1
}

function message_box() {
    title="$1"
    msg="$2"

    $CDL msgbox --icon computer --text "$title" --informative-text "$msg" --button1 "Next"
}

function warning_box() {
    title="$1"
    msg="$2"

    $CDL ok-msgbox --icon hazard --text "$title" --informative-text "$msg"
}

function determine_config() {
    model="$1"

    grep "^$model;" "$CONFDL" | cut -d';' -f3
}

function determine_firmware() {
    model="$1"

    grep "^$model;" "$CONFDL" | cut -d';' -f2
}

function write_eeprom() {
    echo "Writing EEPROM parameters"
    response=`$CDL msgbox --icon computer --text "Step 5" --informative-text "Firmware successfully updated. If you removed the BOOT jumper please replace it now (Printrboard Revision C and earlier) otherwise remove it (Printrboard Revision D or later), then push the Reset button to boot the board normally.

We will finish the configuration process by writing some standard parameters to the board." --button1 "Next"`

    PORTLIST=`ls -1 /dev/tty.usbmodem*`
    PORTCOUNT=`ls -1 /dev/tty.usbmodem* 2> /dev/null | wc -l`
    declare -a portResponse
    if [ $PORTCOUNT -gt 1 ] 
    then
        portResponse=(`$CDL standard-dropdown --icon gear --string-output --title "Printer Port" --text "Found more than one connected port.  Please select the port your printer is connected to." --items $PORTLIST | tr '\n' ' '`)
            if [[ "${portResponse[0]}" == "Cancel" ]]
            then
                    exit
            fi
        PORT="${portResponse[1]}"
    elif [ $PORTCOUNT -eq 1 ]
    then
        PORT=$PORTLIST
    else
        error_box "Couldn't find a port to send GCODE"
    fi

    echo "M500" >> "$CONFIGDL"
    response=`./dfu/bin/myterm.py -p $PORT -b 250000 --gcode "$CONFIGDL" --debug`
    echo $response
}

function normal_update() {

    progress_bar 10

    echo "Getting configuration file"
    get_config
    echo "Checking printer type"
    declare -a modelResponse

    # The model list is built based on the existing array, with underscores converted back to spaces
    modelResponse=(`$CDL standard-dropdown --icon gear --string-output --title "Printer Type" --text "Please select the model of your printer" --items "${BOTNAMES[@]//_/ }" | tr '\n' ' '`)
    model="${modelResponse[@]:1}"

    if [[ "${modelResponse[0]}" == "Cancel" ]]
    then
        exit
    fi

    CONFIG=`determine_config "${model}"`
    URL=`determine_firmware "${model}"`
    MD5URL="$URL.md5"

    progress_bar 20

    echo "Downloading"
    curl_download "$DL" "$URL" | progress_update "Downloading latest firmware from github"
    if [ -z "$DL" ]
    then
        error_box "There was an error downloading the firmware file"
        exit
    fi
    DLMD5=`curl -L -s "$MD5URL"`
    if [ $? -ne 0 ]
    then
        error_box "There was an error retrieving the MD5 checksum"
    fi
    MD5=`md5 -q "$DL"`
    if [[ "$MD5" != "$DLMD5" ]]
    then
        error_box "Could not verify the firmware checksum"
    fi

    curl_download "$CONFIGDL" "$CONFIG" | progress_update "Downloading printer configuration from github"
    if [ -z "$CONFIGDL" ]
    then
        warning_box "Error" "There was an error downloading the configuration file for your printer. See https://github.com/Printrbot/Printr-Configs for the proper configuration information."
    fi

}


if [ ! -z "$DROPPED" ]
then
    file_dropped 
else 
    normal_update
fi

progress_bar 45
echo "Setup"
response=`message_box "Step 1" "Connect the Printrbot to your computer using a USB cable"`
progress_bar 50
response=`message_box "Step 2" "Connect power to the Printrbot and ensure it is on."`
progress_bar 55
response=`message_box "Step 3" "If your Printrboard is Revision C or earlier then please remove the jumper on the BOOT pins now.  

If it is a Revision D or later then place a jumper on the BOOT pins."`
response=`message_box "Step 4" "Push the Reset button (do not power down the board)."` 

response=`warning_box "Proceed?" "About to start the firmware update process. Do not disconnect the USB or power cables until complete."`
if [[ "$response" -eq "2" ]]
then
    exit
fi

progress_bar 60
echo "Erasing existing firmware"
export DYLD_LIBRARY_PATH=./dfu/lib
response=`./dfu/bin/dfu-programmer at90usb1286 erase 2>&1`
if [ $? -ne 0 ]; then
    error_box "$response"
fi
echo "$response"

progress_bar 75
echo "Flashing new firmware"
response=`./dfu/bin/dfu-programmer at90usb1286 flash "$DL" 2>&1`
if [ $? -ne 0 ]; then
    error_box "$response"
fi
echo "$response"

progress_bar 90

if [ -z "$1" ]
then
    write_eeprom
fi

echo "Done"
progress_bar 100
$CDL ok-msgbox --no-cancel --icon heart --text Success --informative-text "Firmware and configuration successfully updated." 

