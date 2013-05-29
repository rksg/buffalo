#!/bin/sh

LOGGER="logger $@"

. /etc/profile


if [ -f /ybox/init.conf ]; then

	. /ybox/init.conf

	YSCANNER_PID=`pgrep -n yscanner`
	if [ -n YSCANNER_PID ]; then
		kill -TERM $YSCANNER_PID
		sleep 1
	fi

	if [ -z `pgrep -n yscanner` ]; then
		/usr/bin/yscanner
	fi

else

	LOGGER "Not restarting yscanner due to missing /ybox/init.conf"

fi
