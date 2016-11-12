BASE_IMAGE_URL="https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz"
BASE_IMAGE="pine64.img"

KERNEL_URL="https://github.com/yang-l/pine64-kernel/blob/1ac0eeab37f7ead8b5951303d39947b1deda4550/kernel.tar.xz?raw=true"
KERNEL_FILE="kernel.tar.xz"

SRC_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SRC_DIR}/../output"
ROOT_DIR="${OUTPUT_DIR}/root"
BOOT_DIR="${ROOT_DIR}/boot"
KERNEL_DIR="${OUTPUT_DIR}/kernel"
LONGSLEEP_DIR="${OUTPUT_DIR}/longsleep"
CONF_DIR="${OUTPUT_DIR}/../src"

ROOT_PART_SIZE="1536"

LOOP_BOOT="/dev/loop5"
LOOP_ROOT="/dev/loop6"

ROOT_UUID=$(uuidgen)

EXCLUDE_PKG="apt-transport-https,cron,debconf-i18n,logrotate,tasksel,tasksel-data,vim-common,vim-tiny,wget"

# Provision option for Docker
INSTALL_DOCKER=true

# LVM configs
VG_NAME="pine64"
LV_DOCKER_NAME="docker"
LV_DOCKER_SIZE="5G"
LV_DOCKER_FS_UUID=$(uuidgen)
