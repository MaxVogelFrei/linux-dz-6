#!/bin/bash
linefile=/var/log/dz6/line
logfile=/var/log/dz6/access.log
original=/var/log/dz6/access-4560-644067.log
rm $logfile
cp $original $logfile
sed -i "s/14\/Aug/$(date +%d'\/'%b)/g" $logfile
sed -i "s/15\/Aug/$(date -d '+ 1 Day' +%d'\/'%b)/g" $logfile
echo "1" > $linefile

