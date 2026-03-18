<img width="37" height="37" alt="image" src="https://github.com/user-attachments/assets/a25adede-03fd-45a9-a07a-befe34a65021" />   |  TLDR: VPS + скрипт ниже = ускорение тг
:--- | :---

## 🚀 Автоматическая установка прокси TeleMT (протокол MTProto от TG)  
Цель: ускорить телеграм (загрузка контента)  
Средство: прокси-сервер, который маскирует трафик TG под обычный интернет-трафик

#### Cкрипт запуска менеджера (установка, удаление, статус, отключение\включение) TeleMT из готового образа ~5мб
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image.sh")
```

#### 📋 Что делает скрипт:
- Проверяет нужные зависимости и устанавливает при отсутствии
- Запрашивает параметры (порт, TLS домен для маскировка трафика, ad_tag ? не реализованно ⏳)
- Скачивает образ с Docker (источник `https://hub.docker.com/r/whn0thacked/telemt-docker`)  
- Генерирует файлы telemt.toml, docker-compose.yml, ключ
- Запускает установку  
допом скриптом можно отключить\включить прокси

####  🛠  Процесс установки:  
`выбор действия`  
<img width="753" height="291" alt="image" src="https://github.com/user-attachments/assets/01ab9b46-d91c-41c7-b8dc-6c88fabe57e6" />

`подготовка зависимостей`  
<img width="753" height="156" alt="image" src="https://github.com/user-attachments/assets/0d5613ac-8023-44be-a9c0-f9ac35e855e0" />

`разворачивание`  
<img width="753" height="263" alt="image" src="https://github.com/user-attachments/assets/b2071e4e-7a4d-4f2d-8549-5e84f31c578c" />

`результат`  
<img width="753" height="94" alt="image" src="https://github.com/user-attachments/assets/b7273739-4a5d-4ab4-b2ca-f2fcac0255f7" />



#### 📦 Особенности образа TeleMT
- Минимальный размер.
- Безопасность: Сборка `distroless`
- Запуск от non-root пользователя.
  
---
вариант 2  
###  Самостоятельная сборка образа, разворачивание на сервере
без проверки и установки зависимостей, для сборки необходимо иметь более 0,5GB памяти на сервере
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-source.sh")
```
####  🛠  Процесс установки:  
<img width="736" height="232" alt="image" src="https://github.com/user-attachments/assets/096fcb3b-cb7a-4201-8315-2fcc791de821" />

---

<details>
   <summary>Пошаговая инструкция и доп описание</summary>
  
> Описание

  TeleMT умеет не просто маскировать трафик, но и правильно реагировать на попытки внешних систем проверить, что же находится на вашем сервере. Если кто-то подключится к нему без специального секрета, TeleMT не обрывает соединение, а прозрачно перенаправляет его на реальный сайт (например, amazon.com или любой другой, который вы укажете)

  
|  | Обычное подключение | Через MTProto-прокси |
| :--- | :--- | :--- |
| **Суть** | Прямое соединение с сервером Telegram. | Соединение через промежуточный сервер (прокси). |
| **Видимость для провайдера** | <small>Четко видит, что трафик идет на IP-адреса Telegram. Может применить DPI и замедлить его.</small> | <small>Видит трафик на IP прокси. Сам трафик замаскирован под обычный HTTPS (например, как на сайт Amazon).</small> |
| **Скорость при замедлении** | <small>Сильно падает, так как провайдер намеренно режет скорость для этого типа трафика.</small> | <small>Остается высокой, так как провайдер не может определить, что это Telegram, и не применяет к нему правила замедления.</small> |
| **Цель использования** | Стандартный режим для работы в странах без ограничений. | Обход замедлений со стороны провайдера. |

> Инструкция

0) Покупаем VDS (с постоянным ip это 99% тарифов) вне границ действия замедления, получаем логин\ip\пароль.
1) Скачиваем putty, к примеру тут https://portableapps.com/apps/internet/putty_portable
2) Через putty подключаемся к серверу (авторизуемся по данным из пункта 0).  
   (или делаем ярлык, вставляем логин\ip\пароль в свойства ярыка `..\putty_portable.exe root@YOUR_IP_HERE -pw your_pas_here`, не надо будет вводить снова)
3) Вставляем в терминал строку
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image.sh")
```
копировать, пкм в поле терминала вставит текст из буфера, ввод  
<img width="519" height="213" alt="image" src="https://github.com/user-attachments/assets/8e825430-5714-460e-8595-7a82cc9b5633" />  

4) После завершения скрипт выдаст ссылку вида:  
🔗 LINK: tg://proxy?server=IP&port=PORT&secret=SECRET
7) Активация: Просто скопируйте её и отправьте себе в Telegram (можно в "Избранное"), затем нажмите на неё для активации прокси.  
<img width="371" height="540" alt="image" src="https://github.com/user-attachments/assets/45911a5b-b045-4fc8-8772-df2eef4cfbd2" />
</details>  






----

####  🔗 Полезные ссылки  
Источник: Telemt - MTProxy on Rust + Tokio: https://github.com/telemt/telemt  
Сборка образа: https://github.com/An0nX/telemt-docker / [whn0thacked/telemt-docker](https://hub.docker.com/r/whn0thacked/telemt-docker)
