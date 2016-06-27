#!/bin/sh

[ -z "$1" ] && echo "Disk to resize the partition is not selected!" && exit 1
[ -z "$2" ] && echo "Please specify the partition index!" && exit 1

disk="$1"
partnum="$2"
partition="/dev/${disk}p${partnum}"
device="/dev/${disk}"

footprint="/.firstboot"

rootfs_growup() {
        echo "Extending the partition ${partition}..."
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
}


if [ ! -f ${footprint} ]; then
        rootfs_growup
        mount -o remount,rw /
        echo ${partition} > ${footprint}
        reboot
fi

echo "Resizing the partition..."
resize2fs ${partition}
fdisk -l ${device}
dpkg --purge odroid-firstboot
rm -f ${footprint}

exit 0
