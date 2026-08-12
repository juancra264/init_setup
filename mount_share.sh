#!/bin/bash
$SHARE_IP=
$SHARE_PATH=
$MOUNT_PATH=
$SHARE_USER=
$SHARE_DOMAIN=

HAVE_CIFS=no
grep -q cifs /proc/filesystems && HAVE_CIFS=yes
/sbin/modinfo cifs &>/dev/null && HAVE_CIFS=yes

if [ "$HAVE_CIFS" = "no" ]; then
  echo "CIFS is not installed"
  sudo apt-get install cifs-utils -y
fi

sudo mount -t cifs "//$SHARE_IP/$SHARE_PATH" \
  $MOUNT_PATH \
  -o username=$SHARE_USER@$SHARE_DOMAIN,vers=3.0
