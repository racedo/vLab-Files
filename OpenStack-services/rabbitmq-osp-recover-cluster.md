# Manually rebuild a RabbitMQ cluster after failure or complete shutdown

## Purpose
This procedure explains how to manually rebuild a RabbitMQ cluster after all nodes went down due to failure or complete shutdown.

Read the notes below if just one or two servers out of a 3-nodes cluster failed.

**Note**: RHEL OSP 6 (Juno) includes a new Pacemaker resource that takes care of this process automatically but in case of partial cluster failure, RabbitMQ partitions are common, please, read the notes below.

### 1. On each node:
```
rm -rf /var/lib/rabbitmq/*
```
### 2. On one node, start rabbitmq-server to create the cookie and copy it to the other nodes:
```
systemctl start rabbitmq-server
scp -p /var/lib/rabbitmq/.erlang.cookie controller2.vm.lab:/var/lib/rabbitmq/
scp -p /var/lib/rabbitmq/.erlang.cookie controller3.vm.lab:/var/lib/rabbitmq/
```
### 3. Start rabbitmq-server in the other two nodes
```
systemctl start rabbitmq-server
```
### 4. Set the HA Policy as described in https://www.rabbitmq.com/ha.html
```
rabbitmqctl set_policy ha-all "^ha\." '{"ha-mode":"all"}'
rabbitmqctl cluster_status
```
### 5. Clean up the resource in Pacemaker so that it starts the service again
Assuming the rabbitmq systemd services were protected by Pacemaker (default in RHEL OSP), clean up the resource.
```
pcs resource cleanup rabbitmq-server
```
## Notes
### Check if there are queues stuck:
After a failure and recovery of just one or two nodes there may be queues stuck (at least as of RabbitMQ 3.3.5, it seems 3.4 fixes this issue).
```
# rabbitmqctl eval 'rabbit_diagnostics:maybe_stuck().'
```
If there are queues stuck you might have to manually restart services that publish messages to these queues. After a cluster partition it is common to have to restart OpenStack services such as nova-compute or any other components that publish messages in RabbitMQ. This issue is fixed in OpenStack Kilo (RHEL OSP 7) by implementing a heartbeat for the messaging queues (https://review.openstack.org/#/c/146047/)

Alternatively, a restart of all the RabbitMQ servers usually fixes this issue. With Pacemaker this is done by running:
```
pcs resource disable rabbitmq-server
pcs resource enable rabbitmq-server
```
After this, make sure that there are no partitions by checking the output of `rabbitmqctl cluster_status` in all the nodes and confirming that all of them show the same status.
