RUNLEVEL=1 apt-get -y -t jessie-backports --no-install-recommends install libseccomp2 aufs-tools xz-utils cgroupfs-mount git ca-certificates

DOCKER_VER="v1.13.0"

# use prebuild docker for aarch64
curl -sLk https://github.com/yang-l/pine64-docker/raw/"${DOCKER_VER}"/docker.tar.xz | tar -C /usr/bin/ -xJpf -

# setup systemd unit files
curl -sLk https://github.com/docker/docker/raw/"${DOCKER_VER}"/contrib/init/systemd/docker.service -o /etc/systemd/system/docker.service
curl -sLk https://github.com/docker/docker/raw/"${DOCKER_VER}"/contrib/init/systemd/docker.socket -o /etc/systemd/system/docker.socket
chmod 664 /etc/systemd/system/docker.{service,socket}

# create "docker" group
groupadd docker
usermod -aG docker debian
