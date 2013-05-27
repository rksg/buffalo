#!/bin/sh

LOGGER="logger $@"

. /etc/profile


if [ -f /ybox/init.conf ]; then

	YEAR=$(date +"%Y")
	if [ "$YEAR" -ne 1970 ]; then

		. /ybox/init.conf

		if [ -z `pgrep -n yheartbeat` ]; then
			$LOGGER "yheartbeat is down, starting it."
			/usr/bin/yheartbeat
			sleep 3
		fi

		if [ -z `pgrep -n yscanner` ]; then
			$LOGGER "yscanner is down, starting it."
			/usr/bin/yscanner
		fi

	else
		$LOGGER "Not starting yscanbox as time is not yet set."
	fi

else

	$LOGGER "Not starting yscanbox due to missing /ybox/init.conf"

fi
