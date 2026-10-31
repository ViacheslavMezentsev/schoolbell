(function () {
  'use strict';
  var audio=document.getElementById('browser-audio');
  var localButton=document.getElementById('browser-play');
  var localResult=document.getElementById('browser-result');
  localButton.addEventListener('click',function () {
    audio.currentTime=0; localButton.disabled=true;
    localResult.textContent='Воспроизводится на этом устройстве…';
    audio.play().catch(function () {
      localButton.disabled=false; localResult.textContent='Не удалось воспроизвести. Проверьте вход в LuCI, сеть и громкость устройства.';
    });
  });
  audio.addEventListener('ended',function () { localButton.disabled=false; localResult.textContent='Воспроизведение на этом устройстве завершено.'; });
  audio.addEventListener('error',function () { localButton.disabled=false; localResult.textContent='Файл недоступен. Обновите страницу и проверьте вход в LuCI.'; });
  var form=document.getElementById('router-form'), button=document.getElementById('router-play'), result=document.getElementById('router-result');
  window.addEventListener('schoolbell-session-lost',function(){button.disabled=true;result.textContent='Войдите для управления звуком.';});
  var messages={
    muted:'Звук отключён кнопкой Без звука.',
    completed:'Проигрыватель завершился успешно. Было слышно через колонки устройства?',
    busy:'Тест уже выполняется или заблокирован после сбоя. Повторно не запускаем.',
    unavailable:'Нет проигрывателя, аудиовыхода или тестовой мелодии.',
    spawn_failed:'Не удалось запустить процесс. Можно повторить.',
    failed:'Проигрыватель завершился с ошибкой.',
    timeout:'Превышено время теста. Процесс остановлен.',
    recovery_required:'Исход процесса не подтверждён. Тест заблокирован; нужна проверка по SSH.',
    cleanup_required:'Процесс завершён, но блокировка не снята. Нужна проверка по SSH.'
  };
  form.addEventListener('submit',async function (event) {
    event.preventDefault(); if(window.schoolbellSessionBlocked)return;button.disabled=true; result.textContent='Звонок на устройстве… ожидаем завершения.';
    try {
      var response=await fetch(form.action,{method:'POST',credentials:'same-origin',body:new URLSearchParams(new FormData(form)),redirect:'error'});
      if(!response.ok) throw new Error('HTTP '+response.status);
      var data=await response.json();
      result.textContent=messages[data.state] || 'Неизвестный ответ. Проверьте состояние через SSH.';
    } catch (_) {
      result.textContent='Ответ не получен. Звук мог начаться: не повторяйте сразу. Проверьте сеть и обновите страницу.';
    } finally { button.disabled=!!window.schoolbellSessionBlocked; }
  });
}());
