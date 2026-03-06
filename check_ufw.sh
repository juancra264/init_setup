#!/bin/bash

echo "===== UFW Status ====="
sudo ufw status verbose
echo ""

echo "===== UFW Rules (Numbered) ====="
sudo ufw status numbered
echo ""

echo "===== UFW Default Policies ====="
sudo ufw show raw | grep -E 'INPUT|OUTPUT|FORWARD'
echo ""

echo "===== UFW Interface-Specific Rules ====="
sudo ufw status verbose | grep -E 'on eth|on ens|on enp'
echo ""

echo "===== UFW Log (Last 20 Entries) ====="
sudo tail -n 20 /var/log/ufw.log
echo ""

echo "===== UFW Service Status ====="
sudo systemctl status ufw --no-pager
