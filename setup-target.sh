#!/bin/bash
DATA_DIR=/d/local/data/iscsi
TGT_SIZE="500"
MB=$((1024*1024))
YYMM=$(date +%Y-%m)
LUN_NAME="guest-docker"
TGT_DOMAIN="com.example.server"
TGT_IMG="${DATA_DIR}/${LUN_NAME}.img"
TGT_IQN="iqn.${YYMM}.${TGT_DOMAIN}:${LUN_NAME}"
TGT_XML="<target ${TGT_IQN}>\nbacking-store ${TGT_IMG}\nwrite-cache off\n</target>"
TGT_CONF="/etc/tgt/conf.d/${LUN_NAME}.conf"
PACKAGES=(open-iscsi tgt)
PORTAL=$(hostname)

dpkg -s "${PACKAGES[@]}" || apt-get install "${PACKAGES[@]}"

mkdir -p "${DATA_DIR}"

if [[ ! -f "${TGT_IMG}" ]]
then
    dd if=/dev/zero bs="${MB}" seek="${TGT_SIZE}" count=0 of="${TGT_IMG}"
fi

if [[ ! -f "${TGT_CONF}" ]]
then
    # tgtadm --lld iscsi --op new --mode target --tid 1 -T "${TGT_IQN}"
    # tgtadm --lld iscsi --op new --mode logicalunit --tid 1 --lun 1 -b "${TGT_IMG}"
    # tgtadm --lld iscsi --op show --mode target
    echo -e "${TGT_XML}" > "${TGT_CONF}"
fi

# Allow the target to accept any initiators (to accept guest VM)
tgtadm --lld iscsi --op bind --mode target --tid 1 -I ALL

systemctl restart tgt
tgt-admin --show

systemctl enable iscsid
systemctl start iscsid
iscsiadm --mode discovery --type sendtargets --portal $(hostname)

iscsiadm -m node -T "${TGT_IQN}" -p "${PORTAL}"

# Log out
iscsiadm -m node -T "${TGT_IQN}" -p "${PORTAL}" -u

# Log in
iscsiadm -m node -T "${TGT_IQN}" -p "${PORTAL}" -l

# Log out of all targets
iscsiadm -m node -U all

