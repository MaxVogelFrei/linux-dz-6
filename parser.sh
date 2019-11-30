#!/bin/bash
logpath=/var/log/dz6
logfile=$logpath/access.log
report=$logpath/report.txt
lockfile=/tmp/parserlockfile
if ( set -o noclobber; echo "$$" > "$lockfile") 2> /dev/null;
then
    trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT
    while true
    do
if [[ $(find /var/log/dz6 -type f -name "line") ]]
then linefile=$(find $logpath/ -type f -name "line")
else
touch $logpath/line
linefile=$(find $logpath/ -type f -name "line")
echo "1" > $linefile
fi
rm -f $report
read lastline < $linefile
startline=$lastline
currentdate=`date '+%s'`
timeinline=`date --date="$(awk -F" " -v line="$lastline" 'NR==line {print $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /')" '+%s'`
function get_lastline {
var1=$1
var2=$2
if
        [ "$var1" -lt "$var2" ]
then
        while [ $var1 -lt $var2 ]
                do
                ((lastline++))
                var1=`date --date="$(awk -F" " -v line="$lastline" 'NR==line {print $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /')" '+%s'`
                done
else
        echo 'date in last line is not lower, nothing to do'
fi
((lastline--))
return $lastline
}
get_lastline $timeinline $currentdate
if
[ "$lastline" -eq  "$startline" ]
then
exit 1
fi
echo "$lastline" > "$linefile"
touch $report
awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1 {print "START TIME: " $4}; NR==line2 {print "END TIME: " $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /' > $report
echo "Top 10 IP" >> $report
awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 {print " : " $1}' $logfile  | sort | uniq -c | sort -rn | head -n 10 >> $report
echo "Top 10 URL" >> $report
awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 {print " : " $7}' $logfile  | sort | uniq -c | sort -rn | head -n 10 >> $report
echo "Codes" >> $report
awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 { if (match($9,/[0-9][0-9][0-9]/,m)) print " : " m[0] }' $logfile  | sort | uniq -c | sort -rn >> $report
echo "Errors" >> $report
awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 { if (match($9,/[45]../,m)) print " : " m[0] }' $logfile  | sort | uniq -c | sort -rn >> $report
sendmail root@localhost < $report
cat $report
done
rm -f "$lockfile"
trap - INT TERM EXIT
else
   echo "Failed to acquire lockfile: $lockfile."
   echo "Held by $(cat $lockfile)"
fi

