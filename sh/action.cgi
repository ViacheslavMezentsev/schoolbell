#!/bin/sh

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

echo "Content-type: text/html; charset=utf-8"
echo

if [ "$REQUEST_METHOD" = POST ]; then
     
    read -n $CONTENT_LENGTH query
    loginfo "POST $query"
     
elif [ "$REQUEST_METHOD" = GET ]; then     
    
    query=$(echo "$QUERY_STRING")
    loginfo "GET $query"
else

    exit 0
fi
        
# Разбор запроса.
if [ -n "$query" ]; then

    # Декодирование запроса.
    query=$(echo "$query" | echo -e $(sed 's/+/ /g; s/%/\\x/g'))
    
    # Проверка типа действия.
    action=$(echo "$query" | sed -n 's/^.*action=\([^&]*\).*$/\1/p')
    
    case "$action" in

        # Состояние.
        "state")
        
            if ps | grep -v grep | grep cron &> /dev/null ; then
                echo "1"
            else
                echo "0"
            fi
        ;;
        
        # Остановка планировщика.
        "stop")
            
            /etc/init.d/cron stop
            sleep 1
        ;;
        
        # Запуск планировщика.
        "start") `/www/cgi-bin/modules/schoolbell/scheduler.cgi` ;;
        
        # Запрос даты.
        # `date +\"%d.%m.%Y\"` Время: `date +\"%H:%M:%S\"`
        "getdate") echo "`date`" ;;
        
        # Синхронизация времени.
        "setdate")
        
            value=$(echo "$query" | sed -n 's/^.*value=\([^&]*\).*$/\1/p')
            `date $value`
        ;;
        
        # Тестирование звукового канала.
        "test") `madplay /www/modules/schoolbell/test.mp3` ;;
        
        # Чтение списка мелодий.
        "loadmelodies") echo `cat /www/modules/schoolbell/melodies.json`;;
        
        # Сохранение настроек.
        "savesettings")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/settings.json
            loginfo $data
        ;;
        
        # Чтение настроек.
        "loadsettings") echo `cat /www/modules/schoolbell/settings.json`;;
        
        # Сохранение плана.
        "saveplan")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/plan.json
            loginfo $data
        ;;
        
        # Чтение плана.
        "loadplan") echo `cat /www/modules/schoolbell/plan.json`;;
        
        # Сохранение текущего расписания.
        "saveschedules")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/schedules.json
            loginfo $data
        ;;
        
        # Чтение расписаний.
        "loadschedules") echo `cat /www/modules/schoolbell/schedules.json`;;
        
        # Системный журнал.
        "logread") echo `logread | sed ':a;N;$!ba;s/\n/\r/g'` ;;
        
        # Отладка.
        "debuglog") echo `cat $LOGFILE | sed ':a;N;$!ba;s/\n/\r/g'` ;;
        
    esac

fi
