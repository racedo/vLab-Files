#Deploying Ironic in the Overcloud
###Introduction
This document describes the process to enable Ironic in the Overcloud in a multi-controller deployment with RH OSP 10 Newton.

The process should work with any working RH OSP 10 deployment or even an already deployed environment updated with the configuration templates described here.

###Architecture Setup
With this setup we can have both, virtual instances and instances deployed on baremetal nodes and reachabe via network between them. In this example I’m using floating IPs with VMs and the provisioning network with the baremetal nodes. 

To be able to test this setup in a lab with virtual machines, we use Libvirt+KVM using VMs for all the nodes in a all-in-one lab. The network topology is described in the diagram below.

Ideally we’d have more networks, for example a dedicated network for cleaning the disks and another one for provisioning the baremetal nodes from the Overcloud and even an extra one as the tenant network for the baremetal nodes in the Overcloud but for simplicity, in this lab I reused the Undercloud’s provisioning network for this four network roles: 
* Provisioning from the Undercloud
* Provisioning from the Overcloud
* Cleaning the baremetal nodes’ disks 
* Baremetal tenant network for the Overcloud nodes
![OVS Libvirt VLANs](IronicintheOvercloud.png)

###Virtual environment configuration
In order to be able to test with `root_device` hints in the nodes (Libvirt VMs) that we want to test as baremetal nodes we define the first disk in Libvirt with a iSCSI bus and a _wwn ID_:
```
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='/var/lib/virtual-machines/overcloud-2-node4-disk1.qcow2'/>
  <target dev='sda' bus='scsi'/>
  <wwn>0x0000000000000001</wwn>
</disk>
```
To verify the hints we can optionally introspect the node in the Undercloud (as currently there’s no introspection in the Overcloud). This is what we can see after introspection of the node in the Undercloud:
```
$ openstack baremetal introspection data save 7740e442-96a6-496c-9bb2-7cac89b6a8e7|jq '.inventory.disks'
[
  {
    "size": 64424509440,
    "rotational": true,
    "vendor": "QEMU",
    "name": "/dev/sda",
    "wwn_vendor_extension": null,
    "wwn_with_extension": "0x0000000000000001",
    "model": "QEMU HARDDISK",
    "wwn": "0x0000000000000001",
    "serial": "0000000000000001"
  },
  {
    "size": 64424509440,
    "rotational": true,
    "vendor": "0x1af4",
    "name": "/dev/vda",
    "wwn_vendor_extension": null,
    "wwn_with_extension": null,
    "model": "",
    "wwn": null,
    "serial": null
  },
  {
    "size": 64424509440,
    "rotational": true,
    "vendor": "0x1af4",
    "name": "/dev/vdb",
    "wwn_vendor_extension": null,
    "wwn_with_extension": null,
    "model": "",
    "wwn": null,
    "serial": null
  },
  {
    "size": 64424509440,
    "rotational": true,
    "vendor": "0x1af4",
    "name": "/dev/vdc",
    "wwn_vendor_extension": null,
    "wwn_with_extension": null,
    "model": "",
    "wwn": null,
    "serial": null
  }
]
```
###Undercloud templates
The following templates contain all the changes needed to configure Ironic and to adapt the NIC config to have a dedicated OVS bridge for Ironic as required.
####Ironic configuration
`~/templates/ironic.yaml`

```
parameter_defaults:
    IronicEnabledDrivers:
        - pxe_ssh
    NovaSchedulerDefaultFilters:
        - RetryFilter
        - AggregateInstanceExtraSpecsFilter
        - AvailabilityZoneFilter
        - RamFilter
        - DiskFilter
        - ComputeFilter
        - ComputeCapabilitiesFilter
        - ImagePropertiesFilter
    IronicCleaningDiskErase: metadata
    IronicIPXEEnabled: true
    ControllerExtraConfig:
        ironic::drivers::ssh::libvirt_uri: 'qemu:///system
```
####Network configuration
First we map an extra bridge called `br-baremetal` which will be used by Ironic:

`~/templates/network-environment.yaml`:
```
[...]
parameter_defaults:
[...]
  NeutronBridgeMappings: datacentre:br-ex,baremetal:br-baremetal
  NeutronFlatNetworks: datacentre,baremetal
```
This bridge will be configured in the provisioning network (_control plane_) of the con
trollers as we will reuse this network as the Ironic network later. If we wanted to add a dedicated network we would do the same config.


It is important to mention that this Ironic network used for provisioning can’t be VLAN tagged, which yet another reason to justify using the Undercloud’s provisioning network for this lab:

`~/templates/nic-configs/controller.yaml`:
```
[...]         
          network_config:
            -
              type: ovs_bridge
              name: br-baremetal
              use_dhcp: false
              members:
                 -
                   type: interface
                   name: eth0
              addresses:
                -
                  ip_netmask:
                    list_join:
                      - '/'
                      - - {get_param: ControlPlaneIp}
                        - {get_param: ControlPlaneSubnetCidr}
              routes:

                -
                  ip_netmask: 169.254.169.254/32
                  next_hop: {get_param: EC2MetadataIp}
[...]
```
####Deployment
This is the deployment script I’ve used. Note there’s a even a composable role for the Ops Tools as well as Ceph but those are irrelevant for the purpose of this document.


`~/deployment-scripts/ironic-ha-net-isol-deployment-dupa.sh`:
```
openstack overcloud deploy \
--templates \
-r ~/templates/roles_data.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/storage-environment.yaml \
-e ~/templates/network-environment.yaml \
-e ~/templates/ceph-storage.yaml \
-e ~/templates/parameters.yaml \
-e ~/templates/firstboot/firstboot.yaml \
-e ~/templates/ips-from-pool-all.yaml \
-e ~/templates/fluentd-client.yaml \
-e ~/templates/sensu-client.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/services/ironic.yaml \
-e ~/templates/ironic.yaml \
--control-scale 3 \
--compute-scale 1 \
--ceph-storage-scale 3 \
--compute-flavor compute \
--control-flavor control \
--ceph-storage-flavor ceph-storage \
--timeout 60 \
--libvirt-type kvm
```
###Post deployment configuration
####Verifications
After the deployment completes successfully we should see how the controllers have the compute service enabled:
```
$ openstack compute service list -c Binary -c Host -c Status
+------------------+------------------------------------+---------+
| Binary           | Host                               | Status  |
+------------------+------------------------------------+---------+
| nova-consoleauth | overcloud-controller-2.localdomain | enabled |
| nova-consoleauth | overcloud-controller-1.localdomain | enabled |
| nova-consoleauth | overcloud-controller-0.localdomain | enabled |
| nova-scheduler   | overcloud-controller-2.localdomain | enabled |
| nova-scheduler   | overcloud-controller-1.localdomain | enabled |
| nova-conductor   | overcloud-controller-2.localdomain | enabled |
| nova-conductor   | overcloud-controller-1.localdomain | enabled |
| nova-compute     | overcloud-controller-2.localdomain | enabled |
| nova-scheduler   | overcloud-controller-0.localdomain | enabled |
| nova-compute     | overcloud-controller-1.localdomain | enabled |
| nova-conductor   | overcloud-controller-0.localdomain | enabled |
| nova-compute     | overcloud-controller-0.localdomain | enabled |
| nova-compute     | overcloud-compute-0.localdomain    | enabled |
+------------------+------------------------------------+---------+
```
And the driver we passed with `IronicEnabledDrivers` is also enabled:
```
$ openstack baremetal driver list
+---------------------+------------------------------------------------------------------------------------------------------------+
| Supported driver(s) | Active host(s)                                                                                             |
+---------------------+------------------------------------------------------------------------------------------------------------+
| pxe_ssh             | overcloud-controller-0.localdomain, overcloud-controller-1.localdomain, overcloud-controller-2.localdomain |
+---------------------+------------------------------------------------------------------------------------------------------------+
```
####Baremtal network
This network will be:
* The provisioning network for the Overcloud’s Ironic.
* The cleaning network for wiping the baremetal node’s disks
* The tenant network for the Overcloud’s Ironic instances

Create the baremetal network in the Overcloud with the same network than the Undercloud’s _ctlplane_ but using a different range:
```
$ . overcloudrc
$ openstack network create \
  --share \ 
  --provider-network-type flat \
  --provider-physical-network baremetal \
  --external \
  baremetal
$ openstack subnet create \
  --network baremetal \
  --subnet-range 192.168.3.0/24 \
  --gateway 192.168.3.1 \
  --allocation-pool start=192.168.3.150,end=192.168.3.170 \
  baremetal-subnet

```
Then we need to configure each controller’s `/etc/ironic.conf` to use this network to clean the hosts at registration and also before tenants use them as baremetal instances:
```
$ openstack network show baremetal -f value -c id
F7af39df-2576-4042-87c0-14c395ca19b4
```
```
$ ssh heat-admin2$CONTROLLER_IP
$ sudo vi /etc/ironic/ironic.conf
$ cleaning_network_uuid=f7af39df-2576-4042-87c0-14c395ca19b4
$ sudo systemctl restart openstack-ironic-conductor
```
We should write it in a template and run the deploy command again instead of the above but this is obviously much slower than doing it manually. In any case we should leave it ready to be included in our next update:
```
parameter_defaults:
    ControllerExtraConfig:
        Ironic::conductor::cleaning_network_uuid: f7af39df-2576-4042-87c0-14c395ca19b4
```
####Deployment images
We can use the same deployment images we use in the Undercloud:
```
$ openstack image create --public --container-format aki --disk-format aki --file ~/images/ironic-python-agent.kernel deploy-kernel
$ openstack image create --public --container-format ari --disk-format ari --file ~/images/ironic-python-agent.initramfs deploy-ramdisk
```
We could also create them using the [CoreOS images](http://docs.openstack.org/project-install-guide/baremetal/draft/deploy-ramdisk.html#deploy-ramdisk). For example, if we wanted to troubleshoot the deployment we could use the CoreOS images and enable debug output in the Ironic Python Agent or adding our ssh-key to access during the deployment of the image.

####Instance images
Again, for simplicity, we can use the _overcloud-full_ image we use in the Undercloud:
```
$ KERNEL_ID=$(openstack image create --file ~/images/overcloud-full.vmlinuz --public --container-format aki --disk-format aki -f value -c id overcloud-full.vmlinuz)
$ RAMDISK_ID=$(openstack image create --file ~/images/overcloud-full.initrd --public --container-format ari --disk-format ari -f value -c id overcloud-full.initrd)
$ openstack image create --file ~/images/overcloud-full.qcow2 --public --container-format bare --disk-format qcow2 --property kernel_id=$KERNEL_ID --property ramdisk_id=$RAMDISK_ID overcloud-full
```
Note that it uses a _kernel_ and a _ramdisk_ image. If we don’t add them, when deploying the nodes I saw errors like this from Ironic conductor:
```
ERROR ironic.drivers.modules.agent_base_vendor Command: sudo ironic-rootwrap /etc/ironic/rootwrap.conf parted -a optimal -s -- /dev/disk/by-path/ip-192.168.3.162:3260-iscsi-iqn.2008-10.org.openstack:9699b9d3-f385-4b3a-abf6-0d0f97bcc1eb-lun-1 mkpart primary ext2 -64MiB -0
ERROR ironic.drivers.modules.agent_base_vendor Stderr: u'/sbin/parted: invalid token: primary\nError: Expecting a file system type.\n'
```
####Create flavors
We create two flavors to start with, one for the baremetal provisioning and another one for the virtual instances. 


Then, we create a property called _baremetal_ which will also be created in the host aggregates to differentiate baremetal from virtual instances. 


As by default the `boot_option` is `netboot`, we set it to `local` and we will do the same when we create the baremetal node (note that this is optional and we could use netboot):
```
$ openstack flavor create --ram 1024 --disk 20 --vcpus 1 baremetal
$ openstack flavor set baremetal --property baremetal=true
$ openstack flavor set baremetal --property capabilities:boot_option="local"
$ openstack flavor create --disk 20 m1.small
$ openstack flavor set m1.small --property baremetal=false
```
####Create host aggregates
To have OpenStack differentiating between baremetal and virtual instances we can create _host aggregates_ to have the _nova-compute_ service running on the controllers just for Ironic and the the one on compute nodes for virtual instances:
```
$ openstack aggregate create --property baremetal=true baremetal-hosts
$ openstack aggregate create --property baremetal=false virtual-hosts
$ for compute in $(openstack hypervisor list -f value -c "Hypervisor Hostname" | grep compute); do openstack aggregate add host virtual-hosts $compute; done
$ openstack aggregate add host baremetal-hosts overcloud-controller-0.localdomain
$ openstack aggregate add host baremetal-hosts overcloud-controller-1.localdomain
$ openstack aggregate add host baremetal-hosts overcloud-controller-2.localdomain

```
####Register the nodes in Ironic
The nodes can be registered using `openstack baremetal create` and a _YAML_ template. In this example I register only one node named _overcloud-2-node4_, which I had previously registered in the Undercloud for introspection (and later deleted from it or set to _maintenance mode_ to avoid conflicts between the two Ironic services).


The section `root_device` contains commented examples of the hints we could use.


This is like the `instackenv.json` in the Undercloud but in `YAML` and probably more readable:
```
$ cat overcloud-2-node4.yaml
nodes:
    - name: overcloud-2-node4
      driver: pxe_ssh
      driver_info:
        ssh_username: stack
        ssh_key_contents:  |
          -----BEGIN RSA PRIVATE KEY-----
          MIIEogIBAAKCAQEAxc0a2u18EgTy5y9JvaExDXP2pWuE8Ebyo24AOo1iQoWR7D5n
          fNjkgCeKZRbABhsdoMBmbDMtn0PO3lzI2HnZQBB4BdBZprAiQ1NwKKotUv9puTeY
          61lR9XI+Vxlb9ecSjlVlbaAl7BmwHbvcXxWtBAJgkI8JzlYsTuz+QQ8SRa6m0A6d
          HpYWd6KJNrPr6y6X8/rLgZe89fq/7wJCRb8I5N0IWwE6D9UfUeLzBMHK5shigYl0
          CIEnBqPCxXPoWhrhp+Nt4LfZZd1jadtUnXXfnA4rFtcwRH2I1AuJJ05mvBWEYn6e
          OjJZ3KSBEzgFFSuOYRhDHIzyZJTATYAPk8TyswIDAQABAoIBACBEZEQgh6Pc4M8r
          3KitmfXq2+qCTq5vtHdKo4jptYTKi1Jxn6ozK5toV+BDxNF6LOwjVtIBy0h25FFL
          64u83N7hkOLJ6UYS55P6EYrgsAIhHlsTocOKz57toxPMVD8aEeHcNm6auHT6f8tp
          8Pol7BKCXMRYQS5CynmZmaR9U+q/2JUn8fOGVp84jA9q8jZk9b7N/OYvLRy+7MzF
          +IYg0AwlMMM5QUgzF4Z0Bith+BepIuWUUCKyOvXVH2+YXyJtPuW+nPlWMnzZTF8t
          u0yMpLQDxIWhqzT25Hr+AIBBIIwF1VQ50fI8WHPU9semcgPdwGliAOTWGa7j19o8
          Qt6udvECgYEA4m55qCnmOxf8L2Lu9i5vx3s3lrDFSbL5NZ/YCPPa2/x0OLvH/7LC
          5D0jfb3ln2gSXF9ElguRy/K7p0rn9ZMfkAtlMaQqA4SkZIAI9FOvyaP1ghbnyUXl
          +LzZCd37DjPn7lP/BtGT2NDBPXPLs0hlqllHLcP8t9bVCnLTcalsPJsCgYEA36GG
          /n+u0uIyKURP/uBS9gYSEMYXvbW0Fn4glzs0/KKOGJ8aeFLECCLczNv27fC1oKLf
          5XVxe7CabA/HYyJAm+Pcrr6Y5wYIJFQc4fg3mtOFPVTvyhC3YCecuyTLOJvype5W
          EOf6RS3Crw0KJslauoGLihVfcIbdK1ouQS0lZ8kCgYANwD/LIqBEvnQmPI/ei3tm
          VelOUXXpv+C6jPaFtKl56p70QxMmSCjly4C4RiwHvj4/NdnoctNr21XiFv53P3QP
          P2Hp3dpfVFLXd58Tl3F5gWeLevCgnIoWzQExRDXW6vgO1TMLqvabmDHkFYAtZxwl
          eD6GXPyf/X/6nnaQ1IUqOQKBgB+gBCsxe1OvUVCsrHNq3dCVAzEEEo9ths43f/xj
          Dxc7FcU9msyxR6+u3nLKGJ2FkOnqnqcgeK/5RZ1KjfPjACgLjUXZBl6FZ9lbW8pJ
          A/QNPaZywIZe3s/mSi/dADA9PY9hqSIy7B2kXwfKXEkn6IC/mTAp3ZlYOSbMVgY5
          kDShAoGAdYp/YHvB2DdO+CPGaFZzfuxUkrvB/aeo+MBw8qDXzC9iqlY3+3NMYenG
          7DsSKAL4EDqjufY3h+4fRwOcD+EFqlUTDG1sjsSDKjdiHyYMzjcrg8nbaj/M9kAs
          xXnSm9686KxUiCDXO5FWKun204B18mPH1UP20aYw098t6aAQwm4=
          -----END RSA PRIVATE KEY-----
        ssh_virt_type: virsh
        ssh_address: 10.0.0.1
      properties:
        cpus: 4
        memory_mb: 12288
        local_gb: 60
        #boot_option: local (it doesn't set 'capabilities')
        root_device:
          # model: "QEMU HARDDISK"
          # size: 64424509440
          # wwn: "0x0000000000000001"
          # serial: "0000000000000001"
          # vendor: QEMU
          name: /dev/sda
      ports:
        - address: 52:54:00:2b:8e:08
```
We create the node using the above template:
```
$ openstack baremetal create overcloud-2-node4.yaml
```
Then we have to specify which are the deployment kernel and ramdisk for the node:
```
$ DEPLOY_KERNEL=$(openstack image show deploy-kernel -f value -c id)
$ DEPLOY_RAMDISK=$(openstack image show deploy-ramdisk -f value -c id)
$ openstack baremetal node set $(openstack baremetal node list | grep overcloud-2-node4 | awk '{print $2}') \
--driver-info deploy_kernel=$DEPLOY_KERNEL \
--driver-info deploy_ramdisk=$DEPLOY_RAMDISK
```
And lastly, just like we do in the Undercloud, we set the node to available:
```
$ openstack baremetal node manage $(openstack baremetal node show overcloud-2-node4 -f value -c uuid)
$ openstack baremetal node provide $(openstack baremetal node show overcloud-2-node4 -f value -c uuid)
```
You can have all of this in a script and run it together every time you register a node.

If everything has gone well, the node will be registered and Ironic will clean its disk metadata (as per above configuration):
```
$ openstack baremetal node list -c Name -c "Power State" -c "Provisioning State"
+-------------------+-------------+--------------------+
| Name              | Power State | Provisioning State |
+-------------------+-------------+--------------------+
| overcloud-2-node4 | power off   | cleaning           |
+-------------------+-------------+--------------------+
```
Wait until the cleaning process has finished and then set the boot_option to local:
```
$ openstack baremetal node set $(openstack baremetal node show overcloud-2-node4 -f value -c uuid) --property 'capabilities=boot_option:local'
```

####Start a baremetal instance
Just as in the virtual instances we’ll use a _ssh key_ and then we’ll start the instance with Ironic:
```
$ openstack keypair create --public-key ~/.ssh/id_rsa.pub stack-key
```
Then we make sure that the cleaning process has finished (_Provisioning State_ is _available_): 
```
$ openstack baremetal node list -c Name -c "Power State" -c "Provisioning State"
+-------------------+-------------+--------------------+
| Name              | Power State | Provisioning State |
+-------------------+-------------+--------------------+
| overcloud-2-node4 | power off   | available          |
+-------------------+-------------+--------------------+
```
and we start the instance:
```
$ openstack server create \
--image overcloud-full \
--flavor baremetal \
--nic net-id=$(openstack network show baremetal -f value -c id) \
```
Now check its IP and access the newly created machine:
```
$ openstack server list -c Name -c Status -c Networks
+----------------------------------------+--------+------------------------------------+
| Name                                   | Status | Networks                           |
+----------------------------------------+--------+------------------------------------+
| bm-instance-0                          | ACTIVE | baremetal=192.168.3.155            |
| overcloud-stack-instance0-62zevcjicyiv | ACTIVE | private-net=172.16.2.7, 10.0.0.166 |
+----------------------------------------+--------+------------------------------------+
```
```
$ ssh cloud-user@192.168.3.155
Warning: Permanently added '192.168.3.155' (ECDSA) to the list of known hosts.
[cloud-user@bm-instance-0 ~]$
```
To finish, just note that the way the network is configured we can access the existing virtual instance from the baremetal node:
```
[cloud-user@bm-instance-0 ~]$ ssh cirros@10.0.0.166
The authenticity of host '10.0.0.166 (10.0.0.166)' can't be established.
RSA key fingerprint is f7:79:1d:f4:56:38:c3:5e:c0:3d:e5:bb:25:4c:da:3c.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.0.0.166' (RSA) to the list of known hosts.
cirros@10.0.0.166's password:
$ ip -4 -o a
1: lo    inet 127.0.0.1/8 scope host lo
2: eth0    inet 172.16.2.7/24 brd 172.16.2.255 scope global eth0
```

