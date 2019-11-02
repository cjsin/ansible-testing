#!/bin/bash

watch_dir="/var/lib/docker/overlay2"

function del_mounts()
{
    local patterns=()
    local p
    for p in "${@}"
    do
        patterns+=("-e" "\\%${p}% d")
    done

    sed -i -r "${patterns[@]}" /etc/fstab
}

function mount_pattern()
{
    local pattern=""
    local p
    for p in "${@}"
    do
        pattern+="${pattern:+|}${p}"
    done
    echo "[[:space:]](${pattern})[[:space:]]"
}

function run()
{
    echo "${@}" 1>&2
    "${@}"
}

function add_mounts()
{
    # Take the mount lines from /proc/mounts but append _netdev to the mount options,
    # and add these lines to the fstab
    run sed -n -r -e "\\%$(mount_pattern "${@}")% { s/[[:space:]]+0 0$/,noauto,_netdev 0 0/; p; } " < /proc/mounts >> /etc/fstab
}

function react()
{
    local -a proc_mounts=( $(grep "${watch_dir}/" /proc/mounts | awk '{print $2}' | sort) )
    local -a fstab_mounts=( $(grep "${watch_dir}/" /etc/fstab  | awk '{print $2}' | sort) )

    local to_del=()
    local to_add=()

    while (( ${#proc_mounts[@]} + ${#fstab_mounts[@]} ))
    do
        p="${proc_mounts[0]}"
        f="${fstab_mounts[0]}"
        if [[ -z "${p}" ]] && [[ -z "${f}" ]]
        then
            break
        elif [[ -z "${p}" ]]
        then
            # Ran out of proc mounts - all remaining fstab mounts must be deleted
            to_del+=("${fstab_mounts[@]}")
            break
        elif [[ "${f}" != "${p}" ]]
        then
            if [[ -z "${f}" ]]
            then
                # Ran out of fstab mounts - all remaining proc mounts must be added
                to_add+=("${proc_mounts[@]}")
                break
            else
                # This proc mount is not in fstab yet
                to_add+=("${p}")
                proc_mounts=("${proc_mounts[@]:1}")
            fi
        else
           # p and f match. pop the top element off both lists
           fstab_mounts=("${fstab_mounts[@]:1}")
           proc_mounts=("${proc_mounts[@]:1}")
        fi
    done

    if (( ${#to_del[@]} ))
    then
        del_mounts "${to_del[@]}"
    fi

    if (( ${#to_add[@]} ))
    then
        add_mounts "${to_add[@]}"
    fi

    systemctl daemon-reload

    systemctl list-units | egrep 'var-lib-docker-overlay2.*[.]mount'
}

function watch_for_changes()
{
    local last_content=""
    local content=""
    while (( 1 ))
    do
        content=$(grep "${watch_dir}" /proc/mounts)
        [[ "${content}" != "${last_content}" ]] && react
        last_content="${content}"
        sleep 5
    done
}

watch_for_changes
