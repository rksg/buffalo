#!/bin/sh 

# Assumes default the default 'wan1' - i.e. wan port on router.
# Pings 8.8.4.4, routed via wan in /etc/config/network, every 10 seconds:
#   - if fail and not using wan2, ifup wan2, i.e. 3G
#   - if pass and using wan2, ifdown wan2.

check_process() {
  [ `pgrep -n $1` ] && return 1 || return 0
}

wait_till_time_is_set() {
  NTPC_CMD=`which ntpclient`
  YEAR=$(date +"%Y")
  while [ "$YEAR" -eq 1970 ]; do
    NTP_PID=$(pgrep -n ntpclient)
    [ -z $NTP_PID ] || kill $NTP_PID
    $NTPC_CMD -i 300 -s -l -h 0.pool.ntp.org -p 123
    sleep 5
  done
}


LOGGER="logger $@"

# test if failover.sh should run
init_config_file="/ybox/init.conf"
if [ -e $init_config_file ]; then
    source $init_config_file
else
    # missing init.conf, newly-flashed, don't run failover
    exit
fi

SHORT_INTERVAL=5
LONG_INTERVAL=30
FIRST_INTERVAL=$LONG_INTERVAL
FAILOVER_INTERVAL=$SHORT_INTERVAL
PING_HOST1="8.8.8.8"
PING_HOST2="8.8.4.4"
PING_PACKETS=1
PING_RETRIES=5
PING_WAIT=2
PING_FAILS_TO_SWITCH=2
PING_INTERVAL=1
AUTOSSH_COUNT=0
INTERVALS_TO_CHECK_AUTOSSH=3

WAN1=wan1
WAN2=wan2
WAN1_IF=`uci show network.$WAN1.ifname | awk -F = '{print $2}'`
WAN2_IF=`uci show network.$WAN2.ifname | awk -F = '{print $2}'`
USINGWAN=0
WAIT_3G=10
WAN2_IFDOWNED=0

sleep $FIRST_INTERVAL
$LOGGER "started..."

if [ $YBOX_MODE == 'M' ]; then

  ########################
  #                      #
  # Master Mode Failover #
  #                      #
  ########################

  while sleep $FAILOVER_INTERVAL; do

    if [ "$USINGWAN" = "0" ]; then
      # no wan available, keep looking until we get one

      $LOGGER "looking for wan..."

      WAN1_AVAIL=`ifconfig $WAN1_IF 2>/dev/null | awk '{if($1=="inet")print $2}' | awk -F : '{print $2}'`
      WAN2_AVAIL=`ifconfig $WAN2_IF 2>/dev/null | awk '{if($1=="inet")print $2}' | awk -F : '{print $2}'`

      if [ "$WAN1_AVAIL" ]; then
        # do a test ping
        RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST2 2>/dev/null | awk '/received/ {print $4}'`
        [ -z $RET ] && RET=0

        if [ "$RET" -eq "$PING_PACKETS" ]; then
          $LOGGER "wan1 up."
          FAILOVER_INTERVAL=$LONG_INTERVAL
          USINGWAN=1
          ifdown $WAN2
          WAN2_IFDOWNED=0
          wait_till_time_is_set

        else
          $LOGGER "wan1 no connectivity."
        fi

      else
        $LOGGER "wan1 not available."
      fi
      
      # wan1 not available or no connectivity, check wan2
      if [ "$USINGWAN" = "0" ]; then

        if [ "$WAN2_AVAIL" ]; then

          # if it was previously downed, up it again
          if [ "$WAN2_IFDOWNED" = "1" ]; then
            $LOGGER "wan2 downed previously, ifup it."
            ifup $WAN2
            WAN2_IFDOWNED=0
            sleep $WAIT_3G
          fi

          # do a ping test
          RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST1 2>/dev/null | awk '/received/ {print $4}'`
          [ -z $RET ] && RET=0

          if [ "$RET" -eq "$PING_PACKETS" ]; then
            $LOGGER "wan2 up."
            FAILOVER_INTERVAL=$LONG_INTERVAL
            USINGWAN=2
            wait_till_time_is_set

          else
            $LOGGER "wan2 no connectivity"
          fi

        else
          $LOGGER "wan2 not available."
        fi
      fi

    else
      # there's a current USINGWAN, check it

      RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST1 2>/dev/null | awk '/received/ {print $4}'`
      [ -z $RET ] && RET=0

      if [ "$RET" -eq "$PING_PACKETS" ]; then 
        #
        # wan is still up
        #

        FAILOVER_INTERVAL=$LONG_INTERVAL

        if [ "$USINGWAN" = "1" ]; then
          # see if 3g wan is up, if so, ifdown it to save $$$
          WAN2_AVAIL=`ifconfig $WAN2_IF 2>/dev/null | awk '{if($1=="inet")print $2}' | awk -F : '{print $2}'`
          if [ "$WAN2_AVAIL" ]; then
            $LOGGER "wan1 already up, ifdown wan2 (3G)."
            WAN2_IFDOWNED=1
            ifdown $WAN2
          fi
        fi

        if [ "$USINGWAN" = "2" ]; then
          # see if wan (eth1) is back
          WAN1_AVAIL=`ifconfig $WAN1_IF 2>/dev/null | awk '{if($1=="inet")print $2}' | awk -F : '{print $2}'`

          if [ "$WAN1_AVAIL" ]; then
            RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST2 2>/dev/null | awk '/received/ {print $4}'`
            [ -z $RET ] && RET=0

            if [ "$RET" -eq "$PING_PACKETS" ]; then
              $LOGGER "wan1 now up, ifdown wan2 (3G)."
              USINGWAN=1
              ifdown $WAN2
              WAN2_IFDOWNED=1
            fi
          fi
        fi
    
        # check autossh
        AUTOSSH_COUNT=`expr $AUTOSSH_COUNT + 1`
        if [ "$AUTOSSH_COUNT" -eq "$INTERVALS_TO_CHECK_AUTOSSH" ]; then
          AUTOSSH_COUNT=0
          check_process "autossh"
          [ $? -eq 0 ] && `/etc/init.d/autossh start`
        fi

      else
        #
        # lost wan
        #
        $LOGGER "lost connectivity on wan${USINGWAN}..."
        
        # retry pings
        PING_COUNT=0
        while [ "$PING_COUNT" -lt "$PING_RETRIES" ]; do
          RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST1 2>/dev/null | awk '/received/ {print $4}'`
          [ -z $RET ] && RET=0
          [ "$RET" -eq "$PING_PACKETS" ] && break
          PING_COUNT=`expr $PING_COUNT + 1`
          sleep $PING_INTERVAL
        done

        if [ "$RET" -eq "$PING_PACKETS" ]; then
          $LOGGER "wan${USINGWAN} connectivity back up."
          FAILOVER_INTERVAL=$LONG_INTERVAL

        else
          $LOGGER "wan${USINGWAN} no more connectivity."
          FAILOVER_INTERVAL=$SHORT_INTERVAL
          USINGWAN=0
        fi
      fi
    fi
  done

else

  #########################
  #                       #
  # Scanner Mode Failover #
  #                       #
  #########################

  USING_MASTER2=0
  PING_CHECKS_FAILED=0
  while sleep $FAILOVER_INTERVAL; do

    RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST1 2>/dev/null | awk '/received/ {print $4}'`
    [ -z $RET ] && RET=0

    if [ "$RET" -eq "$PING_PACKETS" ]; then
      #
      # connectivity is available, check services
      #

      FAILOVER_INTERVAL=$LONG_INTERVAL

      wait_till_time_is_set

      # check autossh
      AUTOSSH_COUNT=`expr $AUTOSSH_COUNT + 1`
      if [ "$AUTOSSH_COUNT" -eq "$INTERVALS_TO_CHECK_AUTOSSH" ]; then
        AUTOSSH_COUNT=0
        check_process "autossh"
        [ $? -eq 0 ] && $LOGGER "autossh down, restarting it" && `/etc/init.d/autossh start`
      fi

    else
      $LOGGER "wifi lost..."

      # retry pings
      PING_COUNT=0
      while [ "$PING_COUNT" -lt "$PING_RETRIES" ]; do
        RET=`ping -w $PING_WAIT -c $PING_PACKETS $PING_HOST1 2>/dev/null | awk '/received/ {print $4}'`
        [ -z $RET ] && RET=0
        [ "$RET" -eq "$PING_PACKETS" ] && break
        PING_COUNT=`expr $PING_COUNT + 1`
        sleep $PING_INTERVAL
      done

      if [ "$RET" -eq "$PING_PACKETS" ]; then
        $LOGGER "wifi back up."
        FAILOVER_INTERVAL=$LONG_INTERVAL

      else
        $LOGGER "no more wifi."
        FAILOVER_INTERVAL=$SHORT_INTERVAL
        PING_CHECKS_FAILED=`expr $PING_CHECKS_FAILED + 1`
        if [ "$PING_CHECKS_FAILED" -eq "$PING_FAILS_TO_SWITCH" ]; then
          PING_CHECKS_FAILED=0
          if [ "$USING_MASTER2" -eq 0 ]; then
            USING_MASTER2=1
            logger "switching to 'ymaster${YBOX_MASTER2}'"
            `uci set wireless.@wifi-iface[1].disabled=1`
            `uci set wireless.@wifi-iface[2].disabled=0`
            `uci commit`
            `wifi`
          else
            USING_MASTER2=0
            logger "switching back to 'ymaster${YBOX_MASTER}'"
            `uci set wireless.@wifi-iface[1].disabled=0`
            `uci set wireless.@wifi-iface[2].disabled=1`
            `uci commit`
            `wifi`
          fi
        fi
      fi

    fi

  done


fi
