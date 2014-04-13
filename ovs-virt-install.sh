# Change after creation to openvswitch with virsh edit
# <interface type='bridge'>
#   <source bridge='br-int0'/>
#   <virtualport type='openvswitch' />
#   <model type='virtio'/>
# </interface>

virt-install \
--name foreman \
--ram 1024 \
--vcpus=1 \
--disk path=/home/VMs/foreman.img,size=20 \
--nonetworks \
--cdrom /home/VMs/rhel-server-6.5-x86_64-dvd.iso \
--graphics vnc,listen=0.0.0.0,keymap=en-uk --noautoconsole --hvm \
--os-variant rhel6
