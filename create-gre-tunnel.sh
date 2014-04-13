# Create ovs bridge, add eth0
ovs-vsctl add-br br-eth0

# Set IP configuration to ovs bridge interface (br-eth0) instead of eth0 and restart network after settings are changed
# Consider setting MTU to 1546 to interface or reduce it to 1454 in the domains
ovs-vsctl add-port br-eth0 eth0 && service network restart

# Create internal ovs bridge and set GRE tunnel endpoint
ovs-vsctl add-br br-int0
ovs-vsctl add-port br-int0 gre0 -- set interface gre0 type=gre options:remote_ip=192.168.2.1
