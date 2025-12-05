#!/usr/bin/env php
<?php
/**
 * Скрипт для проверки статусов внутренних номеров
 * Использование: php check_status.php номер1 номер2 номер3 ...
 * Или: echo "номер1 номер2" | php check_status.php
 */

// URL API - измените на ваш адрес
$apiUrl = 'https://your-api-url.com/api/users';

// Можно переопределить через переменную окружения
if (getenv('API_URL')) {
    $apiUrl = getenv('API_URL');
}

if (empty($apiUrl) || $apiUrl === 'https://your-api-url.com/api/users') {
    fwrite(STDERR, "Ошибка: Не указан URL API.\n");
    fwrite(STDERR, "Измените переменную \$apiUrl в скрипте или установите переменную окружения API_URL\n");
    fwrite(STDERR, "Пример: export API_URL='https://example.com/api/users'\n");
    exit(1);
}

// Получаем номера из аргументов командной строки или из stdin
$numbers = [];
if ($argc > 1) {
    // Номера переданы как аргументы
    $numbers = array_slice($argv, 1);
} else {
    // Читаем из stdin
    $input = trim(stream_get_contents(STDIN));
    if (!empty($input)) {
        $numbers = preg_split('/[\s,]+/', $input);
    }
}

if (empty($numbers)) {
    fwrite(STDERR, "Ошибка: Не указаны номера для проверки\n");
    fwrite(STDERR, "Использование: php check_status.php номер1 номер2 номер3 ...\n");
    fwrite(STDERR, "Или: echo 'номер1 номер2' | php check_status.php\n");
    exit(1);
}

// Нормализуем номера (убираем пробелы)
$numbers = array_map('trim', $numbers);
$numbers = array_filter($numbers, function($n) { return !empty($n); });

// Создаем массив для быстрого поиска
$numbersMap = array_flip($numbers);

// Выполняем HTTPS запрос
$ch = curl_init($apiUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

if ($error) {
    fwrite(STDERR, "Ошибка при выполнении запроса: $error\n");
    exit(1);
}

if ($httpCode !== 200) {
    fwrite(STDERR, "Ошибка HTTP: код $httpCode\n");
    exit(1);
}

if (empty($response)) {
    fwrite(STDERR, "Ошибка: Пустой ответ от сервера\n");
    exit(1);
}

// Парсим XML
libxml_use_internal_errors(true);
$xml = simplexml_load_string($response);

if ($xml === false) {
    $errors = libxml_get_errors();
    fwrite(STDERR, "Ошибка парсинга XML:\n");
    foreach ($errors as $error) {
        fwrite(STDERR, "  " . trim($error->message) . "\n");
    }
    exit(1);
}

// Обрабатываем пользователей
$foundNumbers = [];

foreach ($xml->user as $user) {
    $phone = trim((string)$user->address1_telephone1);
    $status = trim((string)$user->tisa_useraccessibilitycode);
    $fullname = trim((string)$user->fullname);
    
    // Проверяем, есть ли этот номер в списке запрошенных
    if (isset($numbersMap[$phone])) {
        // Проверяем статус
        if ($status === 'В офисе') {
            $foundNumbers[] = [
                'number' => $phone,
                'name' => $fullname,
                'status' => $status
            ];
        }
    }
}

// Выводим результаты
if (empty($foundNumbers)) {
    echo "Номера со статусом 'В офисе' не найдены.\n";
    exit(0);
}

// Сортируем по номеру для удобства
usort($foundNumbers, function($a, $b) {
    return strcmp($a['number'], $b['number']);
});

echo "Найдены номера со статусом 'В офисе':\n";
foreach ($foundNumbers as $item) {
    echo sprintf("%s - %s (%s)\n", $item['number'], $item['name'], $item['status']);
}

exit(0);
