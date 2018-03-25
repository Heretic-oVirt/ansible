#!/bin/bash
#----------------------[25-03-2018]----------------
(
  echo "----00------------------"
  lsblk
  df -h;
  echo "----01------------------"
  vgs
  echo "----02------------------"
  for i in $(vgs | tail -n +2 | awk '{ print $1; }')
  do
    echo $i
    vgdisplay -v $i
    echo '---'
  done
  echo "----03------------------"
  for i in $(vgs | tail -n +2 | awk '{ print $1; }')
  do
    echo $i
    vgdisplay -v $i | grep -i 'Total PE' 
    echo '---'
  done
  echo "----04------------------"
  pvs 
  echo "----05------------------"
  lvs -ao +devices
  echo "----09------------------"
  #sosreport --batch --name $(hostname)
  echo "----11------------------"
  rpm -qa | grep gluster
  echo "----12------------------"
  gluster volume info   enginedomain
  echo "----13------------------"
  gluster volume status enginedomain
  echo "----14------------------"
  gstatus
) >/root/log/DebuggaNodi-$(hostname)-$(date '+%Y-%m-%d-%H-%M').log 2>&1

