#!/bin/sh

#
# name      : /root/bin/update_leds.sh
# version   : 2.0
# author    : shooperman@gmail.com
# date      : 28 February 2013
# copyright : YFind Technologies Pte Ltd
#
# Connectivity on LED1 (2.4GHz)
#   - 3g-wan2 > amber + act-flash
#   - eth1    > green + act-flash
#   - note: no modification required, works with defaults
#
# Wifi Mode on LED2 (5GHz)
#   - ymaster  > amber + act-flash
#   - ystation > green + act-flash
#   - note: toggle 'trigger' [none|netdev] between LED2a and LED2g
#
# YScanBox on LED3 (router)
#   - yheartbeat only > flash with long delay
#   - yscanner only   > flash with short delay
#   - both running    > solid
#   - note: modify 'delayon' and 'delayoff'
#
# Timezone on LED4 (blue box)
#   - timezone set > solid
#   - note: toggle 'trigger' [none|default-on]
#

local changed=0

#
# Wifi Mode
#
local led2a_trigger=`uci get system.LED2a.trigger`
local led2g_trigger=`uci get system.LED2g.trigger`

if [ `iwconfig wlan1 2>/dev/null | awk '/Mode:Master/ {print 1}'` ]; then
	# running as ymaster now
	if [ "$led2a_trigger" != "netdev" ]; then
		uci set system.LED2a.trigger=netdev
		changed=1
	fi
	if [ "$led2g_trigger" != "none" ]; then
		uci set system.LED2g.trigger=none
		changed=1
	fi
elif [ `iwconfig wlan1 2>/dev/null | awk '/ESSID:"/ {print 1}'` ]; then
	# running as ystation or yclient now
	if [ "$led2a_trigger" != "none" ]; then
		uci set system.LED2a.trigger=none
		changed=1
	fi
	if [ "$led2g_trigger" != "netdev" ]; then
		uci set system.LED2g.trigger=netdev
		changed=1
	fi
else
	# not connected
	if [ "$led2a_trigger" != "none" ]; then
		uci set system.LED2a.trigger=none
		changed=1
	fi
	if [ "$led2g_trigger" != "none" ]; then
		uci set system.LED2g.trigger=none
		changed=1
	fi
fi

#
# YScanBox
#
local yscanner_pid=`pgrep -n yscanner`
local yheartbeat_pid=`pgrep -n yheartbeat`
local led3_delayon=`uci get system.LED3.delayon`
local led3_delayoff=`uci get system.LED3.delayoff`

if [ -z $yheartbeat_pid ]; then
	if [ -z $yscanner_pid ]; then
		# both not running (led off)
		if [ "$led3_delayon" != "0" ]; then
			uci set system.LED3.delayon=0
			changed=1
		fi
		if [ "$led3_delayoff" != "1000" ]; then
			uci set system.LED3.delayoff=1000
			changed=1
		fi
	else
		# yscanner only (flash with short delay)
		if [ "$led3_delayon" != "900" ]; then
			uci set system.LED3.delayon=900
			changed=1
		fi
		if [ "$led3_delayoff" != "100" ]; then
			uci set system.LED3.delayoff=100
			changed=1
		fi
	fi
else # yheartbeat running
	if [ -z $yscanner_pid ]; then
		# yheartbeat only (flash with long delay)
		if [ "$led3_delayon" != "100" ]; then
			uci set system.LED3.delayon=100
			changed=1
		fi
		if [ "$led3_delayoff" != "900" ]; then
			uci set system.LED3.delayoff=900
			changed=1
		fi
	else
		# both running (solid)
		if [ "$led3_delayon" != "1000" ]; then
			uci set system.LED3.delayon=1000
			changed=1
		fi
		if [ "$led3_delayoff" != "0" ]; then
			uci set system.LED3.delayoff=0
			changed=1
		fi
	fi
fi

#
# set Time led
#
local led4_trigger=`uci get system.LED4.trigger`
local this_year=$(date +"%Y")
if [ "$this_year" -gt "2000" ]; then
	[ "led4_trigger" != "default-on" ] && {
		uci set system.LED4.trigger=default-on
		changed=1
	}
else
	[ "led4_trigger" != "none" ] && {
		uci set system.LED4.trigger=none
		changed=1
	}
fi

#
# reload LEDs if changed
#
if [ $changed -eq 1 ]; then
	uci commit system
	/etc/init.d/led reload &>/dev/null
fi
