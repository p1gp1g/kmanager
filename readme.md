
## Moving from qemu://session to qemu://system

You may need some right changes on the volumes. You may want to change the VM name to have a system and a session VM.
```
virsh dumpxml > name.xml
sudo virsh define name.xml
```

## Rebase the template

```
cd ~/.kmanager/templates		# go to your template dir
cp template-last.qcow2 template-tmp.qcow2		# copy last template file
qemu-img create -f qcow2 empty.qcow2 15G		# create an empty image if it doesn't exist
qemu-img rebase -f qcow2 -F qcow2 -b empty.qcow2 template-tmp.qcow2		# rebase the temp file to the empty
mv template-tmp.qcow2 template-last.qcow2		# set the rebased back
# kcreate tmp && kupdate tmp && kdelete tmp # if you want to update all system images
# sqlite3 vms.db "DELETE FROM templates WHERE id!=(SELECT MAX(id) FROM templates);"		# if you want to clean your db
```
