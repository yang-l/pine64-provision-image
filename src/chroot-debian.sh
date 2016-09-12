#!/usr/bin/env bash

source ./src/config.sh
set -x

# prevent dpkg to start daemons
sudo dd of="${ROOT_DIR}/usr/sbin/policy-rc.d" << EOF
#!/bin/sh
exit 101
EOF
sudo chmod a+x "${ROOT_DIR}/usr/sbin/policy-rc.d"

# copy static qemu emulation
sudo cp ./qemu-bin/qemu-aarch64-static "${ROOT_DIR}/usr/bin" || exit 1
sudo cp ./qemu-bin/qemu-x86_64-static "${ROOT_DIR}/usr/bin" || exit 1
[ "$(uname -m)" == "x86_64" ] && [ -f /proc/sys/fs/binfmt_misc/aarch64 ] || { echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/usr/bin/qemu-aarch64-static:' | sudo tee /proc/sys/fs/binfmt_misc/register || exit 1 ; }

# copy ssh pubkey
[ -s "${CONF_DIR}/id_rsa_debian.pub" ] && { sudo cp "${CONF_DIR}/id_rsa_debian.pub" "${ROOT_DIR}" || exit 1 ; }

# chroot / mount
do_chroot() {
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/mount -t proc proc /proc
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/mount -t sysfs sys /sys
    sudo mount --rbind /dev/pts "${ROOT_DIR}"/dev/pts
    sudo mount --rbind /tmp "${ROOT_DIR}"/tmp
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/bash "$@"
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/umount /proc
    sudo LC_ALL=C LANGUAGE=C LANG=C chroot "${ROOT_DIR}" qemu-aarch64-static /bin/umount /sys
    sudo umount "${ROOT_DIR}"/dev/pts
    sudo umount "${ROOT_DIR}"/tmp
}

# chroot / debootstrap second-stage
do_chroot /debootstrap/debootstrap --second-stage

# chroot / create scripts
# copy docker installation script
if [ "${INSTALL_DOCKER}" = true ]
then
    yes | sudo cp -av "${SRC_DIR}"/docker-debian.sh "${ROOT_DIR}/usr/local/sbin"
fi

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

sudo dd of="${ROOT_DIR}/etc/locale.nopurge.template" << EOF
####################################################
# This is the configuration file for localepurge(8).
####################################################

####################################################
# Uncommenting this string enables the use of dpkg's
# --path-exclude feature.  In this mode, localepurge
# will configure dpkg to exclude the desired locales
# at unpack time.
#
# If enabled, the following 3 options will be
# disabled:
#
#  QUICKNDIRTYCALC
#  SHOWFREEDSPACE
#  VERBOSE
#
# And the following option will be enabled and cannot
# be disabled (unless USE_DPKG is disabled):
#
#  DONTBOTHERNEWLOCALE
#

#USE_DPKG
####################################################

####################################################
# Uncommenting this string enables removal of localized
# man pages based on the configuration information for
# locale files defined below:

MANDELETE

####################################################
# Uncommenting this string causes localepurge to simply delete
# locales which have newly appeared on the system without
# bothering you about it:

DONTBOTHERNEWLOCALE

####################################################
# Uncommenting this string enables display of freed disk
# space if localepurge has purged any superfluous data:

SHOWFREEDSPACE

#####################################################
# Commenting out this string enables faster but less
# accurate calculation of freed disk space:

#QUICKNDIRTYCALC

#####################################################
# Commenting out this string disables verbose output:

#VERBOSE

#####################################################
# Following locales won't be deleted from this system
# after package installations done with apt-get(8):

en
en_US.UTF-8
EOF

# chroot
do_chroot << "EOF"
#### INSIDE CHROOT ####

## Common functions
set_locale () {
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    debconf-set-selections <<< "locales locales/default_environment_locale select en_US.UTF-8"
    dpkg-reconfigure -f noninteractive locales
}

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
debian_apt_list "jessie"
set_hostname "pine64"
set_nameserver "8.8.8.8" "8.8.4.4"
add_user "debian"

# Do not (re)start service in chroot
dpkg-divert --local --rename --add /sbin/initctl; ln -s /bin/true /sbin/initctl
dpkg-divert --local --rename --add /sbin/start-stop-daemon; ln -s /bin/true /sbin/start-stop-daemon
dpkg-divert --local --rename --add /usr/sbin/service; ln -s /bin/true /usr/sbin/service

export DEBIAN_FRONTEND=noninteractive

# Update
apt-get update

# Install packages
RUNLEVEL=1 apt-get -y --no-install-recommends install curl ethtool ifupdown localepurge locales lsof lvm2 ntp openssh-server sudo

# locale / localepurge
set_locale
mv /etc/locale.nopurge.template /etc/locale.nopurge
localepurge

# Docker
if [ -e "/usr/local/sbin/docker-debian.sh" ]
then
    bash -x /usr/local/sbin/docker-debian.sh
    rm -f /usr/local/sbin/docker-debian.sh
fi

if [ -s "/id_rsa_debian.pub" ]
then
    # password-less sudo
    echo "debian    ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/pwdless_debian

    # copy ssh key
    mkdir -p /home/debian/.ssh
    chown debian.debian /home/debian/.ssh
    cat /id_rsa_debian.pub >> /home/debian/.ssh/authorized_keys
    chmod 600 /home/debian/.ssh/authorized_keys
    rm /id_rsa_debian.pub
fi

# network
set_if_lo
set_if_dhcp "eth0"
set_if_wifi

# systemd
systemctl enable eth0-mackeeper
systemctl enable cpu-corekeeper
systemctl enable ssh-keygen

# /etc/mtab symbol link
ln -snf /proc/self/mounts /etc/mtab

# set right permission
chmod 755 /usr/bin/qemu-x86_64-static

## rc.local / manual modifications
sed -i 's/^exit 0$//' /etc/rc.local

# pine64 gb ethernet workaround
echo 'ethtool -s eth0 speed 100 duplex full' >> /etc/rc.local

# add qemu-x86_64 to run x86_64 program
echo "echo ':x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xfe\xfe\xfc\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-x86_64-static:' > /proc/sys/fs/binfmt_misc/register" >> /etc/rc.local

echo 'exit 0' >> /etc/rc.local
##

# clean up
apt-get --purge autoremove
apt-get clean
rm -f /etc/ssh/ssh_host_*
rm /sbin/initctl; dpkg-divert --local --rename --remove /sbin/initctl
rm /sbin/start-stop-daemon; dpkg-divert --local --rename --remove /sbin/start-stop-daemon
rm /usr/sbin/service; dpkg-divert --local --rename --remove /usr/sbin/service

#### END OF INSIDE CHROOT ####
EOF

# un-registry aarch64
[ -f /proc/sys/fs/binfmt_misc/aarch64 ] && echo -1 | sudo tee /proc/sys/fs/binfmt_misc/aarch64
sudo rm "${ROOT_DIR}/usr/bin/qemu-aarch64-static"

# post clean up
sudo rm -f "${ROOT_DIR}/usr/sbin/policy-rc.d"

# create fstab
sudo dd of="${ROOT_DIR}/etc/fstab" << EOF
# <file system>	<dir>	<type>	<options>			<dump>	<pass>
/dev/mmcblk0p1	/boot	vfat	defaults			0	2
/dev/mmcblk0p2	/	ext4	defaults,data=writeback,noatime,nodiratime		0	1
EOF
