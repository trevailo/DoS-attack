#!/bin/bash

# Функция для отправки запросов
send_request() {
    local url=$1
    local port=$2
    local proxy=$3
    response=$(curl -s -o /dev/null -w "%{http_code}" --proxy "$proxy" "$url:$port")
    
    if [ "$response" -eq 200 ]; then
        echo -e "\e[32mResponse Code: $response - Success (Proxy: $proxy)\e[0m"
    else
        echo -e "\e[33mResponse Code: $response - Error (Proxy: $proxy)\e[0m"
    fi
}

# Функция для отображения справки
usage() {
    echo "Использование: $0 -t <target> -p <port> -n <num_threads> [-x <proxy_list>]"
    echo "  -t <target>      URL или IP-адрес сайта (например, http://example.com)"
    echo "  -p <port>       Порт (например, 80 или 443)"
    echo "  -n <num_threads> Количество потоков (положительное целое число)"
    echo "  -x <proxy_list>  Файл с прокси-серверами (один прокси на строку, необязательный)"
    echo "  -h, -help       Показать эту справку"
    exit 1
}

# Обработка аргументов командной строки
while getopts ":t:p:n:x:h" opt; do
    case $opt in
        t)
            target="$OPTARG"
            ;;
        p)
            port="$OPTARG"
            ;;
        n)
            num_threads="$OPTARG"
            ;;
        x)
            proxy_list="$OPTARG"
            ;;
        h|help)
            usage
            ;;
        \?)
            echo -e "\e[31mНеверный параметр: -$OPTARG\e[0m" >&2
            usage
            ;;
        :)
            echo -e "\e[31mОпция -$OPTARG требует аргумент.\e[0m" >&2
            usage
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$target" ] || [ -z "$port" ] || [ -z "$num_threads" ]; then
    echo -e "\e[31mОшибка: Необходимо указать целевой URL, порт и количество потоков.\e[0m"
    usage
fi

# Проверка, что количество потоков является положительным целым числом
if ! [[ "$num_threads" =~ ^[0-9]+$ ]] || [ "$num_threads" -le 0 ]; then
    echo -e "\e[31mОшибка: Количество потоков должно быть положительным целым числом.\e[0m"
    exit 1
fi

# Чтение прокси из файла, если он указан
if [ -n "$proxy_list" ]; then
    mapfile -t proxies < "$proxy_list"
    total_proxies=${#proxies[@]}
else
    total_proxies=0
fi

# Запуск потоков
for ((i=0; i<num_threads; i++)); do
    if [ $total_proxies -gt 0 ]; then
        proxy=${proxies[$i % total_proxies]}  # Использование прокси по кругу
        send_request "$target" "$port" "$proxy" &
    else
        send_request "$target" "$port" "" &
    fi
    sleep 0.1  # Небольшая задержка между запусками потоков
done

# Ожидание завершения всех фоновых процессов
wait

echo -e "\e[32mStress test completed.\e[0m"