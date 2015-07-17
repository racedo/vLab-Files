# Automatic Health Check in the OSP Installer

## Purpose
This guide uses a RHEL OSP Installer host to install the eDeploy AHC. This allows us to reuse the OSP Installer's DHCP/TFTP/PXE and Apache server.
A dedicated node for eDeploy is recommended so that the Installer's host is dedicated to its task in a supported way as AHC requires packages from the EPEL repository which is unsupported in Red Hat.

eDeploy AHC documentation: https://github.com/enovance/edeploy/blob/master/docs/AHC.rst

OSP Installer documentation: http://red.ht/1M3QEhd

**Note:** I haven't tested Distributed Benchmarking to analyse the network and it's not included in this document.

 DAHC documentation can be found here: https://github.com/enovance/edeploy/blob/master/docs/AHC.rst#distributed-benchmarking

### 1. Install EPEL and required packages:
```
 yum install https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
 yum install make git httpd dnsmasq rsync unzip debootstrap pigz compat-glibc python-pip gcc python-devel python-mock python-netaddr qemu-kvm gcc-c++ glibc
```

### 2. Install python dependency hardware:
```
 pip install hardware
```

### 3. Clone eDeploy git locally:
```
 git clone https://github.com/enovance/edeploy.git
 cd edeploy
 make install-www # Ignore the www-data errors here
 chown -R apache:apache .
```
### 4. Make sure you have the RHEL 7.1 ISO available and create the AHC custom OS:

```
 cd build
 make DIST=redhat DVER=RH7.0 VERSION='1.0' ISO_PATH=/var/www/html/repos/rhel-server-7.1-x86_64-dvd.iso RHN_USERNAME=user RHN_PASSWORD='password' health-check
```

### 5. Copy the PXE and vmlinuz files created in the previous step to /var/lib/tftpboot/boot:

```
 cp /var/lib/debootstrap/install/RH7.0-1.0/base/boot/ /var/lib/tftpboot/boot/
 cp /var/lib/debootstrap/install/RH7.0-1.0/base/boot/vmlinuz-3.10.0-229.el7.x86_64 /var/lib/tftpboot/boot/
```

### 6. Set PXEMNRURL to the URL of the host:

```
 vi /etc/edeploy.conf
```

```
 [SERVER]

 HEALTHDIR=/var/lib/edeploy/health/
 CONFIGDIR=/root/edeploy/config
 LOGDIR=/root/edeploy/config/logs
 HWDIR=/root/edeploy/config/hw
 LOCKFILE=/var/run/httpd/edeploy.lock
 USEPXEMNGR=False
 PXEMNGRURL=http://10.0.0.20:8000/
 #METADATAURL = http://192.168.122.1/
```

### 7. Reuse the Foreman apache config to add support to the AHC upload scripts.  

   Add this in /etc/httpd/conf.d/05-foreman.conf within the VirtualHost section:

```
 <Directory "/usr/share/foreman/public/cgi-bin">
    Options SymLinksIfOwnerMatch
    AllowOverride None
    Require all granted
    Options +ExecCGI
    AddHandler cgi-script .py
 </Directory>
```

```
 systemctl restart httpd
```

### 8. Create the cgi-bin directory and copy the upload-health.py and upload.py scripts:


```
 mkdir -p /var/lib/foreman/public/cgi-bin
 cp /root/edeploy/server/upload-health.py /var/lib/foreman/public/cgi-bin/
 cp /root/edeploy/server/upload.py /var/lib/foreman/public/cgi-bin/
 chown -R foreman:foreman /var/lib/foreman/public/cgi-bin/
 chown -R apache:apache /var/lib/edeploy/
```

### 9. Modify the pxe configuration for the Foreman discovery image to also include the AHC image so it looks like this (set SERV to the Foreman host IP):

```
 DEFAULT menu
 PROMPT 0
 MENU TITLE PXE Menu
 TIMEOUT 200
 TOTALTIMEOUT 6000
 ONTIMEOUT Health

 LABEL Health
 MENU LABEL AHC Health Check
 KERNEL boot/vmlinuz-3.10.0-229.el7.x86_64
 APPEND initrd=boot/health.pxe SERV=10.0.0.20 SESSION=install
 ONSUCCESS=halt ONFAILURE=console IP=all:dhcp pci=bfsort

 LABEL discovery
 MENU LABEL Foreman Discovery
 KERNEL boot/foreman-discovery-image-latest-vmlinuz
 APPEND rootflags=loop initrd=boot/foreman-discovery-image-latest-img root=live:/foreman.iso rootfstype=auto ro rd.live.image rd.live.check rd.lvm=0 rootflags=ro crashkernel=128M elevator=deadline max_loop=256 rd.luks=0 rd.md=0 rd.dm=0 foreman.url=https://osp6-installer.vm.lab nomodeset selinux=0 stateless biosdevname=0
IPAPPEND 2
```
### 10. Get the file ahc-selinux-policy.pp and add the selinux policies or optionally just disable selinux:
```
 semodule -i ahc-selinux-policy.pp
```
### 11. PXE Boot the servers now and observe how they pick up the AHC image

The results are stored in /var/lib/edeploy/health/install/<date-time>

### 12. Create a directory for the results to be analysed by the cardiff tool:
```
 mkdir /var/lib/edeploy/health/install/results
 cd /var/lib/edeploy/health/install/
 cp */*.hw results/
```
### 13. Analyse the results with cardiff:

**Note**: single quotes are mandatory.
```
 cd edeploy/tools/cardiff/
 ./cardiff.py  -p '/var/lib/edeploy/health/install/results/VMwareVirtualPlatform-VMware564d*.hw' |less -R
```
If there are multiple groups cardiff can create a directory and saves the differences if specified with '-o'
```
 ./cardiff.py  -p '/var/lib/edeploy/health/install/results/VMwareVirtualPlatform-VMware564d*.hw' -o /tmp/ahc-groups|less -R
```
The output includes sections like this one:

```
####################
The 2 systems can be grouped in 1 groups of identical hardware
Group 0 (2 Systems)
-> VMware-56 4d a4 ed 64 64 e3 e0-51 69 bd 9a 5a ee ed 78, VMware-56 4d 0e 37 00 4a 20 da-ca 9e 01 2a e0 b2 15 a7


Group 0 : Checking logical disks perf
simultaneous_randread_4k_KBps  sdb: SUMMARY :   2 consistent hosts with 58050.00 IOps as average value and   811.00 standard deviation
simultaneous_randread_4k_KBps  sda: SUMMARY :   2 consistent hosts with 58050.00 IOps as average value and   811.00 standard deviation
simultaneous_randread_4k_KBps  sdc: SUMMARY :   2 consistent hosts with 58050.00 IOps as average value and   811.00 standard deviation
```
For a detailed view (for example, only IOPS tests for all the hard drives):
```
./cardiff/cardiff.py -p '/var/lib/edeploy/health/install/2015_07_17-12h08/VMwareVirtualPlatform-VMware564d*' -l DETAIL -g '0' -c 'standalone_read_1M_IOps' -i 'sd.*'|less -R
```
This will output something like this:
```
####################
The 2 systems can be grouped in 1 groups of identical hardware
Group 0 (2 Systems)
-> VMware-56 4d a4 ed 64 64 e3 e0-51 69 bd 9a 5a ee ed 78, VMware-56 4d 0e 37 00 4a 20 da-ca 9e 01 2a e0 b2 15 a7


Group 0 : Checking logical disks perf

standalone_read_1M_IOps           : DETAIL  : sd.*
     VMware-56 4d 0e 37 00 4a 20 da-ca 9e 01 2a e0 b2 15 a7  \
sda                                                577
sdb                                               1585
sdc                                               1501

     VMware-56 4d a4 ed 64 64 e3 e0-51 69 bd 9a 5a ee ed 78
sda                                                528
sdb                                               1524
sdc                                               1315
```
