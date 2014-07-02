#!/bin/sh

LOGFILE=/www/modules/schoolbell/log.txt

# ������� �������.
loginfo () {

    lcnt=$(wc -l $LOGFILE | cut -f1 -d' ')
    
    # ������������ ������ ����� ������� �� ���������� �����.
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
        
# ������ �������.
if [ -n "$query" ]; then

    # ������������� �������.
    query=$(echo "$query" | echo -e $(sed 's/+/ /g; s/%/\\x/g'))
    
    # �������� ���� ��������.
    action=$(echo "$query" | sed -n 's/^.*action=\([^&]*\).*$/\1/p')
    
    case "$action" in

        # ���������.
        "state")
        
            if ps | grep -v grep | grep cron &> /dev/null ; then
                echo "1"
            else
                echo "0"
            fi
        ;;
        
        # ��������� ������������.
        "stop")
            
            /etc/init.d/cron stop
            sleep 1
        ;;
        
        # ������ ������������.
        "start") `/www/cgi-bin/modules/schoolbell/scheduler.cgi` ;;
        
        # ������ ����.
        # `date +\"%d.%m.%Y\"` �����: `date +\"%H:%M:%S\"`
        "getdate") echo "`date`" ;;
        
        # ������������� �������.
        "setdate")
        
            value=$(echo "$query" | sed -n 's/^.*value=\([^&]*\).*$/\1/p')
            `date $value`
        ;;
        
        # ������������ ��������� ������.
        "test") `madplay /www/modules/schoolbell/test.mp3` ;;
        
        # ������ ������ �������.
        "loadmelodies") echo `cat /www/modules/schoolbell/melodies.json`;;
        
        # ���������� ��������.
        "savesettings")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/settings.json
            loginfo $data
        ;;
        
        # ������ ��������.
        "loadsettings") echo `cat /www/modules/schoolbell/settings.json`;;
        
        # ���������� �����.
        "saveplan")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/plan.json
            loginfo $data
        ;;
        
        # ������ �����.
        "loadplan") echo `cat /www/modules/schoolbell/plan.json`;;
        
        # ���������� �������� ����������.
        "saveschedules")
        
            data=$(echo "$query" | sed -n 's/^.*data=\([^&]*\).*$/\1/p')
            echo "$data" > /www/modules/schoolbell/schedules.json
            loginfo $data
        ;;
        
        # ������ ����������.
        "loadschedules") echo `cat /www/modules/schoolbell/schedules.json`;;
        
        # ��������� ������.
        "logread") echo `logread | sed ':a;N;$!ba;s/\n/\r/g'` ;;
        
        # �������.
        "debuglog") echo `cat $LOGFILE | sed ':a;N;$!ba;s/\n/\r/g'` ;;
        
    esac

fi
