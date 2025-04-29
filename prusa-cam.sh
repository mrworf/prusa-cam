#!/bin/bash
#
# Copyright (C) 2025 Henric Andersson (git@sensenet.nu)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Check requirements
which >/dev/null libcamera-still || echo >&2 "ERROR: You need libcamera-still for this script"
which >/dev/null curl || echo >&2 "ERROR: You need curl for this script"

# Detect highest resolution
CAPS=$(libcamera-still --list-cameras)

# Extract resolutions from camera info
while read RES; do
    WIDTH=$(echo $RES | cut -d'x' -f1)
    HEIGHT=$(echo $RES | cut -d'x' -f2)	
    
	echo "Checking resolution: ${WIDTH}x${HEIGHT}"

    # Skip if width equals height
    if [ $WIDTH -eq $HEIGHT ]; then
        continue
    fi
    
    # Calculate aspect ratio using integer math	
    if [ $WIDTH -gt $HEIGHT ]; then
        RATIO=$(( WIDTH * 1000 / HEIGHT ))
    else
        RATIO=$(( HEIGHT * 1000 / WIDTH ))
    fi	
    
    # Calculate difference from 1.33 (1330) for non-widescreen preference
    RATIO_DIFF=$(( RATIO - 1330 ))
    if [ $RATIO_DIFF -lt 0 ]; then
        RATIO_DIFF=$(( -RATIO_DIFF ))
    fi	
    
    # Update best resolution if this one is better
    if [ -z "$BEST_RATIO_DIFF" ] || [ $RATIO_DIFF -lt $BEST_RATIO_DIFF ]; then
        BEST_RATIO_DIFF=$RATIO_DIFF
        BEST_WIDTH=$WIDTH
        BEST_HEIGHT=$HEIGHT
    fi
done < <(echo "$CAPS" | grep -o '[0-9]\+x[0-9]\+')

# Set the final dimensions
WIDTH=$BEST_WIDTH
HEIGHT=$BEST_HEIGHT

echo "Detected resolution: ${WIDTH}x${HEIGHT}"

# Load default values
PRINTER=
TOKEN=
QUALITY=65
INTERVAL=10

# Load the custom settings
if [ -f 'prusa-cam-config' ]; then
	source 'prusa-cam-config'
fi

# Hint to the user what resolution we're using based on the detected resolution and the config
echo "Selected resolution: ${WIDTH}x${HEIGHT}"

# Check that we have sane values, or abort
if [ -z "$PRINTER" -o -z "$TOKEN" -o -z "$WIDTH" -o -z "$HEIGHT" -o -z "$QUALITY" ]; then
	echo >&2 "ERROR: Script not configured properly"
	exit 255
fi


# Where to save temporary file
TMPFILE=/tmp/prusa-cam.jpg
FINGERPRINT='deadbeefc001beef'

# Start neverending loop
while true; do
	START=$(date +%s)

	echo "Grabbing still..."
	libcamera-still --width ${WIDTH} --height ${HEIGHT} --immediate -q ${QUALITY} -o ${TMPFILE} || exit 1

	SIZE=$(ls -la "${TMPFILE}" | awk '{print $5}')

	echo "Uploading $SIZE bytes to prusa..."
	curl -X PUT -H "accept: */*" -H "content-type: image/jpg" -H "content-length: ${SIZE}" -H "token: ${TOKEN}" -H "fingerprint: ${FINGERPRINT}" "https://connect.prusa3d.com/c/snapshot" --data-binary "@${TMPFILE}" || exit 2
	echo "Done"

	TIME=$(($(date +%s) - ${START}))
	echo "Process took $TIME seconds"
	if [ $TIME -lt $INTERVAL ]; then
		DELAY=$((${INTERVAL} - ${TIME}))
		echo "Waiting $DELAY seconds before next capture"
		sleep ${DELAY}
	else
		echo "We're behind, immediately capture next"
	fi
done
