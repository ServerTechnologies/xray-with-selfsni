# Инструкция по созданию ВПН с маскировкой под собственный сайт на панелях

> Маскировка запросов под собственный сайт - один из самых надежных способов обезопасить свой сервер от блокировок, так как, в отличие от Vless Reality мы маскируем запросы под обращение к сайту на том же самом сервере, что и впн, а не к стороннему сайту, который расположен на сервере с другим ip. Также при прямом запросе по домену сервер отдает обычный сайт и понять что на сервере помимо вебсервера установлен еще и сервер ВПН будет очень сложно.

Здесь представлена инструкция по созданию ВПН с маскировкой под собственный сайт на панелях Marzban и 3x-ui. Инструкция для голого ядра находится [здесь](https://github.com/ServerTechnologies/xray-with-selfsni).

## VPS для создания ВПН
Для установки панели нам понадобится VPS-сервер. Приобрести его можно в [Fornex](https://fornex.com/c/ftsg5x/).

## Минимальные системные требования

- 1 CPU  
- 1 GB RAM  
- 10 GB диска  
- ОС Ubuntu 24 x64

## Подготовка.
Так как на сервере будет функционировать обычный сайт, нам обязательно нужен домен. Можно купить домен в любой зоне. Можно выбрать самый дешевый, но не забудьте про продление домена. Оно может быть существенно дороже покупки. Направьте домен на сервер, создав А запись в DNS.
- Направьте домен на сервер, создав А запись в DNS. проверить обновление DNS записей можно командой ping <имя домена>. <имя домена> надо заменить на ваш домен. В ответ вы должны молучить ip сервера.
```sh
ping <имя домена>
```

### Перед началом работы с сервером
Обовление списка репозиториев и установленных пакетов
```sh
apt update && apt upgrade -y
```

Очистить экран терминала
```sh
clear
```

## Установка панели
Установите панель с помощью этой команды:
```sh
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
```
## Настройка для 3x-ui.
В первую очередь стоит подключить домен к панели и получить TLS сертификат. Для этого через меню x-ui выбираем соответствующие пункты (SSL Certificate Management или Cloudflare SSL Certificate). Чтобы избежать проблем с обновлением сертификатов, рекомендую подключать через Cloudflare.

Далее создаем инбаунд со следующими настройками:\
Протокол vless\
Порт 443\
Транспорт TCP (RAW)\
Безопасность TLS\
ALPN http/1.1\
SSL сертификат Путь к сертификату\
Установить сертификат панели\
\
В настройках клиента указываем flow: xtls-rprx-vision\
\
В Fallbacks, в поле Dest, указываем 8080\
\
Жмем создать

### Установка Nginx, создание сайта

Устанавливаем Nginx
```sh
sudo apt install nginx -y
```

Задаем переменную с именем вашего домена, замените "vash-domen" на ваше доменное имя. Указывайте только имя домена, без http:// или https://
```sh
export domain=vash-domen
```

Заменяем дефолтный файл конфигурации.
```sh
cat << EOF > /etc/nginx/sites-available/default
server {
        listen 80;
        server_name $domain;
        return 301 https://\$http_host\$request_uri;
       }


server {
        listen 127.0.0.1:8080;
        server_name $domain;
        root /var/www/html/;
        index index.html;
        add_header Strict-Transport-Security "max-age=63072000" always;
}
EOF
mv /var/www/html/index.nginx-debian.html /var/www/html/index.html
systemctl restart nginx
```

Можете поставить главной страницей шаблон предложенный мною установка одной командой
```
sudo bash -c 'if command -v wget &> /dev/null; then echo "Используется: wget" && wget -O /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html && echo "Файл успешно скачан в /var/www/html/index.html"; elif command -v curl &> /dev/null; then echo "Используется: curl" && curl -o /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html && echo "Файл успешно скачан в /var/www/html/index.html"; else echo "Ошибка: ни wget, ни curl не установлены"; exit 1; fi'

```

Готово.



## Настройка для Marzban.

### Установка Nginx
В первую очередь устанавливаем Nginx
```sh
apt install nginx -y
```

### Установка Marzban

Установка Marzban описана [здесь](https://github.com/ServerTechnologies/youtube-instructions/blob/main/marzban-settings.md)

Разница заключается только в команде получения сертификата. В пункте "Создание SSL сертификатов", в разделе "И запускаем утилиту, которая создаст сертификат:" вместо указанной там команды для получения сертификатов стоит использовать эти команды:

Задаем переменную с именем нащего домена, замените <имя домена> на ваш домен:
```sh
export DOMAIN=<имя домена>
```

И запускаем команду создания сертификата:

```sh
mkdir -p /var/lib/marzban/certs

~/.acme.sh/acme.sh \
  --issue --force -w /var/www/html -d "$DOMAIN" \
  --fullchain-file "/var/lib/marzban/certs/$DOMAIN.cer" \
  --key-file "/var/lib/marzban/certs/$DOMAIN.cer.key"
```

Остальные пункты инструкции выполняются как есть, заменяем только одну команду для получение сертификатов.

### Создание сайта

Задаем переменную с вашим доменом. Замените "vash-domen" на ваше доменнное имя.
```sh
export domain=vash-domen
```

Заменяем дефолтный файл конфигурации Nginx.
```sh
cat << EOF > /etc/nginx/sites-available/default
server {
        listen 80;
        server_name $domain;
        return 301 https://\$http_host\$request_uri;
       }


server {
        listen 127.0.0.1:8080;
        server_name $domain;
        root /var/www/html/;
        index index.html;
        add_header Strict-Transport-Security "max-age=63072000" always;
}
EOF
mv /var/www/html/index.nginx-debian.html /var/www/html/index.html
systemctl restart nginx
```

### Настройка инбаундов
Настройка инбаундов производится через иконку настроек в правом верхнем углу экрана (иконка в виде шестеренки). Туда, в inbounds, необходимо добавить слудующий блок:

```sh
{
    "tag": "VLESS TCP TLS",
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
    "clients": [],
    "decryption": "none",
    "fallbacks": [
        {
        "dest": 8080
        }
    ]
    },
    "streamSettings": {
    "network": "tcp",
    "security": "tls",
    "tlsSettings": {
        "alpn": "http/1.1",
        "certificates": [
        {
            "certificateFile": "/var/lib/marzban/certs/vash-domen.cer",
            "keyFile": "/var/lib/marzban/certs/vash-domen.cer.key"
        }
        ],
        "minVersion": "1.2",
        "cipherSuites": "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
    }
}
}
```

В **certificateFile** и **keyFile** необходимо указать путь до папок в которые установлены сертификаты к вашему домену.\
После чего нужно нажать **"Сохранить"**, **"Перезагрузить ядро"** и обновить страницу в браузере.\
Далее в правом верхнем углу иконка в виде трех тире (бургер меню) откройте настройки хоста, выбирите соответствующий инбаунд (VLESS TCP TLS), замените **{SERVER_IP}** на ваш домен, далее в дополнительных опциях надо выставить **ALPN** равный **http/1.1** и выбрать **fingerprint**. Для сохранения настроек нажмите **"Применить"**. Обновите страницу.\
\
Далее можно создавать подключения чрез интерфейс. При создании подключения выберите "VLESS TCP TLS"

## Работа с файлами сайта
Xтобы удалить дефолтную страницу
```sh
rm /var/www/html/index.html
```

Или можно открыть дефолтную страницу, используя консольный текстовый редактор, чтобы вставить другой текст
```sh
nano /var/www/html/index.html
```
Чтобы сохранить документ и выйти из текстового редактора, нажмите CTRL + X Y Enter\

Адрес папки, куда надо закинуть файлы сайта. Главный файл сайта должен называться index.html
```sh
/var/www/html/
```

Чтобы открыть папку с файлами сайта
```sh
cd /var/www/html/index.html
```

Установить unzip
```sh
apt install unzip
```

Разархивировать zip архив. Замените <имя архива.zip> на имя архива
```sh
unzip <имя архива.zip>
```

Скопировать файлы из папки с шаблоном в папку с сайтом. Тут я заменил "." на абсолютный путь. Замените <имя папки> на имя папки с шаблоном
```sh
cp -r <имя папки>/* /var/www/html/index.html
```

Можете поставить главной страницей шаблон предложенный мною установка одной командой
```
sudo bash -c 'if command -v wget &> /dev/null; then echo "Используется: wget" && wget -O /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html && echo "Файл успешно скачан в /var/www/html/index.html"; elif command -v curl &> /dev/null; then echo "Используется: curl" && curl -o /var/www/html/index.html https://raw.githubusercontent.com/pegakmop/xray-with-selfsni/refs/heads/main/var/www/html/index.html && echo "Файл успешно скачан в /var/www/html/index.html"; else echo "Ошибка: ни wget, ни curl не установлены"; exit 1; fi'

```



