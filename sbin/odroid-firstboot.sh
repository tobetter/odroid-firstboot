#!/bin/sh

uuid_ofroot=`findmnt -nr -o uuid --target /`
partition=`blkid -U ${uuid_ofroot}`
partnum=`cat /sys/class/block/${partition#/dev/}/partition`
device=${partition%p${partnum}}

reboot=false;

footprint="/.firstboot"

rootfs_growup() {
        start=$(parted ${device} -ms unit s p | grep "^${partnum}" | cut -f 2 -d:)

        fdisk ${device} <<__EOF > /dev/null
p
d
${partnum}
n
p
${partnum}
${start%s}

w
__EOF
        echo "I: the partition table for ${partition} is changed..."

	ttydev=`tty | sed -e "s:/dev/::"`
	if [ "${ttydev}" != "not a tty" ]; then
		dialog --title "Reboot" \
			--pause "The partition size of ${partition} is changed \
and will be resized on next boot. Your system will restart in 5 seconds." 11 40 5
	fi
	if [ "$?" = "0" ]; then
		mount -o remount,rw /
		echo "I: root file system is remounted!"
		echo ${partition} > ${footprint}
		reboot="true"
		echo "I: /.firstboot is created, the system is going to reboot..."
	fi
}

echo ${footprint}
if [ ! -f ${footprint} ]; then
        rootfs_growup
	[ "$reboot" = "true" ] && reboot || exit 0
fi

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

rm -f ${footprint}

echo "I: The 'firstboot' is finished, your system is initiated completely"

exit 0
