# Test a newly created Overcloud
Right after the Overcloud has finished deploying for the first time this heat template can be used to create a public and private network, an instance and a security group that opens TCP port 22 and ICMP.

To use it download overcloud-template.yaml and overcloud-env.yaml, edit overcloud-env.yaml and then as the admin tenant run:

```openstack stack create -t overcloud-template.yaml -e overcloud-env.yaml test```
