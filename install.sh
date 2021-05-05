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
mkdir -p "$SYS_DIR" "$RW_DIR" "$TEMPLATE_DIR"
chattr -R +C "$SYS_DIR" "$RW_DIR" "$TEMPLATE_DIR" # disable CoW

pstep "Initiating ssh key"
[ -f "$HOME/.ssh/$SSH_KEY" ] || ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/$SSH_KEY"

pstep "Initiating database"
SYS_TEMPLATE="template-$OS_VARIANT-$(date "+%Y-%m-%d_%H%M").qcow2"
sqlite3 $DB << EOF
CREATE TABLE vms (id INTEGER PRIMARY KEY, name TEXT, port TEXT);
CREATE TABLE templates (id INTEGER PRIMARY KEY, name TEXT, date TEXT);
INSERT INTO templates (name, date) VALUES ("$SYS_TEMPLATE","$(date)");
EOF

pstep "Create template volumes"
qemu-img create -f qcow2 "$TEMPLATE_DIR/$RW_TEMPLATE" $RW_SIZE
qemu-img create -f qcow2 "$TEMPLATE_DIR/$SYS_TEMPLATE" $SYS_SIZE

pstep "Format rw template volume"
virt-format --filesystem=btrfs -a "$TEMPLATE_DIR/$RW_TEMPLATE"
guestfish -a "$TEMPLATE_DIR/$RW_TEMPLATE" << EOF
run
mount /dev/sda1 /
btrfs-subvolume-create /home
btrfs-subvolume-create /rw
EOF

pstep "Create template VM"
virt-install --import --name template-$OS_VARIANT \
  --virt-type kvm \
  --memory 4096 --vcpus 8 --cpu host \
  --disk "$TEMPLATE_DIR/$SYS_TEMPLATE" \
  --cdrom "$INSTALL_ISO" \
  --os-type=linux \
  --os-variant=$OS_VARIANT \
  --graphics spice \
  --noautoconsole || exit 1

cat << EOF >&3
[+] template-$OS_VARIANT has started, please install the OS on it.
[!] You may need to start once the template after installation.

* Create the user "user" during the installation.
* Execute the following 2 commands
sudo touch /etc/rc.d/rc.local
sudo chmod 770 /etc/rc.d/rc.local

[!] Once done, run ./init_template.sh to finish the installation.
EOF
