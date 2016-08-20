#!/usr/bin/env bash

source ./src/config.sh
set -x

# create folders
[ -d "${OUTPUT_DIR}" ] && { rm -fr "${OUTPUT_DIR}" || exit 1 ; }
mkdir "${OUTPUT_DIR}" || exit 1
[ ! -d "${ROOT_DIR}" ] && { mkdir "${ROOT_DIR}" || exit 1 ; }

# download the base image
curl -sSL "${BASE_IMAGE_URL}" | unxz -d - > "${OUTPUT_DIR}/${BASE_IMAGE}"

# expend the raw image and partition size
dd if=/dev/zero bs="${ROOT_PART_SIZE}"M count=1 >> "${OUTPUT_DIR}/${BASE_IMAGE}"
/bin/echo -e "d\n2\nn\np\n2\n143360\n+${ROOT_PART_SIZE}M\nw\n" | sudo fdisk "${OUTPUT_DIR}/${BASE_IMAGE}"

# losetup
sudo losetup "${LOOP_BOOT}" "${OUTPUT_DIR}/${BASE_IMAGE}" -o $((40960 * 512)) --sizelimit 50MiB || exit 1
sudo losetup "${LOOP_ROOT}" "${OUTPUT_DIR}/${BASE_IMAGE}" -o $((143360 * 512)) --sizelimit "${ROOT_PART_SIZE}"MiB || exit 1

# create filesystem
/bin/echo -e "y\n" | sudo mkfs.ext4 -O ^has_journal -b 4096 -L rootfs -U "${ROOT_UUID}" "${LOOP_ROOT}" || exit 1
sudo tune2fs -o journal_data_writeback "${LOOP_ROOT}" || exit 1

# mount
sudo mount -U "${ROOT_UUID}" "${ROOT_DIR}" || exit 1

# debootstrap (local)
LATEST_DEBOOTSTRAP=$(curl -sSL http://ftp.us.debian.org/debian/pool/main/d/debootstrap | grep 'all.deb' | awk -F 'href' '{print $2}' | cut -d '"' -f2 | tail -n1)
curl -sSL "http://ftp.us.debian.org/debian/pool/main/d/debootstrap/${LATEST_DEBOOTSTRAP}" > "${OUTPUT_DIR}/${LATEST_DEBOOTSTRAP}"
cd "${OUTPUT_DIR}"
ar xv "${LATEST_DEBOOTSTRAP}"
tar -xf data.tar.gz
cd -

# debootstap / first-stage
if [ "$(command -v gpgv)" ]
then
    sudo DEBOOTSTRAP_DIR="${OUTPUT_DIR}"/usr/share/debootstrap "${OUTPUT_DIR}"/usr/sbin/debootstrap --foreign --arch=arm64 --exclude="${EXCLUDE_PKG}" --keyring=./src/debian-archive-keyring.gpg jessie "${ROOT_DIR}" || exit 1
else
    sudo DEBOOTSTRAP_DIR="${OUTPUT_DIR}"/usr/share/debootstrap "${OUTPUT_DIR}"/usr/sbin/debootstrap --foreign --arch=arm64 --exclude="${EXCLUDE_PKG}" jessie "${ROOT_DIR}" || exit 1
fi

# git-clone scripts from longsleep
[ -d "${LONGSLEEP_DIR}" ] && rm -fr "${LONGSLEEP_DIR}"
sudo git clone https://github.com/longsleep/build-pine64-image.git "${LONGSLEEP_DIR}" || exit 1

# chroot / second-stage
./src/chroot-debian.sh || exit 1

# kernel
sudo mount "${LOOP_BOOT}" "${BOOT_DIR}"
[ ! -d "${KERNEL_DIR}" ] && mkdir "${KERNEL_DIR}"
curl -sSL "${KERNEL_URL}" --output "${OUTPUT_DIR}/${KERNEL_FILE}"
sudo tar -C "${KERNEL_DIR}" --numeric-owner -xJpf "${OUTPUT_DIR}/${KERNEL_FILE}"
sudo rm -f "${ROOT_DIR}"/boot/pine64/*
sudo cp -RLp "${KERNEL_DIR}"/boot/. "${ROOT_DIR}"/boot/
sudo cp -RLp "${KERNEL_DIR}"/lib/. "${ROOT_DIR}"/lib/ 2> /dev/null || true
sudo cp -RLp "${KERNEL_DIR}"/usr/. "${ROOT_DIR}"/usr/

# umount
sudo umount "${BOOT_DIR}"
sudo umount "${ROOT_DIR}"

# losetup -d
sudo losetup -d "${LOOP_ROOT}"
sudo losetup -d "${LOOP_BOOT}"
