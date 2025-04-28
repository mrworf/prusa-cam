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
PRINTER=
TOKEN=
DEVICE='/dev/video0'
INPUT=0
RESOLUTION='640x480'
QUALITY=65
INTERVAL=10

# Load the custom settings
if [ -f 'prusa-cam-config' ]; then
	source 'prusa-cam-config'
fi

# Check that we have sane values, or abort
if [ -z "$PRINTER" -o -z "$TOKEN" -o -z "$RESOLUTION" -o -z "$QUALITY" ]; then
	echo >&2 "ERROR: Script not configured properly"
	exit 255
fi

################[ DO NOT CHANGE BELOW THIS POINT ]############################

# Check requirements
which >/dev/null fswebcam || echo >&2 "ERROR: You need fswebcam for this script"
which >/dev/null curl || echo >&2 "ERROR: You need curl for this script"

# Where to save temporary file
TMPFILE=/tmp/prusa-cam.jpg
FINGERPRINT='deadbeefc001beef'

# Start neverending loop
while true; do
	START=$(date +%s)

	echo "Grabbing still..."
	fswebcam --no-banner -d ${DEVICE} -i ${INPUT} -r ${RESOLUTION} --jpeg ${QUALITY} ${TMPFILE} || exit 1

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
