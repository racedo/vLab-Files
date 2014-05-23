# If using foreman as the gateway set it here.
# The dhcpd.conf needs to be changed anyway

# PROVISIONING_INTERFACE only on RDO, RH-OSP 4 doesn't use it. Probably RH-OSP 5 will.
export PROVISIONING_INTERFACE=eth1
export FOREMAN_GATEWAY=172.16.0.254
export FOREMAN_PROVISIONING=true

# Then execute the installer from its location:
cd /usr/share/openstack-foreman-installer/bin
sh foreman_server.sh
