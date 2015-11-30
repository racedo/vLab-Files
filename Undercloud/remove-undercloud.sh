# This assumes you have /root/ifcfg-eth0.static with the IP on eth0, i.e.:
# TYPE=Ethernet
# BOOTPROTO=none
# DEFROUTE=yes
# NAME=eth0
# DEVICE=eth0
# ONBOOT=yes
# IPADDR=10.0.0.10
# PREFIX=24

sudo yum -y remove "openstack*" python-rdomanager-oscplugin puppet haproxy mariadb rabbitmq-server "*swift*"
sudo rm -rf /tftpboot/ /httpboot/ /var/lib/mysql/ /etc/ironic* /etc/ceilometer /etc/neutron/ /etc/glance/ /etc/keystone/ /etc/nova/ /etc/puppet/ /home/stack/undercloud-passwords.conf /etc/haproxy /var/lib/rabbitmq /home/stack/.instack /var/log/keystone /var/log/nova /var/log/ironic* /var/log/glance /var/log/neutron /var/log/ceilometer /var/log/heat /etc/swift /var/log/swift /srv/node/*
sudo ifdown br-ctlplane
sudo rm -f /etc/sysconfig/network-scripts/ifcfg-br-ctlplane
sudo cp -f /root/ifcfg-eth0.static /etc/sysconfig/network-scripts/ifcfg-eth0
sudo ovs-vsctl del-br br-int
sudo systemctl stop iptables
sudo rm /etc/sysconfig/iptables
sudo systemctl start iptables
sudo systemctl restart network
