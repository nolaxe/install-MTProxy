[EN](https://github.com/nolaxe/install-MTProxy/blob/main/README-EN.md)  |  [RU](https://github.com/nolaxe/install-MTProxy/blob/main/README.md)    
<img width="37" height="37" alt="image" src="https://github.com/user-attachments/assets/a25adede-03fd-45a9-a07a-befe34a65021" />   |  TLDR: VPS + скрипт ниже = ускорение тг
:--- | :---

## 🚀 Скрипт автоматической установки прокси TeleMT (протокол MTProto) из готового образа ~5мб
Цель: ускорить телеграм (загрузка контента фото, видео)  
Средство: прокси-сервер, который маскирует трафик TG под обычный интернет-трафик

#### 📦 Особенности образа TeleMT
- Минимальный размер.
- Безопасность: Сборка `distroless`
- Запуск от non-root пользователя.  

#### 🛠 Установка  
Необходимо просто запустить скрипт для установки контейнера
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image.sh")
```
... расширенный вариант (мультипользователи, ad_tag, просмотр статистики использования) *upd 2026-04-06
```
bash <(curl -s "https://raw.githubusercontent.com/nolaxe/install-MTProxy/main/telemt-from-image-mu.sh")
```
#### 📋 Что делает скрипт:
- Проверяет нужные зависимости и устанавливает при отсутствии (Ubuntu 24)
- Запрашивает параметры у пользователя (порт, TLS домен) т.к. сборка без рут прав занятость портов<1024 необходимо смотреть самостоятельно 
- Генерирует секреты (Префикс + Основной ключ + Домен в HEX)
- Генерирует файлы telemt.toml, docker-compose.yml  
- Скачивает собранный образ telemt (источник `https://hub.docker.com/r/whn0thacked/telemt-docker`)  
- Запускает установку
- Выводит на экран и в файл ссылки для подключения

####  🛠  Процесс разворачивания telemt:  
`меню`  
<img width="571" height="469" alt="image" src="https://github.com/user-attachments/assets/53d6c723-4cad-4503-a488-7b7fac610fdf" />  
`подготовка зависимостей`  
<img width="743" height="140" alt="image" src="https://github.com/user-attachments/assets/adeaad6f-8d78-47c4-914d-1bd87870cd71" />  
 `ввод переменных`  
<img width="743" height="317" alt="image" src="https://github.com/user-attachments/assets/2b5d767d-cce7-462b-b0a0-1f3de5e65dfd" />  
`разворачивание`  
  <img width="743" height="104" alt="image" src="https://github.com/user-attachments/assets/c43bee4c-01d0-44b6-a286-8936c71ca004" />  
 `результат`  
<img width="743" height="180" alt="image" src="https://github.com/user-attachments/assets/da5a5c10-07cd-4b8c-b399-aed3b0e66889" />  

`+файл со ссылками proxy_link.txt`  
<img width="743" height="100" alt="image" src="https://github.com/user-attachments/assets/abb570a1-7311-4b67-9b7d-6ca9f6d3b05f" />  
`+cтатистика из api telemt`  
<img width="304" height="77" alt="image" src="https://github.com/user-attachments/assets/502ca659-1c07-4e59-8be2-9643a1803fe2" />  

####  ✨ Готово, можно использовать полученные ссылки для подключения  

<details>
   <summary>🎁</summary>
<img width="400" height="400" alt="Image" src="https://github.com/user-attachments/assets/50a477e5-74a6-45ea-afb9-4e18f4cdfaa5" />
</details>

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

<details>
   <summary>Как сделать красивый адрес</summary>  
Чтобы вместо IP-адреса в ссылке отображался домен, нужно привязать ваш сервер к доменному имени через DNS-записи на бесплатных сервисах  
https://ydns.io/hosts, https://www.noip.com, https://www.duckdns.org и т.п.  
- в итоге, вместо tg://proxy?server=157.257.147.157&port=43&secret=ee667c4....  
- получим tg://proxy?server=rknonelove.ydns.com&port=43&secret=ee667....  
</details>  

----

####  🔗 Полезные ссылки  
Сборка образа Telemt от An0nX: https://github.com/An0nX/telemt-docker / [whn0thacked/telemt-docker](https://hub.docker.com/r/whn0thacked/telemt-docker). 

Разработчики Telemt: https://github.com/telemt/telemt

