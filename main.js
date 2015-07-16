var MODE_MANUAL = 0;
var MODE_AUTO = 1;

// Путь к скрипту.
var ACTION = '/cgi-bin/modules/schoolbell/action.cgi';

// Конструкторы.
function Settings( mode, schedule, preinterval, premelody ) {

    this.mode = mode || MODE_MANUAL;
    this.schedule = schedule || 0;
    this.preinterval = preinterval || 2 ;
    this.premelody = premelody || 0;

    this.Save = function() {

        try {

            var rows = $('#settings')[0].rows;

            // Автомат.
            var inp = rows[1].cells[1].children[0];
            this.mode = inp.value;

            // Расписание.
            inp = rows[2].cells[1].children[0];
            this.schedule = inp.value;

            // Предварительный.
            inp = rows[3].cells[1].children[0];
            this.preinterval = inp.value;

            // Мелодия.
            inp = rows[4].cells[1].children[0];
            this.premelody = inp.value;

            $.post( '/cgi-bin/modules/schoolbell/action.cgi',
                { action : 'savesettings', data : JSON.stringify( this ) } );

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Load = function( values ) {

        try {

            this.mode = values[ 'mode' ];
            this.schedule = values[ 'schedule' ];
            this.preinterval = values[ 'preinterval' ];
            this.premelody = values[ 'premelody' ];

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Refresh = function() {

        var tbody = $('#settings');

        // Очищаем всё, кроме заголовка таблицы.
        tbody.find( 'tr:gt(0)' ).remove();

        // Формируем содержимое таблицы.
        var tr = $('<tr>').css( 'background-color', '#EEEEEE' );

        // "Автомат".
        tr.append( $('<td>').html( 'Автомат' ) );

        var td =  $('<td>').css( 'text-align', 'right' );

        var select = $('<select>');
        select.append( $('<option>').html( 'Выкл' ).val(0) );
        select.append( $('<option>').html( 'Вкл' ).val(1) );
        select.val( settings.mode );

        td.append( select );

        tr.append( td );
        tbody.append( tr );

        // "Расписание".
        tr = $('<tr>').css( 'background-color', '#EEEEEE' );

        tr.append( $('<td>').html( 'Расписание' ) );

        td = $('<td>').css( 'text-align', 'right' );

        select = $('<select>');

        for ( var i = 0; i < schedules.items.length; i++ ) {

            select.append( $('<option>').html( schedules.items[i][1]).val(i) );
        }

        select.val( settings.schedule );

        td.append( select );
        tr.append( td );
        tbody.append( tr );

        // "Предварительный".
        tr = $('<tr>').css( 'background-color', '#EEEEEE' );

        tr.append( $('<td>').html( 'Предварительный' ) );

        td = $('<td>').css( 'text-align', 'right' );

        td.append( $( '<input type="number" min="1" max="10">' ).val( settings.preinterval ) );
        tr.append( td );
        tbody.append( tr );

        // "Мелодия".
        tr = $('<tr>').css( 'background-color', '#EEEEEE' );

        tr.append( $('<td>').html( 'Мелодия' ) );

        td = $('<td>').css( 'text-align', 'right' );

        select = $('<select>');

        for ( var j = 0; j < melodies.items.length; j++ ) {

            select.append( $('<option>').html( melodies.items[j] ).val(j) );
        }

        select.val( settings.premelody );

        td.append( select );

        // Кнопка ">" (проиграть).
        var inp = $( '<input type="button" value=">">' );
        inp.attr( 'onclick', 'Play( "/modules/schoolbell/" + this.parentNode.children[0].value + ".mp3" );' );

        td.append( inp );
        tr.append( td );
        tbody.append( tr );
    }

}

function Schedule() {

    this.Items = [];

    this.Load = function( values ) {

        this.Items = values;
    };

    this.Save = function( id ) {

        var rows = document.getElementById( 'schedule' ).rows;
        var str = "[";

        for ( var i = 1; i < rows.length; i++ ) {

            var cols = rows[i].cells;

            str += "[";

            for ( var j = 0; j < 5; j++ ) {

                var inp;

                switch (j) {

                    case 0: {
                        inp = cols[0].children[0];
                        str += "\"" + ( inp.checked ? "on" : "" ) + "\", ";
                        break;
                    }

                    case 1: {
                        inp = cols[1].children[0];
                        str += "\"" + ( inp.checked ? "on" : "" ) + "\", ";
                        break;
                    }

                    case 2: {
                        inp = cols[2].children[0];
                        str += "\"" + inp.value + "\", ";
                        break;
                    }

                    case 3: {
                        inp = cols[3].children[0];
                        str += "\"" + inp.value + "\", ";
                        break;
                    }

                    case 4: {
                        inp = cols[4].children[0];
                        str += "\"" + inp.value + "\"";
                        break;
                    }

                }

            }

            str += ( i == ( rows.length - 1 ) ) ? "]" : "],";

        }

        str += "]";

        schedules.items[ id ][3] = Base64.encode( str );

    };

    this.AddItem = function( obj ) {

        var tr = $('<tr>').css( 'background-color', '#EEEEEE' );

        // Поле "Вкл".
        var td = $('<td>').css( 'text-align', 'center' );
        tr.append( td.append( $('<input type="checkbox">') ) );

        // Поле "Предв".
        td = $('<td>').css( 'text-align', 'center' );
        tr.append( td.append( $('<input type="checkbox">') ) );

        // Поле "часы".
        td = $('<td>').append( $( '<input type="number" min="0" max="23">' ).val(8) );
        tr.append( td );

        // Поле "минуты".
        td = $('<td>').append( $( '<input type="number" min="0" max="59">' ).val(0) );
        tr.append( td );

        // Поле "мелодия".
        td = $('<td>').css( 'text-align', 'right' );

        var select = $('<select>');

        for ( var j = 0; j < melodies.items.length; j++ ) {

            select.append( $('<option>').val(j).html( melodies.items[j] ) );
        }

        td.append( select.val(0) );
        tr.append( td );

        // Кнопка ">" (проиграть).
        var inp = $('<input type="button">').val('>')
            .click( function() { Play( '/modules/schoolbell/' + $(this)[0].parentNode.children[0].value + '.mp3' ) } );

        td.append( inp );
        tr.append( td );

        // Кнопка "+" (добавить).
        td = $('<td>').css( 'background-color', '#7F7FFF' );

        inp = $('<input type="button">').val('+')
            .click( function() { schedule.AddItem( $(this)[0].parentNode.parentNode ) } );

        td.append( inp );
        tr.append( td );

        // Кнопка "x" (удалить).
        td = $('<td>').css( 'background-color', '#FF7F7F' );

        inp = $('<input type="button">').val('x')
            .click( function() { schedule.DeleteItem( $(this)[0].parentNode.parentNode ) } );

        td.append( inp );
        tr.append( td );

        // Ищем присутствует ли следующий узел в структуре DOM-а,
        if ( obj.nextSibling ) {

            // если да - то создаем после него,
            $('#schedule')[0].insertBefore( tr[0], obj.nextSibling );

            // если такого не нашлось, то просто добавляем в конец.
        } else $('#schedule')[0].appendChild( tr[0] );

    };

    this.DeleteItem = function( obj ) {

        // Удаляем элемент.
        $('#schedule')[0].removeChild( obj );
    };

    this.Clear = function() {

        var values = [['','','8','0','0']];

        this.Load( values );
        this.Refresh();
    };

    this.Refresh = function() {

        var tbody = $('#schedule');

        // Очищаем всё, кроме заголовка таблицы.
        tbody.find( 'tr:gt(0)' ).remove();

        // Добавляем данные.
        for ( var i = 0; i < this.Items.length; i++ ) {

            var tr = $('<tr>').css( 'background-color', '#EEEEEE' );

            // Поле "Вкл".
            var td = $('<td>').css( 'text-align', 'center' );
            td.append( $('<input type="checkbox">').attr( 'checked', this.Items[i][0] == 'on' ) );
            tr.append( td );

            // Поле "Предв".
            td = $('<td>').css( 'text-align', 'center' );
            td.append( $('<input type="checkbox">').attr( 'checked', this.Items[i][1] == 'on' ) );
            tr.append( td );

            // Поле "часы".
            td = $('<td>').append( $( '<input type="number" min="0" max="23">' ).val( this.Items[i][2] ) );
            tr.append( td );

            // Поле "минуты".
            td = $('<td>').append( $( '<input type="number" min="0" max="59">' ).val( this.Items[i][3] ) );
            tr.append( td );

            // Поле "мелодия".
            td = $('<td>').css( 'text-align', 'right' );

            var select = $('<select>');

            for ( var j = 0; j < melodies.items.length; j++ ) {

                select.append( $('<option>').val(j).html( melodies.items[j] ) );
            }

            td.append( select.val( this.Items[i][4] ) );
            tr.append( td );

            // Кнопка ">" (проиграть).
            var inp = $('<input type="button">').val('>')
                .click( function() { Play( '/modules/schoolbell/' + $(this)[0].parentNode.children[0].value + '.mp3' ) } );

            td.append( inp );
            tr.append( td );

            // Кнопка "+" (добавить).
            td = $('<td>').css( 'background-color', '#7F7FFF' );

            inp = $('<input type="button">').val('+')
                .click( function() { schedule.AddItem( $(this)[0].parentNode.parentNode ) } );

            td.append( inp );
            tr.append( td );

            // Кнопка "x" (удалить).
            if ( i > 0 ) {

                td = $('<td>').css( 'background-color', '#FF7F7F' );

                inp = $('<input type="button">').val('x')
                    .click( function() { schedule.DeleteItem( $(this)[0].parentNode.parentNode ) } );

                td.append( inp );
                tr.append( td );
            }

            tbody.append( tr );
        }

    }

}

function Schedules() {

    this.Index = 0;
    this.items = [];

    this.Load = function( values ) {

        try {

            this.items = values;

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Save = function() {

        try {

            $.post( '/cgi-bin/modules/schoolbell/action.cgi',
                { action : 'saveschedules', data : JSON.stringify( this.items ) } );

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Highlight = function( n ) {

        // Снимаем выделение.
        $('#schedules tr').contents('td').css( { 'border' : 'none' } );

        // Выделяем строку рамкой.
        $('#schedules tr').eq(n).contents('td').css(
            { 'border-top':'1px dashed #000000', 'border-bottom' : '1px dashed #000000' } );

        $('#schedules tr').eq(n).contents('td').first().css( { 'border-left' : '1px dashed #000000' } );
        $('#schedules tr').eq(n).contents('td').last().css( { 'border-right' : '1px dashed #000000' } );

    };

    this.Refresh = function() {

        var tbody = $('#schedules');

        // Очищаем таблицу.
        tbody.empty();

        for ( var i = 0; i < this.items.length; i++ ) {

            var tr = $('<tr>').css( 'background-color', '#EEEEEE' );

            // Цвет.
            var td = $('<td>').css( 'background-color', this.items[i][2] );
            td.css( 'width', '20' );
            td.click( function() { schedules.OnClick( $(this)[0].parentNode.rowIndex ); } );
            tr.append( td );

            // Название расписания.
            td = $('<td>').html( this.items[i][1])
                .click( function() { schedules.OnClick( $(this)[0].parentNode.rowIndex ); } );
            tr.append( td );

            // Кнопка "+" (добавить).
            td = $('<td>').css( 'background-color', '#7F7FFF' );

            var inp = $('<input type="button">').val('+')
                .click( function() { schedules.OnAddSchedule( $(this)[0].parentNode.parentNode.rowIndex ) } );

            td.append( inp );
            tr.append( td );

            // Кнопка "x" (удалить).
            if ( i > 0 ) {

                td = $('<td>').css( 'background-color', '#FF7F7F' );

                inp = $('<input type="button">').val('x')
                    .click( function() { schedules.OnDeleteSchedule( $(this)[0].parentNode.parentNode.rowIndex ) } );

                td.append( inp );
                tr.append( td );

            }

            tbody.append( tr );
        }

        this.Highlight( this.Index );

    };

    this.OnDeleteSchedule = function( id ) {

        // Заглушка.
        return;

        if ( id > 0 ) {

            // Удаляем элемент массива.
            schedules.items.splice( id, 1 );

            // Если удаляем последний элемент.
            if ( schedules.items.length == id ) {

                this.Index = id;
                id--;

            }

            // Обновляем список расписаний.
            this.Refresh();

            // Обновляем вид расписания.
            this.OnClick( id );
        }

    };

    this.OnAddSchedule = function( id ) {

        // Заглушка.
        return;

        // Добавляем элемент.
        schedules.items.splice( id + 1, 0, JSON.parse( '["1","Пустое", "#C0C0C0", "W1siIiwiIiwiOCIsIjAiLCIxIl1dCg==" ]' ) );

        // Обновляем список расписаний.
        this.Refresh();

        // Обновляем вид расписания.
        this.OnClick( id );

    };

    this.OnClick = function( row ) {

        // Изменяем идентификатор текущего расписания.
        this.Index = row;

        // Подсвечиваем строку рамкой.
        this.Highlight( this.Index );

        try {

            // Декодируем данные расписания.
            schedule.Load( JSON.parse( Base64.decode( schedules.items[ this.Index ][3] ) ) );

            // Показываем расписание.
            schedule.Refresh();

        } catch ( ex ) {

            console.error( ex );
        }

    }

}

function Melodies() {

    this.items = [];

    this.Load = function( values ) {

        try {

            this.items = values;

        } catch ( ex ) {

            console.error( ex );
        }

    };

}

function Plan() {

    this.items = [];

    this.Save = function() {

        try {

            $.post( '/cgi-bin/modules/schoolbell/action.cgi',
                { action : 'saveplan', data : JSON.stringify( this.items ) } );

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Load = function( values ) {

        try {

            this.items = values;

        } catch ( ex ) {

            console.error( ex );
        }

    };

    this.Clear = function() {

        for ( var i = 0; i < 12; i++ )
            for ( var j = 0; j < 31; j++ )
                this.items[i][j] = 0;

        this.Refresh();
    };

    this.Refresh = function() {

        var tbody = $('#plan');

        // Очищаем таблицу.
        tbody.empty();

        var tr = document.createElement( "tr" );
        tr.style.backgroundColor = "#7F7FFF";
        tr.style.color = "#fff";

        // Выводим текущий год.
        var td = document.createElement( "td" );
        td.style.textAlign = "center";
        td.innerHTML = new Date().getFullYear();
        td.style.fontFamily = "Consolas";
        tr.appendChild( td );

        var Months = [ "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
            "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь" ];
        var Days = [ "Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс" ];

        for ( var i = 0; i < 6; i++ ) {

            for ( var j = 0; j < Days.length; j++ ) {

                td = document.createElement( "td" );
                if ( ( j == 5 ) || ( j == 6 ) ) td.style.color = "#FF7F7F";
                td.style.textAlign = "center";
                td.innerHTML = Days[j];
                td.style.fontFamily = "Consolas";
                tr.appendChild( td );
            }
        }

        tbody.append( tr );

        for ( var i = 0; i < 12; i++ ) {

            tr = document.createElement( "tr" );

            for ( var j = 0; j < 43; j++ ) {

                td = document.createElement( "td" );
                td.style.backgroundColor = "#EEEEEE";
                if ( j > 0 ) td.style.color = "#808080";
                td.style.textAlign = "center";
                td.style.fontFamily = "Consolas";
                tr.appendChild( td );
            }

            tbody.append( tr );

            tbody[0].rows[ i + 1 ].cells[0].innerHTML = Months[i];

            var date = new Date();
            date.setMonth(i);
            date.setDate(1);

            // Корректировка смещения для дня.
            var day = date.getDay();
            day = ( day == 0 ) ? 7 : day--;

            if ( i == 11 ) {

                date.setMonth(0);
                date.setYear( date.getYear() + 1 );

            } else {

                date.setMonth( date.getMonth() + 1 );
            }

            // Откатываемся на 1 день назад, чтобы получить количество
            // дней в текущем месяце.
            date = new Date( date.getTime() - 24 * 3600 * 1000 );

            for ( var j = 1; j <= date.getDate(); j++ ) {

                td = tbody[0].rows[ i + 1 ].cells[ day + j - 1 ];
                td.innerHTML = j;
                td.style.borderWidth = "1px";
                td.style.borderStyle = "solid";
                td.style.borderColor = "gray";

                try {
                    td.style.backgroundColor = schedules.items[ this.items[i][ j - 1 ] ][2];
                } catch ( ex ) {
                    td.style.backgroundColor = "#EEEEEE";
                }

                td.setAttribute( 'onclick', 'plan.OnClick( this, ' + i + ', ' + ( j - 1 ) + ' );' );
            }

        }

    };

    this.OnClick = function( td, i, j ) {

        // Изменяем расписание в плане.
        plan.items[i][j] = palette.Index;

        // Перекрашиваем ячейку цветом из палитры расписаний.
        td.style.backgroundColor = schedules.items[ palette.Index ][2];
    }

}

function Palette() {

    this.Index = 0;

    this.Highlight = function( n ) {

        // Снимаем выделение.
        $('#palette tr').contents('td').css( { 'border' : 'none' } );

        // Выделяем строку рамкой.
        $('#palette tr').eq(n).contents('td').css(
            { 'border-top':'1px dashed #000000', 'border-bottom' : '1px dashed #000000' } );

        $('#palette tr').eq(n).contents('td').first().css( { 'border-left' : '1px dashed #000000' } );
        $('#palette tr').eq(n).contents('td').last().css( { 'border-right' : '1px dashed #000000' } );

    };

    this.Refresh = function() {

        var tbody = $('#palette');

        // Очищаем таблицу.
        tbody.empty();

        for ( var i = 0; i < schedules.items.length; i++ ) {

            var tr = $('<tr>').css( 'background-color', '#EEEEEE' );

            // Цвет.
            var td = $('<td>').css( 'background-color', schedules.items[i][2] );
            td.css( 'width', '20' );
            td.click( function() { palette.OnClick( $(this)[0].parentNode.rowIndex ); } );
            tr.append( td );

            // Название расписания.
            td = $('<td>').html( schedules.items[i][1] )
                .click( function() { palette.OnClick( $(this)[0].parentNode.rowIndex ); } );
            tr.append( td );

            tbody.append( tr );
        }

        this.Highlight( this.Index );
    };

    this.OnClick = function( row ) {

        // Изменяем идентификатор текущего расписания в палитре.
        this.Index = row;

        // Подсвечиваем строку рамкой.
        this.Highlight( this.Index );
    }

}

// Глобальные объекты.
var settings = new Settings();

// Мелодии.
var melodies = new Melodies();

// Расписания.
var schedules = new Schedules();

// Выбранное расписание.
var schedule = new Schedule();

// План.
var plan = new Plan();

// Палитра расписаний.
var palette = new Palette();

var tabIndex = "TabSettings";
var ramka;


function LoadSchedules() {

    return $.post( ACTION, { action : 'loadschedules' },
        function( data ) { schedules.Load( data ); }, 'json' );
}

function LoadMelodies() {

    return $.post( ACTION, { action : 'loadmelodies' },
        function( data ) { melodies.Load( data );  }, 'json' );
}

function DoTabChange( x, y ) {

    var mostrar = document.getElementById(x);
    var actual = document.getElementById( tabIndex );

    // Обновляем содержимое вкладки.
    switch (x) {

        case 'TabSettings': {

            // Настройки.
            $.post( ACTION, { action : 'loadsettings' },
                function( data ) {
                    settings.Load( data );
                    settings.Refresh();
                }, 'json' );

            break;
        }

        case 'TabPlan': {

            // План.
            $.post( ACTION, { action : 'loadplan' },
                function( data ) {

                    plan.Load( data );
                    plan.Refresh();

                    // Палитра расписаний.
                    palette.Refresh();

                }, 'json' );

            break;
        }

        case 'TabSchedules': {

            // Список расписаний.
            $.post( ACTION, { action : 'loadschedules' },
                function( data ) {

                    schedules.Load( data );
                    schedules.Refresh();

                    // Текущее расписание.
                    schedule.Load( JSON.parse( Base64.decode( schedules.items[ schedules.Index ][3] ) ) );
                    schedule.Refresh();

                }, 'json' );

            break;
        }

        case 'TabSystemLog': {

            // Системный журнал.
            $.post( ACTION, { action : 'logread' },
                function( data ) {

                    $('#SystemLog').css( { 'width': '100%', 'height' : '400' } ).val( data );

                } );

            break;
        }

        case 'TabDebug': {

            // Отладочный журнал.
            $.post( ACTION, { action : 'debuglog' },
                function( data ) {

                    $('#Debug').css( { 'width': '100%', 'height' : '400' } ).val( data );

                } );

            break;
        }

    }

    if ( mostrar == actual ) { return false; }

    actual.className = "hidden";
    mostrar.className = "visible";
    tabIndex = x;
    document.getElementById( 'TabSheet1' ).style.borderBottomColor = '#E1E1E1';

    if ( ramka ) ramka.style.borderBottomColor = '#E1E1E1';

    y.style.borderBottomColor = '#FFF';
    ramka = y;

}

function padStr(i) {

    return ( i < 10 ) ? '0' + i : '' + i;
}

function printDate() {

    var temp = new Date();

    return '' + padStr( temp.getFullYear() ) +
        padStr( 1 + temp.getMonth() ) +
        padStr( temp.getDate() ) +
        padStr( temp.getHours() ) +
        padStr( temp.getMinutes() ) + '.' +
        padStr( temp.getSeconds() );
}

function SetDate() {

    return $.post( ACTION, { action : 'setdate', value : printDate() } );
}

function ShowDate() {

    return $.post( ACTION, { action : 'getdate' },
        function( value ) {

            var d = $('div#date').html( 'Дата: ' + value );

            d.append( '<button type="button">Синхронизировать</button>' )
                .click( function() { SetDate(); ShowDate(); } );

        }
    );

}

function StateOnClick( message, cmd ) {

    if ( confirm( message ) ) {

        $.post( ACTION, { action : cmd }, function( value ) { ShowState(); } );
    }

}

function ShowState() {

    return $.post( ACTION, { action : 'state' },
        function( value ) {

            var d = $( 'div#state');

            if ( value == 1 ) {

                d.html( 'Состояние: <font color=\"#6633FF\">РАБОТАЕТ</font>' );

                d.append( $( '<button type="button">Останов</button>')
                    .click( function() { StateOnClick( 'Остановить?', 'stop' ) } ) );

                d.append( $( '<button type="button">Перезапуск</button>' )
                    .click( function() { StateOnClick( 'Перезапустить?', 'start' ) } ) );

            } else {

                d.html( 'Состояние: <font color=\"#CC3300\">ОСТАНОВЛЕН</font>' );

                d.append( $( '<button type="button">Запустить</button>' )
                    .click( function() { StateOnClick( 'Запустить?', 'start' ) } ) );
            }

            d.append( $( '<button type="button">Тест</button>' )
                .click( function() { $.post( ACTION, { action : 'test' } ) } ) );

        }

    );

}

function Play( file ) {

    var player = document.createElement( 'audio' );

    player.src = file;
    player.play();
    
    // Тестирование поддержки новых тегов HTML5.
    //var test_audio= document.createElement("audio"); //try and create sample audio element
    //var test_video= document.createElement("video"); //try and create sample video element
    //var mediasupport={audio: (test_audio.play)? true : false, video: (test_video.play)? true : false};
    // 
    //alert("Audio Element support: " + mediasupport.audio + "\n" + "Video Element support: " + mediasupport.video );

}

