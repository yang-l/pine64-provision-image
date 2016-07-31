#!/usr/bin/env bash

source ./src/config.sh

# initial variable
OPTIND=1
unset HOSTNAME DEVICE

while getopts "h:d:" opt; do
    case "$opt" in
        h)  HOSTNAME=$OPTARG
            ;;
        d)  DEVICE=$OPTARG
            ;;
    esac
done
[ -z "${HOSTNAME}" ] && { HOSTNAME="pine64" ;  echo "Hostname \"-h\" unspecified. Default hostname [ ${HOSTNAME} ] is used" ; }
[ -z "${DEVICE}" ] && { echo "Device \"-d\" unspecified" ; exit 1 ; }

set -x

# burn image to media
sudo dd if="${OUTPUT_DIR}/${BASE_IMAGE}" of="${DEVICE}" bs=4M conv=sync,noerror

# LVM
if [ "${INSTALL_DOCKER}" = true ]
then
    LVM_FS="/dev/mapper/${VG_NAME}-${LV_DOCKER_NAME}"
    # LVM
    /bin/echo -e "n\np\n3\n$((143360 + ROOT_PART_SIZE * 1024 * 1024 / 512))\n\nt\n3\n8e\nw\n" | sudo fdisk "${DEVICE}"
    sudo pvcreate "${DEVICE}3"
    sudo vgcreate "${VG_NAME}" "${DEVICE}3"
    /bin/echo -e "y\n" | sudo lvcreate -L "${LV_DOCKER_SIZE}" -n "${LV_DOCKER_NAME}" "${VG_NAME}"
    # FS
    /bin/echo -e "y\n" | sudo mkfs.ext4 -O ^has_journal -b 4096 -L rootfs -U "${LV_DOCKER_FS_UUID}" "${LVM_FS}"
    sudo tune2fs -o journal_data_writeback "${LVM_FS}"
fi

# mount the media
sudo mount "${DEVICE}2" "${ROOT_DIR}"

# set hostname
echo "${HOSTNAME}" | sudo tee "${ROOT_DIR}"/etc/hostname

# Docker
if [ "${INSTALL_DOCKER}" = true ]
then
    # /etc/fstab
    echo "/dev/${VG_NAME}/${LV_DOCKER_NAME}	/var/lib/docker	ext4	defaults,data=writeback,noatime,nodiratime		0	1" >> "${ROOT_DIR}"/etc/fstab
fi

# umount the media
sleep 5
sudo umount "${DEVICE}2"
