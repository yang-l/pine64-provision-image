BASE_IMAGE_URL="https://www.stdin.xyz/downloads/people/longsleep/pine64-images/simpleimage-pine64-latest.img.xz"
BASE_IMAGE="pine64.img"

KERNEL_URL="https://www.stdin.xyz/downloads/people/longsleep/pine64-images/linux/linux-pine64-latest.tar.xz"
KERNEL_FILE="kernel.tar.xz"

OUTPUT_DIR="./output"
ROOT_DIR="${OUTPUT_DIR}/root"
BOOT_DIR="${ROOT_DIR}/boot"
KERNEL_DIR="${OUTPUT_DIR}/kernel"
LONGSLEEP_DIR="${OUTPUT_DIR}/longsleep"

ROOT_PART_SIZE="1024"

LOOP_BOOT="/dev/loop1"
LOOP_ROOT="/dev/loop2"

ROOT_UUID=$(uuidgen)
