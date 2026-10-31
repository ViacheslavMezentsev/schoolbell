#!/bin/sh
# Для работы с JSON используется библиотека: https://github.com/dominictarr/JSON.sh
# --------------------------------------------------------------

LOGFILE=/www/modules/schoolbell/log.txt

# Ведение журнала.
loginfo () {

    lcnt=$(wc -l $LOGFILE | cut -f1 -d' ')
    
    # Ограничиваем размер файла журнала по количеству строк.
    if [ $lcnt -gt 100 ] ; then
    
        start=`expr $lcnt - 50`
        tail +$start $LOGFILE > /tmp/log.txt
        mv /tmp/log.txt $LOGFILE
        
    fi
    
    echo "`date +"%Y.%m.%d %H:%M:%S [INFO]"` $1" >> $LOGFILE
}

# Запуск планировщика каждый день в полночь.
echo "1 0 * * * /www/cgi-bin/modules/schoolbell/scheduler.cgi" > /etc/crontabs/root

settings=`/www/cgi-bin/modules/schoolbell/json.cgi -l < /www/modules/schoolbell/settings.json`
plan=`/www/cgi-bin/modules/schoolbell/json.cgi -l < /www/modules/schoolbell/plan.json`
schedules=`/www/cgi-bin/modules/schoolbell/json.cgi -l < /www/modules/schoolbell/schedules.json`

mode=$(echo "$settings" | egrep "\[\"mode\"\]" | cut -f2 | egrep -o '[^\"]*')
d=`date +"%d"`
d=`expr $d - 1`
m=`date +"%m"`
m=`expr $m - 1`    

# Автоматический режим выключен.
if [ $mode = 0 ] ; then
    
    id=$(echo "$settings" | egrep "\[\"schedule\"\]" | cut -f2 | egrep -o '[^\"]*')
    loginfo "scheduler: auto=$mode, id=$id"
    
# Автоматический режим включен.
else
    
    # Считываем текущее расписание из плана.
    id=$(echo "$plan" | egrep "\[$m\,$d\]" | cut -f2)
    loginfo "scheduler: auto=$mode, [$m,$d]=$id"
    
fi

schedule=$(echo "$schedules" | egrep "\[$id\,3\]" | cut -f2 | egrep -o '[^\"]*')

# Декодируем.
schedule=$(echo "$schedule" | base64 -d | /www/cgi-bin/modules/schoolbell/json.cgi -l)

# Вычисляем количество задач в расписании.
limit=$(echo "$schedule" | tail -n1 | egrep -o '[0-9]+' | head -n1)

# Перебираем записи расписания.
for i in `seq 0 $limit`; do
    
    # Признак активности.
    enabled=$(echo "$schedule" | egrep "\[$i\,0\]" | cut -f2 | egrep -o '[^\"]*')
    
    # Если задание включено.
    if [[ "$enabled" = "on" ]] ; then
    
        # Формируем описание основного задания. 
        
        # Вермя запуска.
        hour=$(echo "$schedule" | egrep "\[$i\,2\]" | cut -f2 | egrep -o '[^\"]*')
        min=$(echo "$schedule" | egrep "\[$i\,3\]" | cut -f2 | egrep -o '[^\"]*')
        
        pre=$(echo "$schedule" | egrep "\[$i\,1\]" | cut -f2 | egrep -o '[^\"]*')

        # Формируем описание предварительного задания.
        if [[ "$pre" = "on" ]] ; then
            
            # Номер мелодии для предварительного задания.
            n=$(echo "$settings" | egrep "\[\"premelody\"\]" | cut -f2 | egrep -o '[^\"]*')
            melody=$(echo "/www/modules/schoolbell/$n.mp3")
            
            # Время до основного задания.
            a=$(echo "$settings" | egrep "\[\"preinterval\"\]" | cut -f2 | egrep -o '[^\"]*')
            m=`expr $min - $a`
            
            # Корректировка отрицательных значений.
            result=$(( m < 0 ))
            
            if [[ $result -eq 1 ]] ; then
                
                echo "`expr $m + 60` `expr $hour - 1` * * * madplay $melody" >> /etc/crontabs/root
                
            else

                echo "$m $hour * * * madplay $melody" >> /etc/crontabs/root
                
            fi
            
        fi
       
        # Номер мелодии.  
        n=$(echo "$schedule" | egrep "\[$i\,4\]" | cut -f2 | egrep -o '[^\"]*')
        melody=$(echo "/www/modules/schoolbell/$n.mp3")

        echo "$min $hour * * * madplay $melody" >> /etc/crontabs/root
    fi
    
done 

# Перезапуск планировщика.
/etc/init.d/cron start
/etc/init.d/cron restart
