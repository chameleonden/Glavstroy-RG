# Скрипты проверки статусов внутренних номеров

Два скрипта для проверки статусов внутренних номеров через HTTPS API и фильтрации номеров со статусом "В офисе".

## Файлы

- `check_status.php` - PHP скрипт
- `check_status.sh` - Bash скрипт

## Требования

### Для PHP скрипта:
- PHP 5.6+ с расширениями:
  - curl
  - libxml
  - simplexml

### Для Bash скрипта:
- curl
- xmlstarlet или xmllint (для парсинга XML)

Установка зависимостей:
```bash
# Для xmlstarlet
sudo apt-get install xmlstarlet

# Или для xmllint
sudo apt-get install libxml2-utils
```

## Использование

### 1. Установите переменную окружения с URL API:

```bash
export API_URL='https://your-api-url.com/api/users'
```

### 2. Запустите скрипт с номерами:

**PHP скрипт:**
```bash
# Передача номеров как аргументы
php check_status.php 3820 3187 3801 3228

# Или через stdin
echo "3820 3187 3801" | php check_status.php

# Или из файла
cat numbers.txt | php check_status.php
```

**Bash скрипт:**
```bash
# Передача номеров как аргументы
./check_status.sh 3820 3187 3801 3228

# Или через stdin
echo "3820 3187 3801" | ./check_status.sh

# Или из файла
cat numbers.txt | ./check_status.sh
```

## Формат вывода

Скрипты выводят только те номера, у которых статус "В офисе":

```
Найдены номера со статусом 'В офисе':
3187 - Альгешкина, Ольга (В офисе)
3228 - Епифанова, Елена (В офисе)
3801 - Бедерова, Алёна (В офисе)
3820 - Аверьянова, Ольга (В офисе)
```

## Примеры

### Проверка одного номера:
```bash
export API_URL='https://example.com/api/users'
php check_status.php 3820
```

### Проверка нескольких номеров:
```bash
export API_URL='https://example.com/api/users'
php check_status.php 3820 3187 3801 3228 3802
```

### Использование с файлом:
```bash
# Создайте файл numbers.txt с номерами (по одному на строку или через пробел)
echo "3820 3187 3801" > numbers.txt

export API_URL='https://example.com/api/users'
cat numbers.txt | php check_status.php
```

## Обработка ошибок

Скрипты обрабатывают следующие ошибки:
- Отсутствие URL API
- Отсутствие номеров для проверки
- Ошибки HTTP запроса
- Ошибки парсинга XML
- Отсутствие необходимых утилит (для bash скрипта)

При ошибках скрипты выводят сообщения в stderr и завершаются с кодом ошибки.
