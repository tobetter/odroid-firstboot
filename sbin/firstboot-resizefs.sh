#!/bin/sh

[ -z "$1" ] && echo "Disk to resize the partition is not selected!" && exit 1
[ -z "$2" ] && echo "Please specify the partition index!" && exit 1

disk="$1"
partnum="$2"
partition="${disk}p${partnum}"

footprint="/.firstboot"

rootfs_growup() {
        echo "Extending the partition ${partition}..."
        start=$(parted ${disk} -ms unit s p | grep "^${partnum}" | cut -f 2 -d:)

        fdisk ${disk} <<__EOF > /dev/null
p
d
${partnum}
n
p
${partnum}
${start}

w
__EOF
}


if [ ! -f ${footprint} ]; then
        rootfs_growup
        echo ${partition} > ${footprint}
        reboot
else
        echo "Resizing the partition..."
        resize2fs ${partition}
        fdisk -l ${disk}
        dpkg --purge odroid-firstboot
        rm -f ${footprint}
fi
