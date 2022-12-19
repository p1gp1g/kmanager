#!/bin/bash

source install.conf
source $CONF

exec 1<>$LOG_FILE
exec 3>/dev/tty

pstep () {
  echo "[+] $@" >&3;
}

pstep "Preparing template"
RW_UUID=$(virt-filesystems -a $TEMPLATE_DIR/$RW_TEMPLATE -l --uuid | awk 'END{print $7}')
virt-sysprep -d template-$OS_VARIANT \
  --mkdir "/rw" \
  --edit '/etc/fstab:$_ = "" if /subvol=home/' \
  --edit '/etc/sudoers:s/^%wheel\tALL=\(ALL\)\tALL$/# %wheel\tALL=\(ALL\)\tALL/' \
  --edit '/etc/sudoers:s/^# %wheel\tALL=\(ALL\)\tNOPASSWD: ALL$/%wheel\tALL=\(ALL\)\tNOPASSWD: ALL/' \
  --append-line "/etc/fstab:UUID=$RW_UUID /home                       btrfs   subvol=home,compress=zstd:1 0 0" \
  --append-line "/etc/fstab:UUID=$RW_UUID /rw                         btrfs   subvol=rw,compress=zstd:1   0 0" 

pstep "Undefining template-$OS_VARIANT"
virsh undefine template-$OS_VARIANT

pstep "Adding ssh authorized keys"
SYS_TEMPLATE=$(sqlite3 $DB "SELECT name FROM templates ORDER BY id DESC LIMIT 1;")
mkdir -p ./mnt_rw ./mnt_sys
guestmount -a "$TEMPLATE_DIR/$RW_TEMPLATE" -m /dev/sda1 -o uid=$(id -u) -o gid=$(id -g) ./mnt_rw
guestmount -a "$TEMPLATE_DIR/$SYS_TEMPLATE" -m /dev/sda2:/:subvol=home ./mnt_sys
cp -r ./mnt_sys/user ./mnt_rw/home/user || mkdir ./mnt_rw/home/user
chown -R 1000:1000 ./mnt_rw/home/user
mkdir -p ./mnt_rw/home/user/.ssh
cp "$HOME/.ssh/$SSH_KEY.pub" ./mnt_rw/home/user/.ssh/authorized_keys
chown -R 1000:1000 ./mnt_rw/home/user/.ssh
chmod -R 500 ./mnt_rw/home/user/.ssh

if [ -f "./firstboot.sh" ]; then
pstep "Uploading firstboot.sh"
cp ./firstboot.sh ./mnt_rw/rw/
fi

guestunmount ./mnt_sys
guestunmount ./mnt_rw

pstep "Done!"
