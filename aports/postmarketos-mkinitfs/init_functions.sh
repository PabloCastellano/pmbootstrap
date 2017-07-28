#!/bin/sh
# This file will be in /init_functions.sh inside the initramfs.
IP=172.16.42.1

_led_write() {
    echo $1 > /sys/class/leds/white/brightness
}

led_off() {
    if [ -n $1 ]; then
        kill $1 >/dev/null 2>&1
    fi
    _led_write 0
}

led_fade_in() {
    delay="${1:-0.03}"
    step="${2:-10}"
    for val in $(seq 0 $step 250); do
        _led_write $val
        sleep $delay
    done
}

led_fade_out() {
    delay="${1:-0.03}"
    step="${2:-10}"
    for val in $(seq 250 -$step 0); do
        _led_write $val
        sleep $delay
    done
}

led_blink() {
    repeat=$(expr "${1:-5}" - 1)
    delay="${2:-0.25}"

    for t in $(seq 0 $repeat); do
        _led_write 250
        sleep $delay
        _led_write 0
        sleep $delay
    done
}

led_waiting_for_password() {
    while true; do
        led_blink 2 0.15
        sleep 3
    done
}

led_blink_fatal() {
    while true; do
        led_blink 1 0.1
    done
}

# Redirect stdout and stderr to logfile
setup_log() {
	# Bail out if PMOS_NO_OUTPUT_REDIRECT is set
	echo "### postmarketOS initramfs ###"
	grep -q PMOS_NO_OUTPUT_REDIRECT /proc/cmdline && return

	# Print a message about what is going on to the normal output
	echo "NOTE: All output from the initramfs gets redirected to:"
	echo "/pmOS_init.log"
	echo "If you want to disable this behavior (e.g. because you're"
	echo "debugging over serial), please add this to your kernel"
	echo "command line: PMOS_NO_OUTPUT_REDIRECT"

	# Start redirect, print the first line again
	exec >/pmOS_init.log 2>&1
	echo "### postmarketOS initramfs ###"
}

mount_proc_sys_dev() {
	# mdev
	mount -t proc -o nodev,noexec,nosuid proc /proc
	mount -t sysfs -o nodev,noexec,nosuid sysfs /sys

	mkdir /config
	mount -t configfs -o nodev,noexec,nosuid configfs /config

	# /dev/pts (needed for telnet)
	mkdir -p /dev/pts
	mount -t devpts devpts /dev/pts
}

setup_mdev() {
	echo /sbin/mdev >/proc/sys/kernel/hotplug
	mdev -s
}

mount_subpartitions() {
	for i in /dev/mmcblk*; do
		case "$(kpartx -l "$i" 2>/dev/null | wc -l)" in
			2)
				echo "mount subpartitions of $i"
				kpartx -afs "$i"
				break
				;;
			*)
				continue
				;;
		esac
	done
}

find_root_partition() {
	# The partition layout is one of the following:
	# a) boot, root partitions on sdcard
	# b) boot, root partition on the "system" partition (which has its
	#    own partition header! so we have partitions on partitions!)
	#
	# mount_subpartitions() must get executed before calling
	# find_root_partition(), so partitions from b) also get found.
	#
	# However, after executing mount_subpartitions(), the partitions
	# from a) get mounted to /dev/mapper - and then you can only use
	# the ones from /dev/mapper, not the original partition paths (they
	# will appear as busy when trying to mount them). This is an
	# unwanted side-effect, that we must deal with.
	# The subpartitions from b) get mounted to /dev/mapper, and this is
	# what we want.
	#
	# To deal with the side-effect, we use the partitions from
	# /dev/mapper first, and then fall back to partitions with all paths
	# (in case the user inserted an SD card after mount_subpartitions()
	# ran!).

	# Try the partitions in /dev/mapper first.
	for id in pmOS_root crypto_LUKS; do
		DEVICE="$(blkid | grep /dev/mapper | grep "$id" \
			| cut -d ":" -f 1)"
		[ -z "$DEVICE" ] || break
	done

	# Then try all devices
	if [ -z "$DEVICE" ]; then
		for id in pmOS_root crypto_LUKS; do
			DEVICE="$(blkid | grep "$id" | cut -d ":" -f 1)"
			[ -z "$DEVICE" ] || break
		done
	fi
	echo "$DEVICE"
}

setup_usb_network_android() {
	# Only run, when we have the android usb driver
	SYS=/sys/class/android_usb/android0
	[ -e "$SYS" ] || return

	# Do the setup
	printf "%s" "0" >"$SYS/enable"
	printf "%s" "18D1" >"$SYS/idVendor"
	printf "%s" "D001" >"$SYS/idProduct"
	printf "%s" "rndis" >"$SYS/functions"
	printf "%s" "1" >"$SYS/enable"
}

setup_usb_network_configfs() {
	CONFIGFS=/config/usb_gadget
	[ -e "$CONFIGFS" ] || return

	mkdir $CONFIGFS/g1
	printf "%s" "18D1" >"$CONFIGFS/g1/idVendor"
	printf "%s" "D001" >"$CONFIGFS/g1/idProduct"

	mkdir $CONFIGFS/g1/strings/0x409

	mkdir $CONFIGFS/g1/functions/rndis.usb0

	mkdir $CONFIGFS/g1/configs/c.1
	mkdir $CONFIGFS/g1/configs/c.1/strings/0x409
	printf "%s" "rndis" > $CONFIGFS/g1/configs/c.1/strings/0x409/configuration

	ln -s $CONFIGFS/g1/functions/rndis.usb0 $CONFIGFS/g1/configs/c.1
	echo "$(ls /sys/class/udc)" > $CONFIGFS/g1/UDC
}

setup_usb_network() {
	# Only run once
	_marker="/tmp/_setup_usb_network"
	[ -e "$_marker" ] && return
	touch "$_marker"

	# Run all usb network setup functions (add more below!)
	setup_usb_network_android
	setup_usb_network_configfs
}

start_udhcpd() {
	# Only run once
	[ -e /etc/udhcpd.conf ] && return

	# Get usb interface
	INTERFACE=""
	ifconfig rndis0 "$IP" && INTERFACE=rndis0
	if [ -z $INTERFACE ]; then
		ifconfig usb0 "$IP" && INTERFACE=usb0
	fi

	# Create /etc/udhcpd.conf
	{
		echo "start 172.16.42.2"
		echo "end 172.16.42.254"
		echo "lease_file /var/udhcpd.leases"
		echo "interface $INTERFACE"
		echo "option subnet 255.255.255.0"
	} >/etc/udhcpd.conf

	# Start the dhcpcd daemon (forks into background)
	udhcpd
}

unlock_root_partition() {
	led_waiting_for_password &
	pid=$!
	# Wait for the root partition (and unlock it if it is encrypted)
	while ! [ -e /sysroot/usr ]; do
		partition="$(find_root_partition)"
		if [ -z "$partition" ]; then
			echo "Could not find the root partition."
			echo "Maybe you need to insert the sdcard, if your device has"
			echo "any? Trying again in one second..."
			sleep 1
		elif cryptsetup isLuks "$partition"; then
			cryptsetup luksOpen "$partition" root || continue
			partition="/dev/mapper/root"
			break
		else
			# Unencrypted
			break
		fi
	done

	# Mount the root partition
	[ -e /sysroot/usr ] || mount -w -t ext4 "$partition" /sysroot

	# Stop blinking
	led_off $pid
}

# $1: path to ppm.gz file
show_splash() {
	gzip -c -d "$1" >/tmp/splash.ppm
	fbsplash -s /tmp/splash.ppm
}

echo_connect_ssh_message() {
    echo "Your root partition has been decrypted successfully!"
    echo "You can connect to your device using SSH in a few seconds:"
    echo "ssh user@$IP"
}
