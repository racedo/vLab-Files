# Test a newly created Overcloud
Right after the Overcloud has finished deploying for the first time this heat template can be used to create a public and private network, an instance and a security group that opens TCP port 22 and ICMP.

To use it edit overcloud-env.yaml and then run:
```openstack stack create -t heat-test-overcloud-template.yaml -e heat-test-overcloud-env.yaml test```
