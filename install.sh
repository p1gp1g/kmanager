#!/bin/bash

source install.conf

exec 1<>$LOG_FILE
exec 3>/dev/tty

pstep () {
	echo "[+] $@" >&3;
}

pstep "Copying files"
sed -i "s|__CONF__|$CONF|" bin/*
cp bin/* "$BINDIR"
cp kmanager.conf $CONF

source $CONF

pstep "Initiating directories"
# init dirs
mkdir -p "$SYS_DIR" "$RW_DIR" "$TEMPLATE_DIR"
chattr -R +C "$SYS_DIR" "$RW_DIR" "$TEMPLATE_DIR" # disable CoW

pstep "Initiating database"
# init db
sqlite3 $DB << EOF
CREATE TABLE vms (id INTEGER PRIMARY KEY, name TEXT, port TEXT);
INSERT INTO vms(name,port) values ("template-$OS_VARIANT",$FIRST_PORT);
EOF

pstep "Initiating ssh key"
# init ssh key
[ -f "$HOME/.ssh/$SSH_KEY" ] || ssh-keygen -t ed25519 -N "" "$HOME/.ssh/$SSH_KEY"

pstep "Create template volumes"
# create template volumes
qemu-img create -f qcow2 "$TEMPLATE_DIR/$RW_TEMPLATE.bak" $RW_SIZE
qemu-img create -f qcow2 -F qcow2 -b "$TEMPLATE_DIR/$RW_TEMPLATE.bak" "$TEMPLATE_DIR/$RW_TEMPLATE" $RW_SIZE
qemu-img create -f qcow2 "$TEMPLATE_DIR/$SYS_TEMPLATE.bak" $SYS_SIZE
qemu-img create -f qcow2 -F qcow2 -b "$TEMPLATE_DIR/$SYS_TEMPLATE.bak" "$TEMPLATE_DIR/$SYS_TEMPLATE" $SYS_SIZE

pstep "Format rw template volume"
# format rw volume
virt-format --filesystem=btrfs -a "$TEMPLATE_DIR/$RW_TEMPLATE"
guestfish -a "$TEMPLATE_DIR/$RW_TEMPLATE" << EOF
run
mount /dev/sda1 /
btrfs-subvolume-create /home
btrfs-subvolume-create /rw
EOF

pstep "Create template VM"
# create template VM
virt-install --import --name template-$OS_VARIANT \
  --virt-type kvm \
  --memory 4096 --vcpus 8 --cpu host \
  --disk "$TEMPLATE_DIR/$SYS_TEMPLATE" \
  --cdrom "$INSTALL_ISO" \
  --os-type=linux \
  --os-variant=$OS_VARIANT \
  --graphics spice \
  --noautoconsole

cat << EOF >&3
[+] template-$OS_VARIANT has started, please install the OS on it.
[!] You may need to start once the template after installation.

* Create the user "user" during the installation.
* Execute the following 2 commands
sudo touch /etc/rc.d/rc.local
sudo chmod 770 /etc/rc.d/rc.local

[!] Once done, run ./init_template.sh to finish the installation.
EOF
