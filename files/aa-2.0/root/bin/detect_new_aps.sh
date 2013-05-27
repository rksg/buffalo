#!/bin/sh

local ssid
local outfile
local match_string
local tmp_scan_out
local tmp_cell_out
local detected_aps
local aps_and_ids
local num_cells
local this_cell
local next_cell
local this_mac0
local this_mac1
local this_id
local ii
local jj
local cc
local ss
local temp

[ ! $1 ] && echo Usage: ./detect_new_aps.sh AP_NAME [OUTFILE]
ssid=$1
if [ $2 ]; then
  outfile=$2
else
  outfile=new_aps.txt
fi

if [ -f $outfile ]; then
  echo "output will be added to '$outfile'"
else
  touch $outfile
  echo "output will be written to '$outfile"
fi

tmp_scan_out=/tmp/scan.tmp
tmp_cell_out=/tmp/cell.tmp
tmp_aps_out=/tmp/aps.tmp

[ -f $tmp_scan_out ] && rm $tmp_scan_out
[ -f $tmp_cell_out ] && rm $tmp_cell_out

ss=1

while [ true ]; do 

  echo ""
  echo "Scanning Session: #$ss (ctrl-c to exit) ..."
  iwlist wlan1 scanning 2>/dev/null > $tmp_scan_out

  if [ -s $tmp_scan_out ]; then
    num_cells=$(grep -c "ESSID:" $tmp_scan_out)
    ii=1
    cc=0

    while [ "$ii" -le "$num_cells" ]; do
      #
      # pull out one cell into $tmp_cell_out
      #
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

      awk '/'"$this_cell"'/ {p=1}p' $tmp_scan_out | awk '/'"$next_cell"'/ {exit}1' > $tmp_cell_out

      # there's a AP match
      if [ `awk '/ESSID:"'"$ssid"'/ {print 1}' $tmp_cell_out` ]; then
        this_mac1=`awk '/'"$this_cell"'/ {sep=":";if ($5~/-/)sep="-";split($5,x,sep);print x[1]x[2]x[3]x[4]x[5]x[6]}' $tmp_cell_out`
        temp=$((0x`echo $this_mac1` - 1))
        this_mac0=`printf '%x' $temp | tr [a-z] [A-Z]`

        # see if it's a newly discovered AP
        if [ `grep -c $this_mac1 $outfile` = "0" ]; then

          this_id=
          while [ ! $this_id ]; do
            # prompt user for ybox-id NNN
            read -p "   YBox-ID for '${ssid}-${this_mac0:6:6}' (NNN): " this_id

            [ $this_id ] && [ ${#this_id} -ne 3 ] && this_id=
            [ $this_id ] && [ ! `echo $this_id | awk '/[0-9]{3}/ {print $0}'` ] && this_id=

            [ ! $this_id ] && echo "   >>> YBox-ID has to be a 3-digit number, e.g. '013'"
          done

          echo -e "$this_id\t$this_mac0\t$this_mac1" >> $outfile
          cc=`expr $cc + 1`

        fi # $this_mac not in $outfile
      fi # there's a AP match

      ii=`expr $ii + 1`

    done # while there're cells to process

    echo "   ... Added $cc new APs"

  fi # there's a scan output

  ss=`expr $ss + 1`
  sleep 1

done # infinite loop

