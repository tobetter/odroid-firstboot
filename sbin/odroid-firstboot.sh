#!/bin/sh

uuid_ofroot=`findmnt -nr -o uuid --target /`
partition=`blkid -U ${uuid_ofroot}`
partnum=`cat /sys/class/block/${partition#/dev/}/partition`
device=${partition%p${partnum}}

reboot=false;

footprint="/.firstboot"


on_firstboot() {
	#
	# Extend the root partition as much as available space in boot disk.
	#
        start=$(parted ${device} -ms unit s p | grep "^${partnum}" | cut -f 2 -d:)
	echo -e "o\nd\n${partnum}\nn\np\n${partnum}\n${start%s}\n\nw" | fdisk ${device}
        echo "I: the partition table for ${partition} is changed..."

	#
	# Display reboot message
	#
	ttydev=`tty | sed -e "s:/dev/::"`
	[ "${ttydev}" != "not a tty" ] && dialog --title "Firstboot" --pause "The partition size of ${partition} is changed and will be resized on next boot. Your system will restart in 5 seconds." 11 40 5
	if [ "$?" = "0" ]; then
		mount -o remount,rw /
		echo ${partition} > ${footprint}
		echo "I: ${footprint} is created"
		reboot="true"
	fi

	[ "$reboot" = "true" ] && reboot || exit 0
}

[ ! -f ${footprint} ] && on_firstboot

###############################################################################
# Start 2nd stage of firstboot & resizing the root file system
#
echo "I: the partition, ${partition}, is being resized..."
resize2fs ${partition}
fdisk -l ${device}
echo "I: done."

#
# New /etc/machine-id
#
MACHINE_ID_SETUP="/bin/systemd-machine-id-setup"
if [ -f ${MACHINE_ID_SETUP} ]; then
	rm -f /etc/machine-id
	${MACHINE_ID_SETUP}
	echo "I: '/etc/machine-id' is regenerated : "$(cat /etc/machine-id)
fi

#
# Cleaning unnecessary package(s)
#
packages="odroid-firstboot"
hwpack="hwpack-odroid-xu4"
dpkg-query --status ${hwpack} > /dev/null 2>&1
[ "$?" = "0" ] && packages="${packages} ${hwpack}"

echo "I: cleaning unnecessary package(s)..."
dpkg --purge ${packages}

#
# Remove footprint to start Firstboot
#
rm -f ${footprint}

echo "I: The 'firstboot' is finished, your system is initiated completely"

exit 0
