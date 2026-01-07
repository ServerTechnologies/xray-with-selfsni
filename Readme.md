# Инструкция по созданию ВПН с маскировкой под собственный сайт на голом ядре X-Ray

>Маскировка запросов под собственный сайт - один из самых надежных способов обезопасить свой сервер от блокировок, так как, в отличие от Vless Reality мы маскируем запросы под обращение к сайту на том же самом сервере, что и впн, а не к стороннему сайту, который может расположен на сервере с другим ip. Так же при прямом запросе по домену сервер отдает обычный сайт и понять что на сервере помимо вебсервера установлен еще и сервер ВПН будет очень сложно.

Здесь представлена инструкция по созданию ВПН с маскировкой под собственный сайт на голом ядре, инструкция для панелей 3x-ui и Marzban находится [здесь](https://github.com/ServerTechnologies/xray-with-selfsni/blob/main/Panels.md).


## Минимальные системные требования

- 1 CPU  
- 1 GB RAM  
- 10 GB диска  
- ОС Ubuntu 24 x64

## Подготовка.
- Так как на сервере будет функционировать обычный сайт, нам обязательно нужен домен. Можно купить домен в любой зоне, можете выбрать самый дешевый, но не забудьте про прдление домена: оно может быть существенно дороже стоимости покупки. Можно купить домен на один год, через год купить другой домен и сделать все заново.
- Направьте домен на сервер, создав А запись в DNS.

## Как пользоваться скриптом. Установка ядра Xray с протоколом Vless.

Скрипт создавался и тестировался под ОС Ubuntu 22 x64 и Ubuntu 24 x64. На других ОС скрипт может работать некорректно.

Задайте переменную с именем вашего сайта, замените "vash-domen" на ваш домен, укажите просто имя домена, не указывайте http:// или https://:
```sh
export domain=vash-domen
```

Скачайте и запустите скрипт, используя эту команду:

```sh
wget -qO- https://raw.githubusercontent.com/ServerTechnologies/xray-with-selfsni/refs/heads/main/selfsni | bash
```

Скрипт установит веб сервер Nginx, создаст сертификаты Let's Encrypt, подключит их и в качестве сайта будет использоваться дефолтная страница веб-сервера Nginx. Если вы хотите добавить собственный сайт, то надо удалить дефолтную страницу и вместо нее разместить в папке файлы сайта.

Чтобы удалить дефолтную страницу
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

## Команды для управления пользователями

**Вывести список всех клиентов:**

```sh
userlist
```

**Вывести ссылку и QR-код для подключения основного пользователя:**

```sh
mainuser
```

**Создать нового пользователя:**

```sh
newuser
```

**Удалить пользователя:**

```sh
rmuser
```

**Создать ссылку для подключения:**

```sh
sharelink
```

В домашней папке пользователя будет создан файл `help` — в нём содержатся подсказки с описанием команд. Посмотреть его можно с помощью команды (нужно находиться в домашней папке пользователя):

```sh
cat help
```

## Команда для обновления ядра
```sh
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

## Полезные ссылки

- [GitHub проекта X-ray Core](https://github.com/XTLS/Xray-core)
- [Официальная документация на русском](https://xtls.github.io/ru/)
- [Ссылка на раздел официальной документации по созданию сайта для xray](https://xtls.github.io/ru/document/level-0/ch05-webpage.html)

## Клиенты для подключения

**Windows**

- [v2rayN](https://github.com/2dust/v2rayN)  
- [Furious](https://github.com/LorenEteval/Furious)  
- [Invisible Man - Xray](https://github.com/InvisibleManVPN/InvisibleMan-XRayClient)  

**Android**

- [v2rayNG](https://github.com/2dust/v2rayNG)  
- [X-flutter](https://github.com/XTLS/X-flutter)  
- [SaeedDev94/Xray](https://github.com/SaeedDev94/Xray)  

**iOS & macOS arm64**

- [Streisand](https://apps.apple.com/app/streisand/id6450534064)  
- [Happ](https://apps.apple.com/app/happ-proxy-utility/id6504287215)  
- [OneXray](https://github.com/OneXray/OneXray)  

**macOS arm64 & x64**

- [V2rayU](https://github.com/yanue/V2rayU)  
- [V2RayXS](https://github.com/tzmax/V2RayXS)  
- [Furious](https://github.com/LorenEteval/Furious)  
- [OneXray](https://github.com/OneXray/OneXray)  

**Linux**

- [Nekoray](https://github.com/MatsuriDayo/nekoray)  
- [v2rayA](https://github.com/v2rayA/v2rayA)  
- [Furious](https://github.com/LorenEteval/Furious)  

## Если вдруг нужно все удалить, то воспользуйтесь этими командами:
```sh
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
rm -r /usr/local/etc/xray
rm /usr/local/bin/userlist
rm /usr/local/bin/mainuser
rm /usr/local/bin/newuser
rm /usr/local/bin/rmuser
rm /usr/local/bin/sharelink
```