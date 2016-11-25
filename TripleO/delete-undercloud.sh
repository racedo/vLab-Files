yum autoremove openstack-* instack* mariadb* *heat* *director* mongodb* rabbitmq-server httpd* python-swift haproxy

rm -rf \
/var/log/nova /var/log/keystone /var/log/ironic* /var/log/mongodb /var/log/rabbitmq/ /var/log/heat /var/log/httpd /var/log/mistral /var/log/swift /var/log/zaqar /var/log/swift \
/var/lib/rabbitmq/ /var/lib/glance /var/lib/haproxy /var/lib/heat* /var/lib/ironic* /var/lib/mongodb /var/lib/mysql /var/lib/neutron /var/lib/nova /var/lib/rabbitmq /var/lib/swift \
/etc/glance /etc/haproxy /etc/heat /etc/httpd /etc/ironic-inspector /etc/mistral /etc/neutron /etc/nova /etc/rabbitmq /etc/swift /etc/tempest /etc/zaqar
