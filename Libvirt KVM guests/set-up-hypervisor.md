#Deploying VMs in KVM

###Purpose

This document describes how to setup a standlone hypervisor with RHEL and KVM where the guests network is managed by Open vSwitch and the guests are built from the RHEL qcow2 image

The host has 3 interfaces: eth0, eth1 and eth2, where eth1 and eth2 form a bond device (bond0)

The guests will have 2 interfaces: eth0 connected to the hosts eth0 via Open vSwitch and eth1 connected to bond0 also via Open vSwitch

### 1. Subscribe to the right channels:
```
subscription-manager register --auto-attach
subscription-manager repos --disable=*
subscription-manager repos --enable rhel-7-server-rpms --enable rhel-7-server-optional-rpms --enable rhel-7-server-openstack-6.0-rpms --enable rhel-server-rhscl-7-rpms
```
### 2. Install the dependencies:
```
yum -y install virt-install openvswitch qemu-kvm-rhev libvirt libguestfs-tools-c
```
### 3. Enable and start Open vSwitch and libvirtd
```
systemctl enable openvswitch
systemctl start openvswitch
systemctl enable libvirtd
systemctl start libvirtd
```
### 4. Create the Open vSwitch bridges for eth0 and bond0
```
ovs-vsctl add-br br-eth0
ovs-vsctl add-br br-bond0
```
### 5. Make eth0 and bond0 ports of the bridges just created
Note that the network settings that would be set in eth0 are set in br-eth0 as eth0 becomes a port.
```
vi /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-eth0
BOOTPROTO="none"
ONBOOT="yes"

vi /etc/sysconfig/network-scripts/ifcfg-br-eth0
DEVICE=br-eth0
TYPE=OVSBridge
ONBOOT=yes
BOOTPROTO=none
IPADDR0=10.0.0.200
PREFIX0=24
GATEWAY=10.0.0.2
DNS1=10.0.0.2

ovs-vsctl add-port br-eth0 eth0 ; ifdown eth0 ; ifup eth0
```
```
vi /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-bond0
ONBOOT=yes
BOOTPROTO=static
USERCTL=no
NM_CONTROLLED=no
BONDING_OPTS="mode=1 primary=eth1 miimon=100"

vi /etc/sysconfig/network-scripts/ifcfg-br-bond0
DEVICE=br-bond0
TYPE=OVSBridge
ONBOOT=yes
BOOTPROTO=none
PREFIX0=24

ovs-vsctl add-port br-eth0 eth0 ; ifdown bond0 ; ifup bond0
```
### 5. Delete the default libvirt network
```
virsh net-destroy default
virsh net-autostart --disable default
virsh net-undefine default
```
### 6. Create the two network definitions needed for libvirt
```
vi libvirt-br-bond0.xml
<network>
  <name>ovs-eth0-network</name>
  <forward mode='bridge'/>
  <bridge name='br-eth0'/>
  <virtualport type='openvswitch'/>
  <portgroup name='no-vlan' default='yes'>
  </portgroup>
</network>

vi libvirt-br-bond0.xml
<network>
  <name>ovs-bond0-network</name>
  <forward mode='bridge'/>
  <bridge name='br-bond0'/>
  <virtualport type='openvswitch'/>
  <portgroup name='no-vlan' default='yes'>
  </portgroup>
  <portgroup name='vlan-100'>
    <vlan>
      <tag id='100' nativeMode='untagged'/>
    </vlan>
  </portgroup>
</network>
```
## 7. Define the networks in libvirt using the XML files just created:
```
virsh net-define libvirt-br-bond0.xml
virsh net-autostart ovs-bond0-network
virsh net-start ovs-bond0-network

virsh net-define libvirt-br-eth0.xml
virsh net-autostart ovs-eth0-network
virsh net-start ovs-eth0-network
```
## 8. Create a directory for the VMs
```
mkdir /var/lib/virtual-machines/
chown qemu:qemu /var/lib/virtual-machines/
```
## 9. Download the RHEL 7.1 qcow2 image
https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.1/x86_64/product-downloads
## 10. Remove cloud-init, set a root password and alow ssh
https://access.redhat.com/solutions/641193

In the /etc/shadow file paste the root password between the ::

Create a password to add to the /etc/shadow file with `openssl passwd -1 changeme`

Then the /etc/ssh/sshd_conig will need these two parameters
```
PermitRootLogin yes
PasswordAuthentication yes
```
```
guestfish -a /tmp/rhel-guest-image-7.1-20150224.0.x86_64.qcow2 -i ln-sf /dev/null /etc/systemd/system/cloud-init.service
guestfish --rw -a /tmp/rhel-guest-image-7.1-20150224.0.x86_64.qcow2
><fs> run
><fs>list-filesystems
><fs> mount /dev/vda1 /
><fs> vi /etc/shadow
><fs> vi /etc/ssh/sshd_config
><fs> quit
```
### 11.Extend the qcow2 image partition to the desired size:

Create a new qcow2 file with the desired size (10 GB in the example):
```
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/virtual-machines/vm1.qcow2 10G
```
Resize the partition:
```
virt-resize --expand /dev/sda1 /tmp/rhel-guest-image-7.1-20150224.0.x86_64.qcow2 /var/lib/virtual-machines/vm1.qcow2
```
### 12. Create the VM
```
virt-install \
--name vm1 \
--ram 1024 \
--vcpus=1 \
--disk format=qcow2,path=/var/lib/virtual-machines/vm1.qcow2,device=disk,bus=virtio \
--nonetworks \
--graphics vnc,listen=0.0.0.0,keymap=en_gb --noautoconsole --hvm \
--os-variant rhel7 \
--import
```
This will start the VM and its console will be accessible by a VNC client on default port 5900.
### 13. Stop the VM and add the network interfaces
This is needed because `virt-install` doesn't support openvswitch ports.

```
virsh stop vm1
virsh edit vm1
```
Add this in the devices section:
```
    <interface type='network'>
      <source network='ovs-eth0-network' portgroup='no-vlan'/>
      <model type='virtio'/>
    </interface>
    <interface type='network'>
       <source network='ovs-bond0-network' portgroup='vlan-100'/>
       <model type='virtio'/>
    </interface>
```
### 14. Set up the interface that is VLAN tagged:

```
yum remove NetworkManager

vi /etc/sysconfig/network-scripts/ifcfg-eth1.100
DEVICE="eth1.100"
BOOTPROTO=none
ONBOOT=no
TYPE="Ethernet"
VLAN=yes
IPADDR0=1.1.1.1
PREFIX0=24
```
Now, assuming the network settings in the interface are correct, we should be able to access other hosts and VMs in VLAN 100.

