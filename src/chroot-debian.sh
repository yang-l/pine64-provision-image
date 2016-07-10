#!/usr/bin/env bash

source ./src/config.sh

# prevent dpkg to start daemons
sudo dd of="${ROOT_DIR}/usr/sbin/policy-rc.d" << EOF
#!/bin/sh
exit 101
EOF
sudo chmod a+x "${ROOT_DIR}/usr/sbin/policy-rc.d"

# copy static qemu emulation
sudo cp ./src/bin/qemu-aarch64-static "${ROOT_DIR}/usr/bin"
[ "$(uname -m)" == "x86_64" ] && [ -f /proc/sys/fs/binfmt_misc/aarch64 ] || echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/usr/bin/qemu-aarch64-static:' | sudo tee /proc/sys/fs/binfmt_misc/register

# chroot / mount
do_chroot() {
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/mount -t proc proc /proc
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/mount -t sysfs sys /sys
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/bash "$@"
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/umount /sys
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/umount /proc
}

# chroot / debootstrap second-stage
do_chroot /debootstrap/debootstrap --second-stage

# chroot / create scripts
# copy platform scripts from longsleep
yes | sudo cp -av "${LONGSLEEP_DIR}"/simpleimage/platform-scripts/. "${ROOT_DIR}/usr/local/sbin"
sudo chown root:root "${ROOT_DIR}"/usr/local/sbin/.
sudo chmod 755 "${ROOT_DIR}"/usr/local/sbin/.

# create systemd unit files
sudo dd of="${ROOT_DIR}/etc/systemd/system/eth0-mackeeper.service" << EOF
[Unit]
Description=Fix eth0 mac address to uEnv.txt
After=systemd-modules-load.service local-fs.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pine64_eth0-mackeeper.sh
[Install]
WantedBy=multi-user.target
EOF

sudo dd of="${ROOT_DIR}/etc/systemd/system/cpu-corekeeper.service" << EOF
[Unit]
Description=CPU corekeeper
[Service]
ExecStart=/usr/local/sbin/pine64_corekeeper.sh
[Install]
WantedBy=multi-user.target
EOF

sudo dd of="${ROOT_DIR}/etc/systemd/system/ssh-keygen.service" << EOF
[Unit]
Description=Generate SSH keys if not there
Before=ssh.service
ConditionPathExists=|!/etc/ssh/ssh_host_key
ConditionPathExists=|!/etc/ssh/ssh_host_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key.pub
[Service]
ExecStart=/usr/bin/ssh-keygen -A
Type=oneshot
RemainAfterExit=yes
[Install]
WantedBy=ssh.service
EOF

sudo dd of="${ROOT_DIR}/etc/udev/rules.d/90-sunxi-disp-permission.rules" << EOF
KERNEL=="disp", MODE="0770", GROUP="video"
KERNEL=="cedar_dev", MODE="0770", GROUP="video"
KERNEL=="ion", MODE="0770", GROUP="video"
EOF

# chroot
do_chroot << "EOF"
#### INSIDE CHROOT ####

## Common functions
debian_apt_list () {
    echo "deb http://ftp.debian.org/debian/ ${1} main contrib non-free" > /etc/apt/sources.list
    echo "deb http://ftp.debian.org/debian/ ${1}-updates main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://ftp.debian.org/debian/ ${1}-backports main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://security.debian.org/ ${1}/updates main contrib non-free" >> /etc/apt/sources.list

    echo "APT::Default-Release \"${1}\";" > /etc/apt/apt.conf.d/99defaultrelease

    echo "deb http://ftp.debian.org/debian/ stable main contrib non-free" > /etc/apt/sources.list.d/stable.list
    echo "deb http://security.debian.org/ stable/updates main contrib non-free" >> /etc/apt/sources.list.d/stable.list

    echo "deb http://ftp.debian.org/debian/ testing main contrib non-free" > /etc/apt/sources.list.d/testing.list
    echo "deb http://security.debian.org/ testing/updates main contrib non-free" >> /etc/apt/sources.list.d/testing.list
}

set_hostname () {
    echo $1 > /etc/hostname
    cat > /etc/hosts << EOF_HOSTS
127.0.0.1 $1 localhost

# The following lines are desirable for IPv6 capable hosts
::1       localhost ip6-localhost ip6-loopback
fe00::0   ip6-localnet
ff00::0   ip6-mcastprefix
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF_HOSTS
}

set_nameserver () {
    for ((i = 1; i <= $#; i++)); do
        if (($i == 1)); then
            echo "nameserver ${!i}" > /etc/resolv.conf
        else
            echo "nameserver ${!i}" >> /etc/resolv.conf
        fi
    done
}

add_user() {
    adduser --gecos "${1}" --disabled-login "${1}" --uid 1000
    chown -R 1000:1000 /home/"${1}"
    echo "${1}:${1}" | chpasswd
    usermod -a -G sudo,adm,input,video,plugdev "${1}"
}

set_if_lo () {
    echo "auto lo" > /etc/network/interfaces.d/lo
    echo "iface lo inet loopback" >> /etc/network/interfaces.d/lo
}

set_if_dhcp() {
    echo "auto ${1}" > /etc/network/interfaces.d/"${1}"
    echo "iface ${1} inet dhcp" >> /etc/network/interfaces.d/"${1}"
}

set_if_wifi() {
    echo "8723bs" > /etc/modules-load.d/pine64-wifi.conf
    echo "blacklist 8723bs_vq0" > etc/modprobe.d/blacklist-pine64.conf
    cat > /etc/network/interfaces.d/wlan1 << EOF_WLAN1
# Disable wlan1 by default (8723bs has two intefaces)
iface wlan1 inet manual
EOF_WLAN1
}
##

## Main

locale-gen en_US.UTF-8

debian_apt_list "jessie"
set_hostname "pine64"
set_nameserver "8.8.8.8" "8.8.4.4"

add_user "debian"

# Debian chroot - https://wiki.debian.org/chroot
dpkg-divert --local --rename --add /sbin/initctl; ln -s /bin/true /sbin/initctl
export DEBIAN_FRONTEND=noninteractive

# Update
apt-get update

# network
set_if_lo
set_if_dhcp "eth0"
set_if_wifi

# systemd
systemctl enable eth0-mackeeper
systemctl enable cpu-corekeeper
systemctl enable ssh-keygen

# clean up
apt-get --purge autoremove
apt-get clean
rm /sbin/initctl; dpkg-divert --local --rename --remove /sbin/initctl

#### END OF INSIDE CHROOT ####
EOF

# un-registry aarch64
[ -f /proc/sys/fs/binfmt_misc/aarch64 ] && echo -1 | sudo tee /proc/sys/fs/binfmt_misc/aarch64

# post clean up
sudo rm -f "${ROOT_DIR}/usr/sbin/policy-rc.d"

# create fstab
sudo dd of="${ROOT_DIR}/etc/fstab" << EOF
# <file system>	<dir>	<type>	<options>			<dump>	<pass>
/dev/mmcblk0p1	/boot	vfat	defaults			0	2
/dev/mmcblk0p2	/	ext4	defaults,noatime		0	1
EOF
