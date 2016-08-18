#!/bin/bash
if [[ `hostname` = *"compute"* ]]
then

  sed -i 's/quiet\"/quiet intel_iommu=on ixgbe.max_vfs=8"/' /etc/default/grub

  echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/dist.conf
  echo "options igb max_vfs=8" >>/etc/modprobe.d/ixgbe.conf
  chmod +x /etc/rc.d/rc.local
  echo "echo 0 > /sys/class/net/ens4f0/device/sriov_numvfs" >> /etc/rc.local
  echo "echo 0 > /sys/class/net/ens4f1/device/sriov_numvfs" >> /etc/rc.local
  echo "echo 0 > /sys/class/net/ens5f1/device/sriov_numvfs" >> /etc/rc.local
  echo "echo 0 > /sys/class/net/ens5f1/device/sriov_numvfs" >> /etc/rc.local

  grub2-mkconfig -o /boot/grub2/grub.cfg
  cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.$(date +%m-%d-%H%M%S).bak
  dracut -f -v
  #reboot

fi
