#!/bin/bash
#----------------------[30-03-2018]----------------
(
  echo "----00------------------"
  lsblk
  echo "----01------------------"
  df -h
  echo "----02------------------"
  vgs
  echo "----03------------------"
  for i in $(vgs --noheadings -o vg_name)
  do
    vgdisplay -v ${i}
    echo '---'
  done
  echo "----04------------------"
  lvs -ao +devices
  echo "----05------------------"
  pvs 
  echo "----06------------------"
  rpm -qa | grep gluster
  echo "----07------------------"
  gstatus
  echo "----08------------------"
  gluster peer status
  echo "----09------------------"
  gluster volume status
  echo "----10------------------"
  gluster volume info all
  echo "----11------------------"
  for i in $(gluster volume list)
  do
    echo ${i}
    gluster volume heal ${i} info
    echo '---'
  done
) > /root/log/$(hostname)-$(date '+%Y-%m-%d-%H-%M')-storage.log 2>&1

