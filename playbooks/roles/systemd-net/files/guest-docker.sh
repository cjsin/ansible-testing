#!/bin/bash

label="guest-docker"
fs_type="xfs"
mount_options="defaults,noauto,_netdev"
mount_point="/var/lib/docker"
dev_by_path=""
dev=""

function msg()
{
    echo "${*}" 1>&2
}

function err()
{
    msg "ERROR:" "${@}"
}

function inf()
{
    msg "INFO:" "${@}"
}

function check_dev()
{
    dev_by_path=$(ls "/dev/disk/by-label/${label}" 2> /dev/null | head -n1)
    if [[ -z "${dev_by_path}" ]]
    then
        err "No device found for label ${label}"
        return 1
    fi

    dev=$(readlink -f "${dev_by_path}")

    if [[ -z "${dev}" ]]
    then
        err "No device resolved for ${dev_by_path} ."
        return 1
    fi
}

function check_mounted()
{
    if egrep -q "^${dev} " /proc/mounts
    then
        inf "Already mounted."
        return 0
    else
        return 1
    fi
}

function check_mkfs()
{
    if ! lsblk -n -o label "${dev}" | grep -x "${label}"
    then
        inf "Create filesystem ${label} on ${dev} ."
        if ! "mkfs.${fs_type}" -L "${label}" "${dev}"
        then
            err "Filesystem creation failed."
            return 1
        fi
    fi
}

function check_fstab()
{
    local fstab_line="LABEL=${label} ${mount_point} ${fs_type} ${mount_options} 0 0"
    if ! grep -qF "${fstab_line}" /etc/fstab
    then
        sed -i "/LABEL=${label}[[:space:]]/ d" /etc/fstab
        inf "Add to fstab."
        echo "${fstab_line}" >> /etc/fstab
        systemctl daemon-reload
    fi
}

function toolish_xfs_process()
{
    if ! xfs_repair "${dev}"
    then
        local tmp_mount="/mnt/${label}-fs-check"
        mkdir -p "${tmp_mount}"
        # xfs will replay logs when mounted.
        mount "${dev}" "${tmp_mount}" || echo "Mount ${dev} failed."
        # now unmount for the xfs_repair to run
        umount "${dev}"
        rmdir "${tmp_mount}"
        xfs_repair "${dev}"
    fi
}

function run_fsck()
{
    case "${fs_type}"
    in
        xfs)
            toolish_xfs_process "${dev}"
            ;;
        *)
            fsck "${dev}"
            ;;
    esac
}

function check_filesystem()
{
    inf "Check filesystem"

    if ! run_fsck
    then
        err "Filesystem check failed!"
        return 1
    fi
}

function mount_filesystem()
{
    if ! mkdir -p "${mount_point}"
    then
        err "Could not create ${mount_point} ."
        return 1
    fi
    if ! mount "${dev}"
    then
        err "Failed mounting ${dev} ."
        return 1
    fi
}

check_dev        || exit 1
check_mounted    && exit 0
#check_mkfs       || exit 1
check_fstab
check_filesystem || exit 1

systemctl start guest-docker.mount
#mount_filesystem || exit 1
