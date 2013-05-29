#!/bin/sh

# gzips *.log except the latest one (might still be in use)
i=0
for file in `ls -t /ybox/log/*.log`; do
  if [ $i -gt 0 ]; then
    gzip $file
  fi
  let "i++"
done

# keep at most 7 backups of *.gz
i=0
for file in `ls -t /ybox/log/*.gz`; do
  let "i++"
  if [ $i -gt 7 ]; then
    rm $file
  fi  
done
