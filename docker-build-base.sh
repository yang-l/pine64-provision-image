docker run -i --rm \
       --privileged \
       -v $(pwd):/srv/source \
       $1 /bin/bash -s <<EOF

set -x

[ -b "/dev/loop5" ] || mknod /dev/loop5 -m0660 b 7 5
[ -b "/dev/loop6" ] || mknod /dev/loop6 -m0660 b 7 6

[ -d "/proc/sys/fs/binfmt_misc" ] || modprobe binfmt_misc
[ -f "/proc/sys/fs/binfmt_misc/register" ] || mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc

cd /srv/source
bash debian-base.sh

EOF
