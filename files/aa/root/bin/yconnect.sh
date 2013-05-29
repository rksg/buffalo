#!/bin/sh /etc/rc.common
#
# name      : /root/bin/connected.sh
# version   : 2.0
# author    : shooperman@gmail.com
# date      : 1 March 2013
# copyright : YFind Technologies Pte Ltd
# remarks   : replaces failover.sh
#

config_load 'ybox'

#
# configuration
#

NO_IFACE=none
IFACE1=eth1
IFACE2=3g-wan2
IFACE3=wlan1
WAN1=wan1
WAN2=wan2
WAN3=radio1
CARRIER1=/sys/class/net/$IFACE1/carrier
CARRIER2=/sys/class/net/$IFACE2/carrier
CARRIER3=/sys/class/net/$IFACE3/carrier
WAIT_3G=10

config_get DEBUG $CONFIG_SECTION 'connected_debug'
config_get DELAY0 $CONFIG_SECTION 'connected_delay0'
config_get DELAY1 $CONFIG_SECTION 'connected_delay1'
config_get DELAY2 $CONFIG_SECTION 'connected_delay2'
config_get DELAY3 $CONFIG_SECTION 'connected_delay3'
config_get PING_IP $CONFIG_SECTION 'connected_ping_ip'

if [ $DEBUG -eq 1 ]; then
  DELAY0=5  # when there's no connection
  DELAY1=5  # on wan1 (eth)
  DELAY2=5  # on wan2 (3g)
  DELAY3=5  # on wan3 (wlan)
fi

#
# functions
#

update_leds() {
  /root/bin/update_leds.sh
}

default_and_current_iface() {
  local temp_iface
  local temp_carrier

  # defaults to no-iface
  CURRENT_IFACE=$NO_IFACE

  # gets default iface
  temp_iface=`route 2>/dev/null | awk '{if($1=="default")print $8}'`
  [ $temp_iface ] && DEFAULT_IFACE=$temp_iface || DEFAULT_IFACE=$NO_IFACE

  # check that it's operational
  if [ $temp_iface ]; then

    # set carrier
    [ $temp_iface = "$IFACE1" ] && temp_carrier=$CARRIER1
    [ $temp_iface = "$IFACE2" ] && temp_carrier=$CARRIER2
    [ $temp_iface = "$IFACE3" ] && temp_carrier=$CARRIER3

    if [ -f $temp_carrier ] && TEMP=`cat $temp_carrier 2>/dev/null` &&  [ $TEMP ] && [ ${TEMP:0:1} = "1" ]; then
      CURRENT_IFACE=$temp_iface
    fi
  fi
}

first_iface() {
  local temp 

  FIRST_IFACE=$NO_IFACE

  if [ -f $CARRER1 ] && temp=`cat $CARRIER1 2>/dev/null` &&  [ $temp ] && [ ${temp:0:1} = "1" ]; then
    FIRST_IFACE=$IFACE1
    return
  fi

  if [ -f $CARRER2 ] && temp=`cat $CARRIER2 2>/dev/null` &&  [ $temp ] && [ ${temp:0:1} = "1" ]; then
    FIRST_IFACE=$IFACE2
    return
  fi

  if [ -f $CARRER3 ] && temp=`cat $CARRIER3 2>/dev/null` &&  [ $temp ] && [ ${temp:0:1} = "1" ]; then
    FIRST_IFACE=$IFACE3
    return
  fi
}


#
# set up
#

DELAY=$DELAY0
MY_YBOXID=`hostname`
MY_YBOXID=${MY_YBOXID:2:3}

update_leds

while true; do

  first_iface
  default_and_current_iface

  [ $DEBUG -eq 1 ] && logger -t yconnect "DEBUG>>> curr:$CURRENT_IFACE 1st:$FIRST_IFACE def:$DEFAULT_IFACE"

  if [ $CURRENT_IFACE = "$NO_IFACE" ]; then

    ###
    # current interface: none
    ###

    # first iface: eth1
    if [ $FIRST_IFACE = "$IFACE1" ]; then
      logger -t yconnect "detected and switching to '$FIRST_IFACE'"
      ifup $WAN1
      update_leds

    # first iface: 3g-wan2
    elif [ $FIRST_IFACE = "$IFACE2" ]; then
      logger -t yconnect "detected and switching to '$FIRST_IFACE'"
      ifup $WAN2
      sleep $WAIT_3G
      update_leds

    # first iface: wlan1
    elif [ $FIRST_IFACE = "$IFACE3" ]; then
      #
      # NOTE:
      #   We don't switch to Station mode as this will propagate
      #   a chaotic switching manic through the YBox wlan. Hence,
      #   this chunk here simply ensures re-ups wlan1.
      #
      wifi up $WAN3 &> /dev/null
      logger -t yconnect "detected and switching to '$FIRST_IFACE'"
      update_leds

    else
      logger -t yconnect "no connectivity available"
    fi

    DELAY=$DELAY0  # short delay till next check for curr-iface

  elif [ $CURRENT_IFACE = "$IFACE1" ]; then

    ###
    # current interface: eth1
    ###

    DELAY=$DELAY1

  elif [ $CURRENT_IFACE = "$IFACE2" ]; then

    ###
    # current interface: 3g-wan2
    ###

    DELAY=$DELAY2

    # if eth1 available, switch to it
    if [ $FIRST_IFACE = "$IFACE1" ]; then
      RESULT=`ping -c 1 -s 1 -I $FIRST_IFACE -W 5 -q $PING_IP 2>/dev/null | awk '/received/ {print $4}'`
      [ -z $RESULT ] && RESULT=0
      if [ $RESULT -eq 1 ]; then
        logger -t yconnect "'$FIRST_IFACE' came up, switching to it"
        ifup $WAN1
        DELAY=$DELAY1
        update_leds
      fi
    fi

  elif [ $CURRENT_IFACE = "$IFACE3" ]; then

    ###
    # current interface: wlan1
    ###

    DELAY=$DELAY3

    # if eth1 or 3g-wan2 is available, use it, ping it and upgrade to Master mode
    if [ $FIRST_IFACE != "$IFACE3" ]; then

      # ping through it to check that it's working first
      RESULT=`ping -c 1 -s 1 -I $FIRST_IFACE -W 5 -q $PING_IP 2>/dev/null | awk '/received/ {print $4}'`
      [ -z $RESULT ] && RESULT=0

      if [ "$RESULT" -eq 1 ]; then  # can ping through eth1/3g-wan2

        # if eth1 available, switch to it
        if [ $FIRST_IFACE = "$IFACE1" ]; then
          logger -t yconnect "'$FIRST_IFACE' came up, switching to it"
          ifup $WAN1
          DELAY=$DELAY1
          update_leds

        # if 3g available, switch to it
        elif [ $FIRST_IFACE = "$IFACE2" ]; then
          logger -t yconnect "'$FIRST_IFACE' came up, switching to it"
          ifup $WAN2
          sleep $WAIT_3G
          DELAY=$DELAY2
          update_leds
        fi

        # switch to and operate as Master
        uci set wireless.ymaster.disabled=0
        uci set wireless.ystation.disabled=1
        uci commit
        wifi up $WAN3

      fi

    else  # still on wlan1

      RESULT=`ping -c 1 -s 1 -I $FIRST_IFACE -W 5 -q $PING_IP 2>/dev/null | awk '/received/ {print $4}'`
      [ -z $RESULT ] && RESULT=0

      if [ "$RESULT" -eq 0 ]; then  # cannot ping through current Master

        logger -t yconnect "'$FIRST_IFACE' ping failed"

        # perform a scan and update ap.list
        config_get venue_idx $CONFIG_SECTION 'venue_idx'
        config_get wifi_iface $CONFIG_SECTION 'wifi_iface'
        config_get scanlog_file $CONFIG_SECTION 'scanlog_file'
        config_get aplist_file $CONFIG_SECTION 'aplist_file'

        [ -f $scanlog_file ] && `rm $scanlog_file; touch $scanlog_file`
        [ -f $aplist_file ] && `rm $aplist_file; touch $aplist_file`

        [ $DEBUG -eq 1 ] && logger -t yconnect "DEBUG>>> scanning APs..."
        while [ ! -s $scanlog_file ]; do
          iwlist $wifi_iface scanning 2>/dev/null > $scanlog_file
          sleep 2
        done

        [ $DEBUG -eq 1 ] && logger -t yconnect "DEBUG>>> processing APs..."
        ii=1
        onecell_file=/tmp/onecell.tmp
        num_aps=$(grep -c "ESSID:" $scanlog_file)
        temp_yboxid="1${MY_YBOXID}"  # to avoid the bash-octal conversion
        min_masterid=`expr $((temp_yboxid)) - 25`
        max_masterid=`expr $((temp_yboxid)) + 25`

        while [ "$ii" -le "$num_aps" ]; do
          if [ $ii -lt 10 ]; then
            this_cell=$(echo "Cell 0$ii - Address:")
          else
            this_cell=$(echo "Cell $ii - Address:")
          fi
          jj=`expr $ii + 1`
          if [ $jj -lt 10 ]; then
            next_cell=$(echo "Cell 0$jj - Address:")
          else
            next_cell=$(echo "Cell $jj - Address:")
          fi
          awk '/'"$this_cell"'/ {p=1}p' $scanlog_file | awk '/'"$next_cell"'/ {exit}1' > $onecell_file

          # there's a MAC match, i.e. '- Address: 88:88:88:'
          if [ `awk '/- Address: 88:88:88:'"$venue_idx"':/ {print 1}' $onecell_file` ]; then
            if [ `awk '/ESSID:""/ {print 1}' $onecell_file` ]; then
              this_mac=`awk '/'"$this_cell"'/ {sep=":";if ($5~/-/)sep="-";split($5,x,sep);print x[1]x[2]x[3]x[4]x[5]x[6]}' $onecell_file`
              this_masterid=`printf "%03d\n" 0x${this_mac:8:4}`
              temp_masterid="1${this_masterid}"  # to avoid the bash-octal conversion
              if [ $((temp_masterid)) -ge $min_masterid ]; then 
                if [ $((temp_masterid)) -le $max_masterid ]; then
                  this_strength=`awk '/^[ \t]+Quality/ {print $0}' $onecell_file | cut -d '/' -f 1 | cut -d '=' -f 2`
                  echo "${this_strength} ymaster${this_masterid}" >> $aplist_file
                fi
              fi
            fi
          fi

          ii=`expr $ii + 1`
        done

        sort -nr $aplist_file > "${aplist_file}.tmp"
        mv "${aplist_file}.tmp" $aplist_file

        # get current master
        old_master_ssid=`uci get wireless.ystation.ssid`

        # create list after $old_master_ssid
        awk '/'"$old_master_ssid"'/ {p=1}p' $aplist_file > ${aplist_file}.tmp
        temp=`wc -l ${aplist_file}.tmp | awk '{print $1}'`

        # if cannot find or last master, recycle the entire aplist
        if [ $((temp)) -le 1 ]; then
          cat $aplist_file > ${aplist_file}.tmp
        fi

        # Go through all valid Masters
        [ $DEBUG -eq 1 ] && logger -t yconnect "DEBUG>>> choosing a Master..."
        cat ${aplist_file}.tmp | while read this_line; do
          this_master_ssid=`echo $this_line | cut -d ' ' -f 2`
          if [ "$this_master_ssid" != "$old_master_ssid" ]; then
            logger -t yconnect "'$FIRST_IFACE' switching to '$this_master_ssid'"
            uci set wireless.ystation.ssid="$this_master_ssid"
            uci commit wireless
            wifi up $WAN3 &> /dev/null
            update_leds
          fi
        done

      fi
    fi
  fi

  sleep $DELAY

done 
