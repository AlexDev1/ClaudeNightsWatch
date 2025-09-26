#!/bin/bash

# Демон Claude Nights Watch - Автономное Выполнение Задач
# Основан на claude-auto-renew-daemon, но выполняет задачи вместо простых обновлений

LOG_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-daemon.log"
PID_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-daemon.pid"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
START_TIME_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-start-time"
TASK_FILE="task.md"
RULES_FILE="rules.md"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"

# Убеждаемся что директория логов существует
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Функция для логирования сообщений
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Функция для обработки завершения работы
cleanup() {
    log_message "Демон завершает работу..."
    rm -f "$PID_FILE"
    exit 0
}

# Настройка обработчиков сигналов
trap cleanup SIGTERM SIGINT

# Функция для проверки достижения времени запуска
is_start_time_reached() {
    if [ ! -f "$START_TIME_FILE" ]; then
        # Время запуска не установлено, всегда активен
        return 0
    fi
    
    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    
    if [ "$current_epoch" -ge "$start_epoch" ]; then
        return 0  # Время запуска достигнуто
    else
        return 1  # Всё ещё ожидаем
    fi
}

# Функция для получения времени до запуска
get_time_until_start() {
    if [ ! -f "$START_TIME_FILE" ]; then
        echo "0"
        return
    fi
    
    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    local diff=$((start_epoch - current_epoch))
    
    if [ "$diff" -le 0 ]; then
        echo "0"
    else
        echo "$diff"
    fi
}

# Функция для получения команды ccusage
get_ccusage_cmd() {
    if command -v ccusage &> /dev/null; then
        echo "ccusage"
    elif command -v bunx &> /dev/null; then
        echo "bunx ccusage"
    elif command -v npx &> /dev/null; then
        echo "npx ccusage@latest"
    else
        return 1
    fi
}

# Функция для получения минут до сброса
get_minutes_until_reset() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Используем JSON вывод с флагом --active для получения только активного блока
    local json_output=$($ccusage_cmd blocks --json --active 2>/dev/null)
    
    if [ -z "$json_output" ]; then
        # Нет активного блока - возвращаем 0 как в оригинальном поведении
        echo "0"
        return 0
    fi
    
    # Извлекаем endTime из активного блока
    local end_time=$(echo "$json_output" | grep '"endTime"' | head -1 | sed 's/.*"endTime": *"\([^"]*\)".*/\1/')
    
    if [ -z "$end_time" ]; then
        echo "0"
        return 0
    fi
    
    # Преобразуем ISO метку времени в Unix epoch для вычислений
    local end_epoch
    if command -v date &> /dev/null; then
        # Пробуем разные форматы команды date (macOS vs Linux)
        # Формат Linux (правильно обрабатывает UTC)
        if end_epoch=$(date -d "$end_time" +%s 2>/dev/null); then
            :
        # Формат macOS - нужно указать UTC часовой пояс
        elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "$end_time" +%s 2>/dev/null); then
            :
        # macOS format without milliseconds in UTC
        elif end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end_time" +%s 2>/dev/null); then
            :
        # Try stripping the .000Z and parsing in UTC
        elif stripped_time=$(echo "$end_time" | sed 's/\.000Z$/Z/') && end_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$stripped_time" +%s 2>/dev/null); then
            :
        else
            log_message "Не удалось разобрать формат ccusage endTime: $end_time" >&2
            echo "0"
            return 0
        fi
    else
        echo "0"
        return 0
    fi
    
    local current_epoch=$(date +%s)
    local time_diff=$((end_epoch - current_epoch))
    local remaining_minutes=$((time_diff / 60))
    
    if [ "$remaining_minutes" -gt 0 ]; then
        echo $remaining_minutes
    else
        echo "0"
        return 0
    fi
}

# Функция для подготовки задачи с правилами
prepare_task_prompt() {
    local prompt=""
    
    # Добавляем правила если они существуют
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        prompt="IMPORTANT RULES TO FOLLOW:\n\n"
        prompt+=$(cat "$TASK_DIR/$RULES_FILE")
        prompt+="\n\n---END OF RULES---\n\n"
        log_message "Применены правила из $RULES_FILE"
    fi
    
    # Добавляем содержание задачи
    if [ -f "$TASK_DIR/$TASK_FILE" ]; then
        prompt+="TASK TO EXECUTE:\n\n"
        prompt+=$(cat "$TASK_DIR/$TASK_FILE")
        prompt+="\n\n---END OF TASK---\n\n"
        prompt+="Please read the above task, create a todo list from it, and then execute it step by step."
    else
        log_message "ERROR: Task file not found at $TASK_DIR/$TASK_FILE"
        return 1
    fi
    
    echo -e "$prompt"
}

# Функция для выполнения задачи
execute_task() {
    log_message "Запуск выполнения задачи из $TASK_FILE..."
    
    if ! command -v claude &> /dev/null; then
        log_message "ОШИБКА: команда claude не найдена"
        return 1
    fi
    
    # Check if task file exists
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        log_message "ERROR: Task file not found at $TASK_DIR/$TASK_FILE"
        return 1
    fi
    
    # Подготавливаем полный промпт с правилами и задачей
    local full_prompt=$(prepare_task_prompt)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_message "Выполнение задачи с Claude (автономный режим)..."
    
    # Логируем полный отправляемый промпт
    echo "" >> "$LOG_FILE"
    echo "=== PROMPT SENT TO CLAUDE ===" >> "$LOG_FILE"
    echo -e "$full_prompt" >> "$LOG_FILE"
    echo "=== END OF PROMPT ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Выполняем задачу с Claude в автономном режиме
    # Логируем всё - и выполнение, и ответ
    log_message "=== CLAUDE RESPONSE START ==="
    (echo -e "$full_prompt" | claude --dangerously-skip-permissions 2>&1) | tee -a "$LOG_FILE" &
    local pid=$!
    
    # Мониторим выполнение (без таймаута для сложных задач)
    log_message "Выполнение задачи запущено (PID: $pid)"
    
    # Ожидаем завершения
    wait $pid
    local result=$?
    
    log_message "=== CLAUDE RESPONSE END ==="
    
    if [ $result -eq 0 ]; then
        log_message "Выполнение задачи успешно завершено"
        date +%s > "$LAST_ACTIVITY_FILE"
        return 0
    else
        log_message "ОШИБКА: Выполнение задачи завершилось с кодом $result"
        return 1
    fi
}

# Функция для вычисления времени следующей проверки
calculate_sleep_duration() {
    local minutes_remaining=$(get_minutes_until_reset)
    
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        log_message "Осталось времени: $minutes_remaining минут" >&2
        
        if [ "$minutes_remaining" -le 5 ]; then
            # Проверяем каждые 30 секунд когда близко к сбросу
            echo 30
        elif [ "$minutes_remaining" -le 30 ]; then
            # Проверяем каждые 2 минуты когда осталось менее 30 минут
            echo 120
        else
            # Проверяем каждые 10 минут в остальных случаях
            echo 600
        fi
    else
        # Запасной вариант: проверяем на основе последней активности
        if [ -f "$LAST_ACTIVITY_FILE" ]; then
            local last_activity=$(cat "$LAST_ACTIVITY_FILE")
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_activity))
            local remaining=$((18000 - time_diff))  # 5 часов = 18000 секунд
            
            if [ "$remaining" -le 300 ]; then  # 5 минут
                echo 30
            elif [ "$remaining" -le 1800 ]; then  # 30 минут
                echo 120
            else
                echo 600
            fi
        else
            # Нет информации, проверяем каждые 5 минут
            echo 300
        fi
    fi
}

# Основной цикл демона
main() {
    # Проверяем не запущен ли уже
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Демон уже запущен с PID $OLD_PID"
            exit 1
        else
            log_message "Удаляем устаревший PID файл"
            rm -f "$PID_FILE"
        fi
    fi
    
    # Сохраняем PID
    echo $$ > "$PID_FILE"
    
    log_message "=== Демон Claude Nights Watch Запущен ==="
    log_message "PID: $$"
    log_message "Логи: $LOG_FILE"
    log_message "Директория задач: $TASK_DIR"
    
    
    # Проверяем наличие файла задач
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        log_message "ПРЕДУПРЕЖДЕНИЕ: Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        log_message "Пожалуйста, создайте файл task.md с вашими задачами"
    fi
    
    # Check for rules file
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        log_message "Файл правил найден по пути $TASK_DIR/$RULES_FILE"
    else
        log_message "Файл правил не найден. Рассмотрите создание $RULES_FILE для ограничений безопасности"
    fi
    
    # Check for start time
    if [ -f "$START_TIME_FILE" ]; then
        start_epoch=$(cat "$START_TIME_FILE")
        log_message "Настроено время запуска: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
    else
        log_message "Время запуска не задано - начинаем мониторинг немедленно"
    fi
    
    # Check ccusage availability
    if ! get_ccusage_cmd &> /dev/null; then
        log_message "ПРЕДУПРЕЖДЕНИЕ: ccusage не найден. Используем проверку по времени."
        log_message "Установите ccusage для более точного времени: npm install -g ccusage"
    fi
    
    # Основной цикл
    while true; do
        # Проверяем не прошло ли время запуска
        if ! is_start_time_reached; then
            time_until_start=$(get_time_until_start)
            hours=$((time_until_start / 3600))
            minutes=$(((time_until_start % 3600) / 60))
            seconds=$((time_until_start % 60))
            
            if [ "$hours" -gt 0 ]; then
                log_message "Ожидание времени запуска (осталось ${hours}ч ${minutes}м)..."
                sleep 300  # Check every 5 minutes when waiting
            elif [ "$minutes" -gt 2 ]; then
                log_message "Ожидание времени запуска (осталось ${minutes}м ${seconds}с)..."
                sleep 60   # Check every minute when close
            elif [ "$time_until_start" -gt 10 ]; then
                log_message "Ожидание времени запуска (осталось ${minutes}м ${seconds}с)..."
                sleep 10   # Check every 10 seconds when very close
            else
                log_message "Ожидание времени запуска (осталось ${seconds}с)..."
                sleep 2    # Check every 2 seconds when imminent
            fi
            continue
        fi
        
        # If we just reached start time, log it
        if [ -f "$START_TIME_FILE" ]; then
            # Check if this is the first time we're active
            if [ ! -f "${START_TIME_FILE}.activated" ]; then
                log_message "✅ Время запуска достигнуто! Начинаем мониторинг выполнения задач..."
                touch "${START_TIME_FILE}.activated"
            fi
        fi
        
        # Получаем минуты до сброса
        minutes_remaining=$(get_minutes_until_reset)
        
        # Проверяем нужно ли выполнять задачу
        should_execute=false
        
        if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
            if [ "$minutes_remaining" -le 2 ]; then
                should_execute=true
                log_message "Сброс близко ($minutes_remaining минут), готовим выполнение задачи..."
            fi
        else
            # Запасная проверка
            if [ -f "$LAST_ACTIVITY_FILE" ]; then
                last_activity=$(cat "$LAST_ACTIVITY_FILE")
                current_time=$(date +%s)
                time_diff=$((current_time - last_activity))
                
                if [ $time_diff -ge 18000 ]; then
                    should_execute=true
                    log_message "5 часов прошло с последней активности, выполняем задачу..."
                fi
            else
                # No activity recorded, safe to start
                should_execute=true
                log_message "Нет записи о предыдущей активности, запускаем начальное выполнение задачи..."
            fi
        fi
        
        # Выполняем задачу если нужно
        if [ "$should_execute" = true ]; then
            # Check if task file exists before execution
            if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
                log_message "ОШИБКА: Невозможно выполнить - файл задач не найден по пути $TASK_DIR/$TASK_FILE"
                log_message "Ожидание 5 минут перед следующей проверкой..."
                sleep 300
                continue
            fi
            
            # Немного ожидаем, чтобы убедиться, что мы в окне обновления
            sleep 60
            
            # Пытаемся выполнить задачу
            if execute_task; then
                log_message "Выполнение задачи завершено!"
                # Ожидаем 5 минут после успешного выполнения
                sleep 300
            else
                log_message "Выполнение задачи не удалось, повтор через 1 минуту"
                sleep 60
            fi
        fi
        
        # Вычисляем как долго ожидать
        sleep_duration=$(calculate_sleep_duration)
        log_message "Следующая проверка через $((sleep_duration / 60)) минут"
        
        # Ожидаем до следующей проверки
        sleep "$sleep_duration"
    done
}

# Запускаем демон
main