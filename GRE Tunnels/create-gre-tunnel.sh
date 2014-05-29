# Create ovs bridge, add eth0:
ovs-vsctl add-br br-eth0

# Set IP configuration to ovs bridge interface (br-eth0) instead of eth0 and restart network after settings are changed
# Consider setting MTU to 1546 to interface or reduce it to 1454 in the domains
ovs-vsctl add-port br-eth0 eth0 && service network restart

# Create internal ovs bridge and set GRE tunnel endpoints:
ovs-vsctl add-br br-int0
ovs-vsctl add-port br-int0 gre0 -- set interface gre0 type=gre options:remote_ip=192.168.2.1
ovs-vsctl add-port br-int0 gre1 -- set interface gre1 type=gre options:remote_ip=192.168.2.3

# Enable STP (needed for more than 2 hosts):
ovs-vsctl set bridge br-int0 stp_enable=true

# Endpoints for the GRE tunnels can be set in VMs with libvirt as described in libvirt-vlans.xml.example
# Local endpoints on hosts can be set too. For example if we need VLAN support:
ovs-vsctl add-port br-int0 vlan100 tag=100 -- set Interface vlan100 type=internal
ifconfig vlan100 172.16.0.5
