#! /bin/bash

set -e -v

DOCKER_VERSION=18.06.3~ce~3-0~ubuntu
KERNEL_VER=4.4.0-1014-aws
V4L2LOOPBACK_VERSION=0.10.0

lsb_release -a

# add docker group and add current user to it
sudo groupadd -f docker

# Make sure we use add the calling user to docker
# group. If the the script itself is called with sudo,
# we must use SUDO_USER, otherwise, use USER.
if [ -z "${VAGRANT_PROVISION}" ]; then
    user=$USER
else
    user=$SUDO_USER
fi

sudo usermod -a -G docker $user

[ -e /usr/lib/apt/methods/https ] || {
  apt-get install apt-transport-https
}

sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:taskcluster/ppa

# Add docker gpg key and update sources
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
sudo sh -c 'echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu trusty stable" \
  > /etc/apt/sources.list.d/docker.list'

# Add kernel debug info for SystemTap
# Ref: https://wiki.ubuntu.com/Kernel/Systemtap
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C8CAB6595FDFF622
codename=$(lsb_release -c | awk  '{print $2}')
sudo tee /etc/apt/sources.list.d/ddebs.list << EOF
deb http://ddebs.ubuntu.com/ ${codename}      main restricted universe multiverse
#deb http://ddebs.ubuntu.com/ ${codename}-security main restricted universe multiverse
deb http://ddebs.ubuntu.com/ ${codename}-updates  main restricted universe multiverse
deb http://ddebs.ubuntu.com/ ${codename}-proposed main restricted universe multiverse
EOF

## Update to pick up new registries
sudo apt-get update -y

# Upgrade to the latest kernel from the base image. If not, a bug in apt-get remove
# may install a newer kernel after we remove the old one
sudo apt-get install -yq unattended-upgrades
sudo unattended-upgrades
sudo apt-get autoremove -y

# Uninstall base-image kernels
sudo DEBIAN_FRONTEND=noninteractive apt-get remove -yq \
    $(ls -1 /boot/vmlinuz-*{aws,gcp} | sed -e 's,/boot/vmlinuz,linux-image,')

# Update kernel
# We install the generic kernel because it has the V4L2 driver
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
    linux-image-$KERNEL_VER \
    linux-image-$KERNEL_VER-dbgsym \
    linux-headers-$KERNEL_VER \
    dkms

# Clean up old 3.13 kernel.
sudo apt-get remove -y linux-image-extra-virtual
sudo apt-get autoremove -y

## Install all the packages
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq \
    docker-ce=$DOCKER_VERSION \
    lvm2 \
    curl \
    build-essential \
    git-core \
    gstreamer0.10-alsa \
    gstreamer0.10-plugins-bad \
    gstreamer0.10-plugins-base \
    gstreamer0.10-plugins-good \
    gstreamer0.10-plugins-ugly \
    gstreamer0.10-tools \
    pbuilder \
    python-mock \
    python-configobj \
    python-support \
    cdbs \
    python-pip \
    jq \
    rsyslog-gnutls \
    openvpn \
    lxc \
    rng-tools \
    systemtap \
    liblz4-tool

# Remove apport because it prevents obtaining crashes from containers
# and because it may send data to Canonical.
sudo apt-get purge -y apport

# Clone and build Zstandard
sudo git clone https://github.com/facebook/zstd /zstd
cd /zstd
# Corresponds to v1.3.3.
sudo git checkout f3a8bd553a865c59f1bd6e1f68bf182cf75a8f00
sudo make zstd
sudo mv zstd /usr/bin
cd /
sudo rm -rf /zstd

if [ -z "${VAGRANT_PROVISION}" ]; then
    ## Clear mounts created in base image so fstab is empty in other builds...
    sudo sh -c 'echo "" > /etc/fstab'
fi

## Install v4l2loopback
cd /usr/src
sudo rm -rf v4l2loopback-$V4L2LOOPBACK_VERSION
sudo git clone --branch v$V4L2LOOPBACK_VERSION https://github.com/umlaeute/v4l2loopback.git v4l2loopback-$V4L2LOOPBACK_VERSION
cd v4l2loopback-$V4L2LOOPBACK_VERSION
sudo dkms install -m v4l2loopback -v $V4L2LOOPBACK_VERSION -k ${KERNEL_VER}
sudo dkms build -m v4l2loopback -v $V4L2LOOPBACK_VERSION -k ${KERNEL_VER}

echo "v4l2loopback" | sudo tee --append /etc/modules

sudo sh -c 'echo "options v4l2loopback devices=100" > /etc/modprobe.d/v4l2loopback.conf'

# Install Audio loopback devices
echo "snd-aloop" | sudo tee --append /etc/modules
sudo sh -c 'echo "options snd-aloop enable=1,1,1,1,1,1,1,1 index=0,1,2,3,4,5,6,7" > /etc/modprobe.d/snd-aloop.conf'

# For some unknown reason, the kernel doesn't load snd-aloop even with
# it listed in /etc/modules, with no trace in dmesg. We put it here to make
# sure it is loaded during system startup.
sudo bash -c 'cat > /etc/rc.local <<EOF
#!/bin/sh -e
modprobe snd-aloop
exit 0
EOF'
sudo chmod +x /etc/rc.local

# Do one final package cleanup, just in case.
sudo apt-get autoremove -y
