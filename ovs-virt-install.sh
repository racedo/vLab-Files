# If using directly a Open vSwitch bridge add this to the domain:
#
# <interface type='bridge'>
#    <source bridge='br-int0'/>
#    <virtualport type='openvswitch' />
#    <model type='virtio'/>
# </interface>
# 
# If using a Open vSwitch network previously defined with virsh add this to the domain:
#
# <interface type='network'>
#    <source network='ovs-network' portgroup='vlan-02'/>
#    <model type='virtio'/>
# </interface>

virt-install \
--name foreman \
--ram 1024 \
--vcpus=1 \
--disk path=/home/VMs/foreman.img,size=20 \
--nonetworks \
--cdrom /home/VMs/ISOs/rhel-server-6.5-x86_64-dvd.iso \
--graphics vnc,listen=0.0.0.0,keymap=en_gb --noautoconsole --hvm \
--os-variant rhel6
