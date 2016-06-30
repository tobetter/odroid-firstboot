#!/bin/sh

uuid_ofroot=`findmnt -nr -o uuid --target /`
part_ofroot=`blkid -U ${uuid_ofroot}`
pnum_ofroot=`cat /sys/class/block/${part_ofroot#/dev/}/partition`

device=${part_ofroot%p${pnum_ofroot}}

reboot=false;

footprint="/.firstboot"

on_firstboot() {
	#
	# Extend the root partition as much as available space in boot disk.
	#
	start=$(parted ${device} -ms unit s p | grep "^${pnum_ofroot}" | cut -f 2 -d:)
	echo -e "o\nd\n${pnum_ofroot}\nn\np\n${pnum_ofroot}\n${start%s}\n\nw" | fdisk ${device}
	echo "I: the partition table for ${part_ofroot} is changed..."

	#
	# Replace the UUID of root file system
	#
	tune2fs -O ^uninit_bg ${part_ofroot}
	tune2fs -U `uuidgen` ${part_ofroot}
	tune2fs -O +uninit_bg ${part_ofroot}

	uuid_ofroot=`findmnt -nr -o uuid --target /`

	#
	# Create default mount table '/etc/fstab'
	#
	bootdir="/boot"
	fstab="/etc/fstab"
	part_ofboot=`blkid -L BOOT | grep ${device}`
	uuid_ofboot=`findmnt -nr -o uuid --target ${bootdir}`

	[ `mount | grep ${bootdir} > /dev/null` ] || umount ${bootdir}
	mount ${part_ofboot} ${bootdir}

	# Overwrite installed mount table file
	echo "# DEFAULT MOUNT TABLE, AUTOMATICALLY CREATED BY 'ODROID-FIRSTBOOT'" > ${fstab}
	echo "" >> ${fstab}
	cat /proc/mounts | grep ${part_ofroot} >> ${fstab}
	cat /proc/mounts | grep ${part_ofboot} >> ${fstab}

	sed -i "s,${part_ofroot},UUID=${uuid_ofroot},g" ${fstab}
	sed -i "s,${part_ofboot},UUID=${uuid_ofboot},g" ${fstab}

	echo "I: default mount table is created to ${fstab}"

	#
	# Display reboot message
	#
	ttydev=`tty | sed -e "s:/dev/::"`
	[ "${ttydev}" != "not a tty" ] && dialog --title "Firstboot" --pause "The partition size of ${part_ofroot} is changed and will be resized on next boot. Your system will restart in 5 seconds." 11 40 5
	if [ "$?" = "0" ]; then
		mount -o remount,rw /
		echo ${part_ofroot} > ${footprint}
		echo "I: ${footprint} is created"
		reboot="true"
	fi

	[ "$reboot" = "true" ] && reboot || exit 0
}

[ ! -f ${footprint} ] && on_firstboot

###############################################################################
# Start 2nd stage of firstboot & resizing the root file system
#
echo "I: the partition, ${part_ofroot}, is being resized..."
resize2fs ${part_ofroot}
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
