#!/bin/bash
SCRIPT=$(readlink -f "${0}")
DIR="${SCRIPT%/*}"
VERBOSE="${VERBOSE:-0}"
cd "${DIR}" || exit 1

function msg()
{
    echo "${@}" 1>&2
}

function verb()
{
    (( VERBOSE )) && msg "${@}"
}

function run()
{
    msg "Run ${*}"
    "${@}"
}

function is-installed()
{
    dpkg -l "${1}" 2> /dev/null | egrep -q .
}

function apt-install()
{
    verb "${FUNCNAME[0]} ${*}"
    local p
    for p in "${@}"
    do
        is-installed "${p}" || run apt-get -y install "${p}"
    done
}

function apt-init()
{
    ls /var/lib/apt/lists/ | egrep -q . || run apt-get update
}

function enable-and-start()
{
    verb "${FUNCNAME[0]} ${*}"
    systemctl daemon-reload
    systemctl is-enabled "${1}" > /dev/null || run systemctl enable "${1}"
    systemctl is-active "${1}" > /dev/null || run systemctl start "${1}"
}
function disable-and-stop()
{
    verb "${FUNCNAME[0]} ${*}"
    systemctl daemon-reload
    systemctl is-enabled "${1}" > /dev/null && run systemctl disable "${1}"
    systemctl is-active "${1}" > /dev/null && run systemctl stop "${1}"
}

function deactivate-vbox()
{
    verb "Deactivate virtualbox guest agent"
    disable-and-stop vboxadd
    disable-and-stop vboxadd-service
}

function activate-qemu()
{
    verb "Activate qemu guest agent"
    if ! systemctl is-active qemu-guest-agent > /dev/null 2>&1
    then
        apt-install qemu-guest-agent
        run systemctl daemon-reload
        run udevadm trigger
    fi
}

deactivate-vbox
apt-init
activate-qemu

# Install gpm for convenience
apt-install gpm

# Install ethtool to support network device driver identification
apt-install ethtool

verb "Setup delay-net-stop"
# Set up a service for delaying the network stop so we can see what is happening during shutdown
install -m 755 delay-net-stop.sh /root/
install -m 644 delay-net-stop.service /etc/systemd/system/
#enable-and-start delay-net-stop

verb Disable standard debian networking
[[ -f /etc/network/interfaces ]] && mv /etc/network/interfaces /etc/network/interfaces.OLD
disable-and-stop networking.service
if ip link | egrep eth0
then
    run ip link set eth0 down
fi


verb "Setup systemd networking"
install -m 644 10-eth0.network /etc/systemd/network/
install -m 644 10-eth0.link /etc/systemd/network/
install -m 644 -D -t /etc/systemd/system/systemd-networkd.service.d systemd-networkd-debug.conf
enable-and-start systemd-networkd

if ! ip a | grep -q nic0
then
    udevadm trigger
    udevadm info /sys/class/net/eth0
    udevadm test /sys/class/net/eth0
    networkctl status
    networkctl list

    # Update the initrd so the network config comes up correctly the first time after a reboot
    verb "Rebuild initrd"
    run update-initramfs -u
fi


# Prepare iscsi for mounting a docker data partition
verb "Install iscsi"
apt-install open-iscsi
enable-and-start open-iscsi

verb "Set up iscsi portal and targets"
PORTAL=$(ip route | egrep default.via | awk '{print $3}')
if [[ -n "${PORTAL}" ]]
then

    echo "${PORTAL} portal" >> /etc/hosts

    apt-install xfsprogs

    verb "Set up iscsi discovery"
    install -m 0644 open-iscsi-discovery.service /etc/systemd/system

    verb "Set up guest-docker path"
    install -m 755 guest-docker.sh /root/
    install -m 644 guest-docker.service /etc/systemd/system
    install -m 644 guest-docker.path /etc/systemd/system
    verb "Start services"
    run systemctl daemon-reload
    enable-and-start guest-docker.path
    enable-and-start open-iscsi-discovery.service
fi

# Install docker and start a service that will be using the docker
# partition during a shutdown

verb "Setup docker"
apt-install docker.io

install -m 0644 -D -t /etc/systemd/system/docker.service.d docker-dropin.conf

enable-and-start docker

sleep 3


verb "Setup a long running docker service"
# Pre-pull the image
docker images | grep -q busybox || docker pull busybox:latest
install -m 755 long-runner.sh /root
install -m 644 long-runner.service /etc/systemd/system
enable-and-start long-runner.service

install -m 644 docker-stopped.service /etc/systemd/system
enable-and-start docker-stopped.service
