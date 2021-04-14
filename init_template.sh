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
  --append-line "/etc/fstab:UUID=$RW_UUID /rw                         btrfs   subvol=rw,compress=zstd:1   0 0" \
  --append-line "/etc/rc.d/rc.local:#!/bin/bash" \
  --append-line "/etc/rc.d/rc.local:[ -x /rw/rc.local ] && /rw/rc.local" \
  --append-line "/etc/rc.d/rc.local:/usr/bin/systemctl enable --now sshd #1del" \
  --append-line "/etc/rc.d/rc.local:/usr/sbin/restorecon /home/user/.ssh/authorized_keys #1del" \
  --append-line "/etc/rc.d/rc.local:sed -i '"'/#1del$/d'"' /etc/rc.d/rc.local #1del" \

pstep "Undefining template-$OS_VARIANT"
#virsh undefine template-$OS_VARIANT

pstep "Adding ssh authorized keys"
mkdir -p ./mnt_rw ./mnt_sys
guestmount -a "$TEMPLATE_DIR/$RW_TEMPLATE" -m /dev/sda1:/:subvol=home -o uid=$(id -u) -o gid=$(id -g) ./mnt_rw
guestmount -a "$TEMPLATE_DIR/$SYS_TEMPLATE" -m /dev/sda2:/:subvol=home ./mnt_sys
cp -r ./mnt_sys/user ./mnt_rw/user
chown -R 1000:1000 ./mnt_rw/user
mkdir -p ./mnt_rw/user/.ssh
cp "$HOME/.ssh/$SSH_KEY.pub" ./mnt_rw/user/.ssh/authorized_keys
chown -R 1000:1000 ./mnt_rw/user/.ssh
chmod -R 500 ./mnt_rw/user/.ssh

guestunmount ./mnt_rw
guestunmount ./mnt_sys

pstep "Done!"
