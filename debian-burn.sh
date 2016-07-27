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
sleep 3

# mount the media
sudo mount "${DEVICE}2" "${ROOT_DIR}"

# set hostname
echo "${HOSTNAME}" | sudo tee "${ROOT_DIR}"/etc/hostname

# umount the media
sleep 5
sudo umount "${DEVICE}2"
