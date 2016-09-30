# Creating Overcloud Images
## References

Main DIB documentation: http://docs.openstack.org/developer/diskimage-builder/

TripleO elements and options used for the Overcloud with DIB:

https://github.com/openstack/tripleo-common/blob/master/image-yaml/overcloud-images.yaml


## Modify base image if necessary
During the image build packages are installed so the image needs to be subscribed. Extra packages are installed as an example only.
```
virt-customize -a /tmp/rhel-guest-image-7.2-20160302.0.x86_64.qcow2 \
--run-command \
'subscription-manager register --username=user --password=password ;\
subscription-manager attach --pool=8a85f98156981319015698a6add24aec;\
subscription-manager  repos --disable=*;\
subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-openstack-9-rpms --enable=rhel-7-server-openstack-9-director-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-7-server-optional-rpms;\
yum -q -y install grub2-efi grub2-efi-modules'
```

**Note: Alternatively the element ```rhel-common``` should allow us to register/unregister the image during its build.

## Variables used

```DIB_YUM_REPO_CONF```: can be used to add an extra repository during the image build.

```ELEMENTS_PATH```: is used to especify the TripleO DIB elements

```DIB_LOCAL_IMAGE```: local qcow2 base RHEL image

## Installing packages in the image

As an example, I'm installing ``grub2-efi-modules`` in the ramdisk image.

Edit ```/usr/share/diskimage-builder/elements/redhat-common/package-installs.yaml```

Add the package like this: ```grub2-efi-modules:```

## Exploring the contents of an initramfs file

```/usr/lib/dracut/skipcpio ironic-python-agent.initramfs |gunzip -c|cpio -i -d```

## Examples
### Overcloud RHEL 7 ramdisk and kernel only

```
export DIB_LOCAL_IMAGE=/tmp/rhel-guest-image-7.2-20160302.0.x86_64.qcow2
export ELEMENTS_PATH=/usr/share/tripleo-image-elements
disk-image-create -o ironic-python-agent -u ironic-agent dynamic-login element-manifest network-gateway enable-packages-install  rhel7 -p python-hardware-detect
```

### Overcloud full image RHEL 7 
```
disk-image-create \
-o overcloud-full -u \
hosts baremetal dhcp-all-interfaces os-collect-config os-net-config stable-interface-names grub2 element-manifest network-gateway dynamic-login enable-packages-install rhel7 \
-p python-psutil,python-debtcollector,plotnetcfg,sos,python-networking-cisco,python-UcsSdk,device-mapper-multipath,python-networking-bigswitch,openstack-neutron-bigswitch-lldp,openstack-neutron-bigswitch-agent,python-heat-agent-puppet,grub2-efi-modules
```
### Generic CentOS 7 ramdisk and kernel only
```
export ELEMENTS_PATH=/usr/share/tripleo-image-elements
ramdisk-image-create --ramdisk-element dracut-ramdisk -o ironic-agent centos7
```
### Generic RHEL 7 ramdisk and kernel only passing an extra repository
```
export DIB_YUM_REPO_CONF=/etc/yum.repos.d/rhel-7.3.repo
export DIB_LOCAL_IMAGE=rhel-guest-image-7.2-20160302.0.x86_64.qcow2
ramdisk-image-create --ramdisk-element dracut-ramdisk -o ironic-agent rhel7
```
### Generic RHEL 7 ramdisk with HP Proliant Tools:
Apply patch if necessary: https://bugs.launchpad.net/diskimage-builder/+bug/1590176
```
export DIB_YUM_REPO_CONF=/etc/yum.repos.d/rhel-7.3.repo
export DIB_LOCAL_IMAGE=rhel-guest-image-7.2-20160302.0.x86_64.qcow2
export DIB_HPSSACLI_URL=http://whp-hou4.cold.extweb.hp.com/pub/softlib2/software1/pubsw-linux/p215599048/v83802/hpssacli-1.50-4.0.x86_64.rpm
ramdisk-image-create --ramdisk-element dracut-ramdisk -o ironic-agent proliant-tools rhel7
```
