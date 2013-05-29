#!/bin/sh
#
# name      : /root/bin/ymonitor.sh
# version   : 2.0
# author    : shoop@y-find.com
# date      : 5 May 2013
# copyright : YFind Technologies Pte Ltd
#

# wait till yscanbox init is complete
while [ ! -z `ps | grep S99yscanbox | grep -v grep` ]; do
  sleep 1
done

if [ -z `pgrep -n autossh` ]; then
  logger -t ymonitor "Autossh process missing, restarting autossh"
  /etc/init.d/autossh restart
fi

if [ -z `pgrep -n yheartbeat` ]; then 
  logger -t ymonitor "YHeartbeat process missing, restarting YScanBox"
  /etc/init.d/yscanbox restart
elif [ -z `pgrep -n yscanner` ]; then
  logger -t ymonitor "YScanner process missing, restarting YScanner"
  /etc/init.d/yscanbox restart_yscanner
fi