#!/bin/sh
########################################################################
#
# Description : Firmware Script
#
# Authors     : Based on Open Suse Udev Rules
#               kay.sievers@suse.de
#
# Adapted to  : Jim Gifford
# LFS
#
# Version     : 00.00
#
# Notes       :
#
########################################################################

FIRMWARE_DIRS="/lib/firmware"

if [ ! -e /sys/$DEVPATH/loading ]; then
    echo "firmware loader misses sysfs directory" >> /root/firmwareload.log
    exit 0
fi

for DIR in $FIRMWARE_DIRS; do
    [ -e "$DIR/$FIRMWARE" ] || continue
    echo "loading $DIR/$FIRMWARE" >> /root/firmwareload.log
    echo 1 > /sys/$DEVPATH/loading
    cat "$DIR/$FIRMWARE" > /sys/$DEVPATH/data
    echo 0 > /sys/$DEVPATH/loading
    exit
done

echo -1 > /sys/$DEVPATH/loading
echo "Cannot find  firmware file '$FIRMWARE'" >> /root/firmwareload.log
exit 1
