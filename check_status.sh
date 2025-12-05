#!/bin/bash
#
# Скрипт для проверки статусов внутренних номеров
# Использование: ./check_status.sh номер1 номер2 номер3 ...
# Или: echo "номер1 номер2" | ./check_status.sh
#

# URL API - измените на ваш адрес
DEFAULT_API_URL="https://your-api-url.com/api/users"

# Используем переменную окружения, если установлена, иначе значение по умолчанию
API_URL="${API_URL:-$DEFAULT_API_URL}"

# Проверяем, что URL установлен и не является значением по умолчанию
if [ -z "$API_URL" ] || [ "$API_URL" = "https://your-api-url.com/api/users" ]; then
    echo "Ошибка: Не указан URL API." >&2
    echo "Измените переменную DEFAULT_API_URL в скрипте (строка 9) или установите переменную окружения API_URL" >&2
    echo "Пример: export API_URL='https://example.com/api/users'" >&2
    exit 1
fi

# Отладочный режим (можно включить через переменную окружения DEBUG=1)
DEBUG="${DEBUG:-0}"

# Получаем номера из аргументов или из stdin
if [ $# -gt 0 ]; then
    # Номера переданы как аргументы
    NUMBERS=("$@")
else
    # Читаем из stdin
    read -r input
    if [ -z "$input" ]; then
        echo "Ошибка: Не указаны номера для проверки" >&2
        echo "Использование: $0 номер1 номер2 номер3 ..." >&2
        echo "Или: echo 'номер1 номер2' | $0" >&2
        exit 1
    fi
    # Разбиваем по пробелам и запятым
    NUMBERS=($(echo "$input" | tr ', ' '\n' | grep -v '^$'))
fi

if [ ${#NUMBERS[@]} -eq 0 ]; then
    echo "Ошибка: Не указаны номера для проверки" >&2
    exit 1
fi

# Выполняем HTTPS запрос
if ! command -v curl &> /dev/null; then
    echo "Ошибка: curl не установлен" >&2
    exit 1
fi

if [ "$DEBUG" = "1" ]; then
    echo "Запрос к API: $API_URL" >&2
fi

RESPONSE=$(curl -s -w "\n%{http_code}" "$API_URL" 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
XML_CONTENT=$(echo "$RESPONSE" | sed '$d')

if [ "$DEBUG" = "1" ]; then
    echo "HTTP код: $HTTP_CODE" >&2
    echo "Размер ответа: ${#XML_CONTENT} байт" >&2
fi

if [ "$HTTP_CODE" != "200" ]; then
    echo "Ошибка HTTP: код $HTTP_CODE" >&2
    exit 1
fi

if [ -z "$XML_CONTENT" ]; then
    echo "Ошибка: Пустой ответ от сервера" >&2
    exit 1
fi

# Проверяем наличие xmlstarlet или xmllint для парсинга XML
PARSER=""
if command -v xmlstarlet &> /dev/null; then
    PARSER="xmlstarlet"
elif command -v xmllint &> /dev/null; then
    PARSER="xmllint"
else
    echo "Ошибка: Не найден xmlstarlet или xmllint для парсинга XML" >&2
    echo "Установите один из них: sudo apt-get install xmlstarlet или sudo apt-get install libxml2-utils" >&2
    exit 1
fi

# Создаем временный файл для XML
TMP_XML=$(mktemp)
echo "$XML_CONTENT" > "$TMP_XML"

# Нормализуем номера (убираем пробелы) и создаем массив для быстрого поиска
declare -A NUMBERS_MAP
for NUMBER in "${NUMBERS[@]}"; do
    NUMBER=$(echo "$NUMBER" | tr -d '[:space:]')
    if [ -n "$NUMBER" ]; then
        NUMBERS_MAP["$NUMBER"]=1
    fi
done

if [ "$DEBUG" = "1" ]; then
    echo "Ищем номера: ${!NUMBERS_MAP[@]}" >&2
fi

# Обрабатываем всех пользователей из XML
FOUND_NUMBERS=()

if [ "$PARSER" = "xmlstarlet" ]; then
    # Используем xmlstarlet - получаем все пользователи и обрабатываем
    USER_COUNT=$(xmlstarlet sel -t -c "count(/users/user)" "$TMP_XML" 2>/dev/null)
    
    for ((i=1; i<=USER_COUNT; i++)); do
        PHONE=$(xmlstarlet sel -t -v "normalize-space(/users/user[$i]/address1_telephone1)" "$TMP_XML" 2>/dev/null)
        STATUS=$(xmlstarlet sel -t -v "normalize-space(/users/user[$i]/tisa_useraccessibilitycode)" "$TMP_XML" 2>/dev/null)
        FULLNAME=$(xmlstarlet sel -t -v "normalize-space(/users/user[$i]/fullname)" "$TMP_XML" 2>/dev/null)
        
        # Пропускаем, если номер пустой
        if [ -z "$PHONE" ]; then
            continue
        fi
        
        # Проверяем, есть ли этот номер в списке запрошенных
        if [ -n "${NUMBERS_MAP[$PHONE]:-}" ] && [ "$STATUS" = "В офисе" ]; then
            FOUND_NUMBERS+=("$PHONE|$FULLNAME|$STATUS")
            if [ "$DEBUG" = "1" ]; then
                echo "Найден: $PHONE - $FULLNAME ($STATUS)" >&2
            fi
        elif [ "$DEBUG" = "1" ] && [ -n "${NUMBERS_MAP[$PHONE]:-}" ]; then
            echo "Номер $PHONE найден, но статус: '$STATUS' (не 'В офисе')" >&2
        fi
    done
else
    # Используем более простой подход с grep и sed
    # Создаем временный файл для результатов
    TMP_RESULTS=$(mktemp)
    
    # Извлекаем все блоки пользователей
    awk '
    BEGIN { RS="<user>"; FS="\n" }
    NR > 1 {
        phone = ""
        status = ""
        fullname = ""
        for (i=1; i<=NF; i++) {
            if ($i ~ /<address1_telephone1>/) {
                gsub(/.*<address1_telephone1>/, "", $i)
                gsub(/<\/address1_telephone1>.*/, "", $i)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                phone = $i
            }
            if ($i ~ /<tisa_useraccessibilitycode>/) {
                gsub(/.*<tisa_useraccessibilitycode>/, "", $i)
                gsub(/<\/tisa_useraccessibilitycode>.*/, "", $i)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                status = $i
            }
            if ($i ~ /<fullname>/) {
                gsub(/.*<fullname>/, "", $i)
                gsub(/<\/fullname>.*/, "", $i)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                fullname = $i
            }
        }
        if (phone != "" && status == "В офисе") {
            print phone "|" fullname "|" status
        }
    }
    ' "$TMP_XML" > "$TMP_RESULTS"
    
    # Обрабатываем результаты
    while IFS='|' read -r PHONE FULLNAME STATUS; do
        # Пропускаем, если номер пустой
        if [ -z "$PHONE" ]; then
            continue
        fi
        
        # Проверяем, есть ли этот номер в списке запрошенных
        if [ -n "${NUMBERS_MAP[$PHONE]:-}" ]; then
            FOUND_NUMBERS+=("$PHONE|$FULLNAME|$STATUS")
        fi
    done < "$TMP_RESULTS"
    
    rm -f "$TMP_RESULTS"
fi

# Удаляем временный файл
rm -f "$TMP_XML"

# Выводим результаты
if [ ${#FOUND_NUMBERS[@]} -eq 0 ]; then
    exit 0
fi

# Извлекаем только номера и сортируем
NUMBERS_ONLY=()
for ITEM in "${FOUND_NUMBERS[@]}"; do
    NUMBER=$(echo "$ITEM" | cut -d'|' -f1)
    NUMBERS_ONLY+=("$NUMBER")
done

# Сортируем номера
IFS=$'\n' SORTED_NUMBERS=($(printf '%s\n' "${NUMBERS_ONLY[@]}" | sort -n))
unset IFS

# Выводим номера через разделитель "#-" с "#" после каждого номера
RESULT=""
for NUMBER in "${SORTED_NUMBERS[@]}"; do
    RESULT="${RESULT}${NUMBER}#-"
done
# Убираем последний "-" (остается "#" после последнего номера)
if [ -n "$RESULT" ]; then
    echo "${RESULT%-}"
fi

exit 0
