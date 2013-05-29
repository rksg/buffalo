#!/bin/sh

#
# name      : init.sh
# version   : 1.1
# author    : shooperman@gmail.com
# date      : 23 August 2012
# copyright : YFind Technologies Pte Ltd
#
# This init is run once right after a Ybox flash. It is triggered from rc.local.
#

LOGGER="logger -p user.info $0 >> "
init_config_file="/ybox/init.conf"

# remove unused configs
[ -e '/etc/config/ntpclient' ] && `rm /etc/config/ntpclient`
[ -e '/etc/hotplug.d/iface/20-ntpclient' ] && `rm /etc/hotplug.d/iface/20-ntpclient`

# get ybox MAC
YBOX_MAC=`ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | sed 's/://g' | tr [a-z] [A-Z]`
YBOX_IFNAME=`iwconfig 2>1 | grep Mode:Monitor | awk '{print $1}'`

# pull from system.yfound.com if missing init.conf
if [ ! -f $init_config_file ] ; then
	`wget -q -O $init_config_file http://system.yfound.com/yboxes/$YBOX_MAC/init.conf`
fi

# pull from system.dev.yfound.com if missing init.conf
if [ ! -f $init_config_file ] ; then
	`wget -q -O $init_config_file http://system.dev.yfound.com/yboxes/$YBOX_MAC/init.conf`
fi

# use sample config if set
if [ -n "$USE_SAMPLE_CONFIG" ] ; then
	`cp /ybox/sample_init.conf $init_config_file`
fi

if [ ! -f $init_config_file ] ; then
	$LOGGER "cannot wget from 'http://system.yfound.com/yboxes/${YBOX_MAC}/init.conf', stopped."
	sleep 30
	reboot -f
fi

echo "YBOX_MAC=${YBOX_MAC}" >> $init_config_file
echo "YBOX_IFNAME=${YBOX_IFNAME}" >> $init_config_file

source $init_config_file

#
# Configure Ybox
#

# update ybox password to default
passwd <<EOF
yf1nd3r123
yf1nd3r123
EOF

# update /etc/config/system
`uci set system.@system[0].hostname=${YBOX_VENUE_ID}${YBOX_ID}`
`uci set system.@system[0].zonename=${YBOX_ZONENAME}`
`uci set system.@system[0].timezone=${YBOX_TIMEZONE}`

# update /etc/config/wireless
`uci set wireless.@wifi-iface[1].ssid=ymaster${YBOX_MASTER}`
`uci set wireless.@wifi-iface[2].ssid=ymaster${YBOX_MASTER2}`
`uci set wireless.@wifi-iface[3].ssid=ymaster${YBOX_ID}`

if [ $YBOX_MODE == 'M' ]; then
	`uci set network.lan.ipaddr=192.168.10.1`
	`uci set wireless.@wifi-iface[1].disabled=1`
	`uci set wireless.@wifi-iface[2].disabled=1`
	`uci set wireless.@wifi-iface[3].disabled=0`
	sed -i "s/#HH/1/" /etc/crontabs/root
else
	`uci set network.lan.ipaddr=192.168.20.1`
	`uci set wireless.@wifi-iface[1].disabled=0`
	`uci set wireless.@wifi-iface[2].disabled=1`
	`uci set wireless.@wifi-iface[3].disabled=1`
	sed -i "s/#HH/5/" /etc/crontabs/root
fi


# update /etc/config/autossh
ssh_option="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -N -T -R 5${YBOX_ID}${YBOX_VENUE_INSTANCE}:localhost:22 yfinder@${YBOX_VENUE_SERVER}"
`uci set autossh.@autossh[0].ssh="${ssh_option}"`

# uncomment to save changes
`uci commit`


#
# some housekeeping
#

# change permissions for id_rsa
chmod 400 /root/.ssh/id_rsa

# disable unnecessary utilities
[ -e '/etc/init.d/sysntpd' ] && `/etc/init.d/sysntpd disable`

reboot




