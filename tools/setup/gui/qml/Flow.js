// Pure simulated routes: no I/O, host commands or device operations.
var routes = [
 {name:"Установка OpenWrt", bundles:["OpenWrt 19.07.9 · MR3020 EU v3.30"], steps:[
  {id:"device",title:"Подключение и модель",text:"Сверьте EU Ver. 3.30 с наклейкой. В настоящем мастере роутер подключается отдельным Ethernet-кабелем. На этом шаге Reset не нажимают.",confirm:"В макете модель подтверждена",resetPhoto:true},
  {id:"backup",title:"Сохранение данных",text:"Перед заменой прошивки мастер предложит сохранить настройки текущей системы. Резервная копия TP-Link не переносится в OpenWrt. Здесь копирование только имитируется.",confirm:"Резервная копия условно сохранена"},
  {id:"bundle",title:"Образ OpenWrt",text:"Образ для проверенного профиля EU v3.30. Устанавливается только OpenWrt; набор приложений можно выбрать отдельным сценарием после установки. Версия 19.07.9 больше не получает обновления безопасности."},
  {id:"check",title:"Проверка перед прошивкой",text:"Моделируется проверка образа, модели и прямого подключения. Настоящая прошивка заменит систему роутера."},
  {id:"reset",title:"Запуск восстановления через Reset",text:"В настоящем мастере: дождитесь готовности сервера, отключите питание, зажмите WPS/RESET и подайте питание. После начала передачи отпустите кнопку. Затем питание не отключайте.\n\nСейчас нажмите только кнопку имитации ниже.",resetPhoto:true},
  {id:"execute",title:"Установка OpenWrt",text:"Передача образа, загрузка и восстановление сети моделируются. Передача сама по себе не подтверждает успешную прошивку."},
  {id:"result",title:"Проверка OpenWrt",text:"Моделируемый результат: OpenWrt загрузилась, интерфейс доступен, сеть компьютера восстановлена. Школьник ещё не установлен. Для него выберите «Установка пакетов»."}
 ]},
 {name:"Установка пакетов",bundles:["Школьник · полный набор зависимостей","Аудио · драйверы и проигрыватель"],steps:[
  {id:"device",title:"Подключение к OpenWrt",text:"Используется уже установленная OpenWrt. Мастер проверит модель, версию системы и доступ по SSH. Перепрошивка и кнопки роутера не нужны.",confirm:"В макете доступ к OpenWrt подтверждён"},
  {id:"backup",title:"Резервная копия конфигурации",text:"Перед установкой сохраняются настройки и перечень пакетов. Если Школьник уже установлен, сохраняются его данные и прежний пакет для отката. В макете файлы не создаются.",confirm:"Копия и откат условно подготовлены"},
  {id:"bundle",title:"Выберите набор пакетов",text:"Набор должен соответствовать версии OpenWrt, ядру и архитектуре. В реальном мастере пароль вводится локально; здесь пароль не запрашивается."},
  {id:"check",title:"Проверка пакетов",text:"Моделируются проверка совместимости, свободного места и контрольных сумм. Работающие автозвонки потребуют отдельной остановки перед обновлением."},
  {id:"execute",title:"Установка пакетов",text:"Моделируются SSH-подключение, передача, установка и проверка пакетов. Прошивка не заменяется."},
  {id:"result",title:"Проверка набора",text:"Моделируемый результат: выбранный набор установлен. Для набора Школьника проверяются доступность интерфейса и выключенные автозвонки. Громкость не меняется."}
 ]},
 {name:"Возврат заводской прошивки",bundles:["TP-Link EU v3.30 · Build 250625 · проверенный recovery"],steps:[
  {id:"device",title:"Проверка ревизии",text:"Этот профиль проверен только для TL-MR3020 EU Ver. 3.30. Используется отдельный Ethernet-кабель. Reset пока не нажимают.",confirm:"В макете EU v3.30 подтверждена",resetPhoto:true},
  {id:"backup",title:"Сохраните текущую систему",text:"Перед возвратом сохраняются доступные настройки и данные. Пакеты OpenWrt и данные Школьника не работают в заводской системе.",confirm:"Данные условно сохранены"},
  {id:"bundle",title:"Образ заводской системы",text:"Выбирается подготовленный recovery-образ, а не произвольный OEM-архив. Прежние настройки TP-Link и пароль администратора могут сохраниться."},
  {id:"check",title:"Проверка перед возвратом",text:"Моделируются проверка профиля EU v3.30, хеша образа и выделенного адаптера. Установка пакетов в этом сценарии отсутствует."},
  {id:"reset",title:"Возврат через WPS/RESET",text:"В настоящем мастере: после готовности сервера отключите питание, зажмите WPS/RESET и подайте питание. Отпустите кнопку после начала передачи. Дождитесь записи и загрузки, не отключая питание.\n\nВ макете используйте кнопку ниже, роутер не трогайте.",resetPhoto:true},
  {id:"execute",title:"Возврат TP-Link",text:"Моделируются передача recovery-образа, ожидание заводской системы и восстановление сети. SSH и пакеты здесь не используются."},
  {id:"result",title:"Проверьте заводской интерфейс",text:"Моделируемый результат: TP-Link Build 250625 доступна. В реальной проверке сверьте версию и войдите с прежним паролем TP-Link, не root OpenWrt. При забытом пароле нужен отдельный сброс заводских настроек после загрузки; он удалит настройки. Автоматический сброс не выполняется."}
 ]}
];
// The equipment screen precedes task selection in both modes.
var equipment = {
 id:"equipment", title:"Что понадобится", confirm:"Всё перечисленное подготовлено — продолжить макет",
 text:"Обязательно для установки:\n• Компьютер с Windows 11 и свободным USB-разъёмом.\n• USB–Ethernet-адаптер: отдельное подключение к роутеру, без изменения основного подключения компьютера.\n• Сетевой кабель с разъёмами RJ45 — от адаптера к роутеру.\n• TP-Link TL-MR3020 EU Ver. 3.30; версию сверим по наклейке.\n• Блок питания роутера и кабель USB Type-C для этой ревизии.\n\nДля последующей подачи звонков также нужны совместимая USB-аудиокарта, USB-хаб при необходимости и активные колонки. Для самой прошивки они не требуются.\n\nСейчас это макет: ничего подключать не нужно."
};
var guided = {name:"Установить Школьник",bundles:["OpenWrt 19.07.9 + Школьник · готовый комплект"],steps:[
 {id:"device",title:"Найдите версию на наклейке",text:"Посмотрите на нижнюю сторону роутера. Нужны модель TL-MR3020, регион EU и надпись Ver: 3.30. По одному внешнему виду версию определить нельзя. Если надписи отличаются, этот комплект не подходит.",confirm:"На наклейке указано TL-MR3020 EU Ver. 3.30"},
 {id:"cable",title:"Подключите отдельный сетевой кабель",text:"В реальной установке: вставьте USB–Ethernet-адаптер в компьютер. Соедините его сетевым кабелем с роутером. Основное подключение компьютера оставьте как есть.\n\nМастер сам проверит связь. В макете нажмите «Далее», чтобы увидеть следующий шаг."},
 {id:"backup",title:"Сохраните настройки на всякий случай",text:"Перед заменой системы мастер предложит сохранить доступные настройки в файл. Этот файл поможет при возврате к прежней системе; настройки TP-Link не переносятся в Школьник. Если копию получить не удалось, мастер остановится и объяснит варианты.\n\nВ макете файл не создаётся.",confirm:"Сохранение копии смоделировано"},
 {id:"check",title:"Всё ли готово к установке?",text:"Мастер проверит роутер, соединение и готовый комплект. Вам не нужно выбирать отдельные файлы прошивки и программ.\n\nУстановка заменит систему роутера на OpenWrt и добавит Школьник. Используемая OpenWrt 19.07.9 устарела; не открывайте управление устройством из Интернета."},
 {id:"poweroff",title:"1. Отключите питание роутера",text:"Во время настоящей установки отсоедините только кабель питания от роутера. Сетевой кабель оставьте подключённым.\n\nЗдесь нажмите кнопку ниже — физически ничего делать не нужно.",next:"Питание отключено — имитация"},
 {id:"hold",title:"2. Зажмите WPS/RESET",text:"Найдите кнопку WPS/RESET сверху корпуса, как показано справа. Зажмите её и держите.\n\nВ макете просто перейдите к следующей подсказке.",resetPhoto:true,next:"Кнопка зажата — имитация"},
 {id:"poweron",title:"3. Подключите питание",text:"В настоящей установке подключите питание, продолжая держать WPS/RESET. Отпускайте кнопку только после сообщения мастера о начале передачи.\n\nСледующее нажатие смоделирует начало передачи.",resetPhoto:true,next:"Питание подано — имитация"},
 {id:"release",title:"4. Отпустите WPS/RESET",text:"Передача началась — это сообщение сейчас смоделировано. В настоящей установке после такого сообщения отпустите WPS/RESET.\n\nС этого момента не отключайте питание и сетевой кабель до завершения проверки.",resetPhoto:true,next:"Кнопка отпущена — продолжить"},
 {id:"execute",title:"Подождите, идёт установка",text:"Сначала устанавливается система роутера, затем Школьник. Мастер проверит результат и восстановит подключение компьютера. Не отключайте питание в ходе настоящей установки."},
 {id:"result",title:"Школьник готов — результат макета",text:"В настоящем мастере здесь появятся проверенная версия Школьника, кнопка открытия его страницы и место сохранения резервной копии. Автозвонки останутся выключенными.\n\nПосле установки подключите аудиокарту и колонки, проверьте дату, время и звук, затем настройте расписание. Сейчас устройство не изменялось, копия не создавалась."}
]};
routes.push(guided);
var simpleRecovery = {name:"Вернуть заводскую систему TP-Link",bundles:routes[2].bundles,steps:[
 guided.steps[0], guided.steps[1],
 {id:"backup",title:"Сохраните важные данные",text:"Возврат заводской системы удалит Школьник и установленные программы. Перед продолжением сохраните настройки и пользовательские данные. В макете файл не создаётся.",confirm:"Сохранение данных смоделировано"},
 {id:"check",title:"Проверка перед возвратом",text:"Мастер подберёт проверенный файл для EU Ver. 3.30 и проверит подключение. Не нужно искать или выбирать файл самостоятельно. Прежний пароль TP-Link может сохраниться."},
 guided.steps[4], guided.steps[5], guided.steps[6], guided.steps[7],
 {id:"execute",title:"Возвращаем заводскую систему",text:"Дождитесь окончания записи и проверки загрузки. В настоящей установке питание и сетевой кабель должны оставаться подключёнными."},
 {id:"result",title:"Заводская система готова — макет",text:"В настоящем мастере здесь появится кнопка открытия страницы TP-Link. Для входа может потребоваться прежний пароль TP-Link. Если он забыт, после завершения загрузки понадобится отдельный сброс настроек; мастер объяснит его отдельно. Сброс сам по себе не выполняется.\n\nСейчас роутер не изменялся и резервная копия не создавалась."}
]};
function routeFor(task, expert) { return task===2 && !expert ? simpleRecovery : routes[task]; }
function choices(expert) { return expert ? [3,0,1,2] : [3,2]; }
function errorText(task, scenario, expert) {
 if(scenario===1) return expert ? "Нет связи через выделенный адаптер. Проверьте кабель и маршрут." : "Роутер не найден. Проверьте сетевой кабель и USB–Ethernet-адаптер, затем повторите проверку.";
 if(task===1) return scenario===2 ? "Не удалось войти в роутер. Проверьте доступ к нему и пароль; запись пакетов ещё не началась." : "Установка программ остановилась. Сохраните подробности ошибки и повторите этап. Система роутера не перепрошивается.";
 return scenario===2 ? "Передача завершена, но загрузка роутера ещё не подтверждена. Питание не отключайте. Повторите ожидание; повторная прошивка не запускается." : "Компьютер пока не получил адрес от роутера. Проверьте кабель и повторите подключение. Прошивка повторно не записывается.";
}
function phase(task, progress) {
 if(task===3) return progress<30?"Передаём систему роутеру":progress<55?"Ждём включения новой системы":progress<85?"Устанавливаем Школьник":"Проверяем Школьник и подключение";
 if(task===1) return progress<25?"Подключение по SSH":progress<50?"Передача пакетов":progress<85?"Установка выбранного набора":"Проверка версий и интерфейса";
 return progress<35?"Передача образа":progress<75?(task===2?"Ожидание заводской системы":"Ожидание OpenWrt"):"Восстановление сети компьютера";
}
function shouldFail(task, scenario, progress) {
 return scenario>=2 && progress >= (scenario===2 ? (task===1?20:50) : (task===1?65:90));
}
// Shared state machine used by QML and host tests. All events are simulated.
function initial(expert, generation) {
 return {expert:!!expert, task:3, step:-2, confirmed:false, selectedBundle:"", scenario:0,
 progress:0, running:false, failed:false, recovered:false, verifying:false, verified:false,
 pending:"", closed:false, generation:generation || 0, revision:0, starts:0,
 report:"Только имитация. Сетевых операций нет."};
}
function pageOf(s) {
 return s.step===-2 ? equipment : s.step===-1 ? {id:"task",title:"Выберите задачу",text:""} : routeFor(s.task,s.expert).steps[s.step];
}
function canNext(s) {
 var p=pageOf(s);
 return !s.closed && !s.pending && p.id!=="execute" && p.id!=="result" &&
 (!p.confirm || s.confirmed) && !(p.id==="check" && s.scenario===1);
}
function transition(before, event) {
 if(before.closed) return before;
 if(event.revision!==undefined && event.revision!==before.revision) return before;
 var s=JSON.parse(JSON.stringify(before)), p=pageOf(s), route=routeFor(s.task,s.expert);
 if(s.pending) {
  if(event.type==="dismiss") {s.pending=""; s.generation++;}
  else if(event.type==="accept") {
   if(s.pending==="close") {s.closed=true;s.running=false;s.generation++;}
   else {s=initial(s.expert,s.generation+1);s.report="Сценарий отменён. Устройство не изменялось.";}
  } else return before;
 } else if(event.type==="request") {
  if(event.action!=="reset" && event.action!=="close") return before;
  s.pending=event.action;s.generation++;
 } else if(event.type==="mode" && s.step===-2) {
  s=initial(!!event.value,s.generation+1);
 } else if(event.type==="task" && s.step===-1 && choices(s.expert).indexOf(event.value)>=0) {
  s.task=event.value;s.scenario=0;s.selectedBundle="";s.confirmed=false;
 } else if(event.type==="confirm" && p.confirm) {s.confirmed=!!event.value;}
 else if(event.type==="bundle" && p.id==="bundle" && route.bundles.indexOf(event.value)>=0) {s.selectedBundle=event.value;}
 else if(event.type==="scenario" && p.id!=="execute" && p.id!=="result" && event.value>=0 && event.value<=4) {s.scenario=event.value;}
 else if(event.type==="recheck" && p.id==="check" && s.scenario===1) {s.scenario=0;}
 else if(event.type==="back" && s.step>-2 && p.id!=="execute" && p.id!=="result") {
  s.step--;s.confirmed=false;s.selectedBundle="";s.verified=false;s.generation++;
 } else if(event.type==="next" && canNext(s)) {
  if(!s.selectedBundle) s.selectedBundle=route.bundles[0];
  s.step++;s.confirmed=false;
  if(pageOf(s).id==="execute") {
   s.progress=0;s.running=true;s.failed=false;s.recovered=false;s.verifying=false;s.verified=false;s.starts++;s.generation++;
   s.report+="\nНачата имитация: "+route.name;
  }
 } else if(event.type==="retry" && p.id==="execute" && s.failed) {
  s.failed=false;s.running=true;s.recovered=true;s.generation++;
  s.report+="\nПовтор проверки с "+s.progress+" %, без новой записи прошивки.";
 } else if(event.type==="tick" && event.generation===s.generation && s.running && p.id==="execute") {
  if(s.verifying) {
   if(s.scenario===4 && !s.recovered) {s.running=false;s.failed=true;s.report+="\nПроверка результата не пройдена.";}
   else {s.running=false;s.verified=true;s.verifying=false;s.step++;s.report+="\nРезультат имитации проверен.";}
  } else {
   s.progress=Math.min(100,s.progress+2);
   if(!s.recovered && s.scenario>=2 && s.scenario<=3 && shouldFail(s.task,s.scenario,s.progress)) {
    s.running=false;s.failed=true;s.report+="\n"+errorText(s.task,s.scenario,s.expert);
   } else if(s.progress===100) {s.verifying=true;s.report+="\nПередача и выполнение завершены; результат ещё проверяется.";}
  }
 } else return before;
 s.revision=before.revision+1;
 return s;
}
function interruptionText(s) {
 return (s.running || s.failed ? "Сценарий ещё не завершён. " : "")+
 (s.pending==="close" ? "Закрыть макет? Текущий сценарий не сохранится." : "Отменить сценарий и начать заново? Подтверждения и результат будут сброшены.")+
 "\n\nЭто только имитация: устройства не изменяются. В настоящей установке закрытие окна не означает, что питание роутера можно отключить.";
}
if (typeof module !== "undefined") module.exports={routes:routes,phase:phase,shouldFail:shouldFail,equipment:equipment,choices:choices,errorText:errorText,routeFor:routeFor,initial:initial,pageOf:pageOf,canNext:canNext,transition:transition};
