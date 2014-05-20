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
#    <interface type='network'>
#      <source network='ovs-network' portgroup='no-vlan'/>
#      <model type='virtio'/>
#    </interface>
#    <interface type='network'>
#      <source network='ovs-network' portgroup='vlan-100'/>
#      <model type='virtio'/>
#   </interface>
#    <interface type='network'>
#      <source network='ovs-network' portgroup='vlan-200'/>
#      <model type='virtio'/>
#   </interface>
#
# Note that the order above makes eth0 in the no-vlan network, eth1 in the vlan-100 network and eth2 in the vlan-200 network.
#
# To boot from the network add this to the <os> section
#
#    <boot dev='network'/>
#    <boot dev='hd'/>
#
# Create a pool to be able to use qcow2: virsh pool-define-as --name VMs-pool --type dir --target /home/VMs/pool/

virt-install \
--name foreman-rhel \
--ram 1024 \
--vcpus=1 \
--disk size=20,format=qcow2,pool=VMs-pool \
--nonetworks \
--cdrom /home/VMs/ISOs/rhel-server-6.5-x86_64-dvd.iso \
--graphics vnc,listen=0.0.0.0,keymap=en_gb --noautoconsole --hvm \
--os-variant rhel6
