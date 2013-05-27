#!/bin/sh
#
# name      : /root/bin/purge.sh
# version   : 2.0
# author    : shoop@y-find.com
# date      : 5 May 2013
# copyright : YFind Technologies Pte Ltd
#

##########
#
# Purge YScanBox Logs
#
##########

# keep at most 7 backups of *.gz
ii=0
for file in `ls -t /ybox/log/*.gz 2>/dev/null`; do
  if [ $ii -ge 7 ]; then
    rm $file
    logger -t purge "removed $file"
  fi
  ii=`expr $ii + 1`
done

# gzips *.log except the latest one (might still be in use)
local ii=0
for file in `ls -t /ybox/log/*.log 2>/dev/null`; do
  if [ $ii -gt 0 ]; then
    gzip -9 $file
    logger -t purge "gzipped $file"
  fi
  ii=`expr $ii + 1`
done

