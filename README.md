# Домашнее задание 6 - BASH

## Задание
	написать скрипт для крона
	который раз в час присылает на заданную почту
	* X IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
	* Y запрашиваемых адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
	* все ошибки c момента последнего запуска
	* список всех кодов возврата с указанием их кол-ва с момента последнего запуска
	в письме должно быть прописан обрабатываемый временной диапазон
	должна быть реализована защита от мультизапуска

## Процесс решения

Скрипт будет обрабатывать файл лога находящийся по пути /var/log/dz6/access.log
Там же будет лежать файл line для хранения последней обработанной строки
использую /tmp/parserlockfile для защиты от повторного запуска

### подготовка лога

скрипт update.log.sh удаляет имеющийся лог, копирует оригинал из задачи в access.log, и пишет 1 в файл хранящий номер строки 
через sed заменяю даты 14 Aug на текущую дату, 15 Aug на текущую +1 день

	#!/bin/bash
	linefile=/var/log/dz6/line
	logfile=/var/log/dz6/access.log
	original=/var/log/dz6/access-4560-644067.log
	rm $logfile
	cp $original $logfile
	sed -i "s/14\/Aug/$(date +%d'\/'%b)/g" $logfile
	sed -i "s/15\/Aug/$(date -d '+ 1 Day' +%d'\/'%b)/g" $logfile
	echo "1" > $linefile

### обработка лога
задаю переменные 
linefile - файл с позицией в логе, logfile - сам лог, 
report - файл с отчетом полученным из скрипта, который отправлю на почту,
parserlockfile - метка для защиты от повторного запуска


	#!/bin/bash
	linefile=/var/log/dz6/line
	logfile=/var/log/dz6/access.log
	report=/var/log/dz6/report.txt
	lockfile=/tmp/parserlockfile

условие защищающее от повторного запуска

	if ( set -o noclobber; echo "$$" > "$lockfile") 2> /dev/null;
	then
		trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT
		while true
		do

удаляю прошлый отчет, читаю сохраненную позицию в логе,
делаю startline равной lastline

			rm -f $report
			read lastline < $linefile
			startline=$lastline

получаю текущую дату и дату из последней обработанной строки

			currentdate=`date '+%s'`
			timeinline=`date --date="$(awk -F" " -v line="$lastline" 'NR==line {print $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /')" '+%s'`

функция получающая новый номер строки соответствующей текущему времени для ограничения выборки из лога
сравниваю значение от последнего запуска с текущим временем


			function get_lastline {
			var1=$1
			var2=$2
			if
			[ "$var1" -lt "$var2" ]
			then

цикл "пока время считанное из строки меньше чем текущее -продолжаю, в другом случае ничего не делаю"

			        while [ $var1 -lt $var2 ]
			                do
			                ((lastline++))
			                var1=`date --date="$(awk -F" " -v line="$lastline" 'NR==line {print $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /')" '+%s'`
			                done
			else
			        echo 'date in last line is not lower, nothing to do'
			fi

как результат функция выдает номер строки - 1, т.к. последняя итерация  в цикле даст строку со временем больше, чем текущее

			((lastline--))
			return $lastline
			}

передаю в функцию два значения "время из строки" и "текущее время"

			get_lastline $timeinline $currentdate

если номер строки на выходе совпадет с тем что я сохранил в переменную startline то выходим с ошибкой

			if
			[ "$lastline" -eq  "$startline" ]
			then
				exit 1
			fi

сохраняю номер строки в файл для следующего запуска

			echo "$lastline" > "$linefile"

формирую отчет, использую awk между startline и lastline
делаю сортировку по порядку, считаю количество повторов
сортирую по количеству повторов
оставляю первую десятку

			touch $report
			awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1 {print "START TIME: " $4}; NR==line2 {print "END TIME: " $4}' $logfile | sed -e 's/\[//;s/\// /g;s/:/ /' > $report
			echo "Top 10 IP" >> $report
			awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 {print " : " $1}' $logfile  | sort | uniq -c | sort -rn | head -n 10 >> $report
			echo "Top 10 URL" >> $report
			awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 {print " : " $7}' $logfile  | sort | uniq -c | sort -rn | head -n 10 >> $report

для отображения кодов возврата дополнительно исключаю нечисловые записи

			echo "Codes" >> $report
			awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 { if (match($9,/[0-9][0-9][0-9]/,m)) print " : " m[0] }' $logfile  | sort | uniq -c | sort -rn >> $report

для отображения ошибок дополнительно исключаю результаты кроме 4/5**

			echo "Errors" >> $report
			awk -F" " -v line1="$startline" -v line2="$lastline" 'NR==line1, NR==line2 { if (match($9,/[45]../,m)) print " : " m[0] }' $logfile  | sort | uniq -c | sort -rn >> $report

отправляю на почту отчет

			sendmail root@localhost < $report
			cat $report

после завершения удаляю метку

			done
			rm -f "$lockfile"
			trap - INT TERM EXIT
	else
	   echo "Failed to acquire lockfile: $lockfile."
	   echo "Held by $(cat $lockfile)"
	fi

