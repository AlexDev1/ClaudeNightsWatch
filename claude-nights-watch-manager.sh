#!/bin/bash

# Менеджер Claude Nights Watch - Запуск, остановка и управление демоном выполнения задач

DAEMON_SCRIPT="$(cd "$(dirname "$0")" && pwd)/claude-nights-watch-daemon.sh"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"
PID_FILE="$TASK_DIR/logs/claude-nights-watch-daemon.pid"
LOG_FILE="$TASK_DIR/logs/claude-nights-watch-daemon.log"
START_TIME_FILE="$TASK_DIR/logs/claude-nights-watch-start-time"
TASK_FILE="task.md"
RULES_FILE="rules.md"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_task() {
    echo -e "${BLUE}[TASK]${NC} $1"
}

start_daemon() {
    # Обрабатываем параметр --at если предоставлен
    START_TIME=""
    if [ "$2" = "--at" ] && [ -n "$3" ]; then
        START_TIME="$3"
        
        # Проверяем и преобразуем время запуска в epoch
        if [[ "$START_TIME" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            # Формат: "HH:MM" - предполагаем сегодня
            START_TIME="$(date '+%Y-%m-%d') $START_TIME:00"
        fi
        
        # Преобразуем в метку времени epoch
        START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" +%s 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            print_error "Неверный формат времени. Используйте 'HH:MM' или 'YYYY-MM-DD HH:MM'"
            return 1
        fi
        
        # Сохраняем время запуска
        echo "$START_EPOCH" > "$START_TIME_FILE"
        print_status "Демон начнёт мониторинг в: $(date -d "@$START_EPOCH" 2>/dev/null || date -r "$START_EPOCH")"
    else
        # Удаляем любое существующее время запуска (запуск немедленно)
        rm -f "$START_TIME_FILE" 2>/dev/null
    fi
    
    # Проверяем существование файла задач
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        print_warning "Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        print_warning "Пожалуйста, создайте файл task.md с вашими задачами перед запуском демона"
        read -p "Хотите продолжить в любом случае? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            print_error "Демон уже запущен с PID $PID"
            return 1
        fi
    fi
    
    print_status "Запуск демона Claude Nights Watch..."
    print_status "Директория задач: $TASK_DIR"
    
    # Экспортируем директорию задач для демона
    export CLAUDE_NIGHTS_WATCH_DIR="$TASK_DIR"
    nohup "$DAEMON_SCRIPT" > /dev/null 2>&1 &
    
    # Ожидаем запуска демона с логикой повторов
    for i in {1..5}; do
        sleep 1
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                print_status "Демон успешно запущен с PID $PID"
                
                if [ -f "$START_TIME_FILE" ]; then
                    START_EPOCH=$(cat "$START_TIME_FILE")
                    print_status "Начало выполнения задач в: $(date -d "@$START_EPOCH" 2>/dev/null || date -r "$START_EPOCH")"
                fi
                print_status "Логи: $LOG_FILE"
                
                # Показываем предпросмотр задач
                if [ -f "$TASK_DIR/$TASK_FILE" ]; then
                    echo ""
                    print_task "Предпросмотр задач (первые 5 строк):"
                    head -5 "$TASK_DIR/$TASK_FILE" | sed 's/^/  /'
                    echo "  ..."
                fi
                
                return 0
            fi
        fi
        if [ $i -eq 5 ]; then
            print_error "Не удалось запустить демон"
            return 1
        fi
    done
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        print_warning "Демон не запущен (файл PID не найден)"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if ! kill -0 "$PID" 2>/dev/null; then
        print_warning "Демон не запущен (процесс $PID не найден)"
        rm -f "$PID_FILE"
        return 1
    fi
    
    print_status "Остановка демона с PID $PID..."
    kill "$PID"
    
    # Ожидаем корректного завершения
    for i in {1..10}; do
        if ! kill -0 "$PID" 2>/dev/null; then
            print_status "Демон успешно остановлен"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    # Принудительное завершение если всё ещё работает
    print_warning "Демон не остановился корректно, принуждаем..."
    kill -9 "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    print_status "Демон остановлен"
}

status_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        print_status "Демон не запущен"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if kill -0 "$PID" 2>/dev/null; then
        print_status "Демон запущен с PID $PID"
        
        # Проверяем статус времени запуска
        if [ -f "$START_TIME_FILE" ]; then
            start_epoch=$(cat "$START_TIME_FILE")
            current_epoch=$(date +%s)
            
            if [ "$current_epoch" -ge "$start_epoch" ]; then
                print_status "Статус: ✅ АКТИВЕН - Мониторинг выполнения задач включён"
            else
                time_until_start=$((start_epoch - current_epoch))
                hours=$((time_until_start / 3600))
                minutes=$(((time_until_start % 3600) / 60))
                print_status "Статус: ⏰ ОЖИДАНИЕ - Активация через ${hours}ч ${minutes}м"
                print_status "Время запуска: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
            fi
        else
            print_status "Status: ✅ ACTIVE - Task execution monitoring enabled"
        fi
        
        # Показываем статус задач
        echo ""
        if [ -f "$TASK_DIR/$TASK_FILE" ]; then
            print_task "Файл задач: $TASK_DIR/$TASK_FILE ($(wc -l < "$TASK_DIR/$TASK_FILE") строк)"
        else
            print_warning "Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        fi
        
        if [ -f "$TASK_DIR/$RULES_FILE" ]; then
            print_task "Файл правил: $TASK_DIR/$RULES_FILE ($(wc -l < "$TASK_DIR/$RULES_FILE") строк)"
        else
            print_status "Нет файла правил (рассмотрите создание $RULES_FILE для безопасности)"
        fi
        
        # Показываем последнюю активность
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_status "Последняя активность:"
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        fi
        
        # Показываем оценку следующего выполнения (только если активен)
        if [ ! -f "$START_TIME_FILE" ] || [ "$current_epoch" -ge "$(cat "$START_TIME_FILE" 2>/dev/null || echo 0)" ]; then
            if [ -f "$HOME/.claude-last-activity" ]; then
                last_activity=$(cat "$HOME/.claude-last-activity")
                current_time=$(date +%s)
                time_diff=$((current_time - last_activity))
                remaining=$((18000 - time_diff))
                
                if [ $remaining -gt 0 ]; then
                    hours=$((remaining / 3600))
                    minutes=$(((remaining % 3600) / 60))
                    echo ""
                    print_status "Приблизительное время до следующего выполнения задачи: ${hours}ч ${minutes}м"
                fi
            fi
        fi
        
        return 0
    else
        print_warning "Демон не запущен (процесс $PID не найден)"
        rm -f "$PID_FILE"
        return 1
    fi
}

restart_daemon() {
    print_status "Перезапуск демона..."
    stop_daemon
    sleep 2
    start_daemon "$@"
}

show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        print_error "Файл логов не найден"
        return 1
    fi
    
    if [ "$1" = "-f" ]; then
        tail -f "$LOG_FILE"
    else
        tail -50 "$LOG_FILE"
    fi
}

show_task() {
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        print_error "Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        return 1
    fi
    
    echo ""
    print_task "Текущая задача ($TASK_DIR/$TASK_FILE):"
    echo "============================================"
    cat "$TASK_DIR/$TASK_FILE"
    echo "============================================"
    
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        echo ""
        print_task "Текущие правила ($TASK_DIR/$RULES_FILE):"
        echo "============================================"
        cat "$TASK_DIR/$RULES_FILE"
        echo "============================================"
    fi
}

# Обработка основных команд
case "$1" in
    start)
        start_daemon "$@"
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 2
        start_daemon "$@"
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs "$2"
        ;;
    task)
        show_task
        ;;
    *)
        echo "Claude Nights Watch - Демон Автономного Выполнения Задач"
        echo ""
        echo "Использование: $0 {start|stop|restart|status|logs|task} [опции]"
        echo ""
        echo "Команды:"
        echo "  start           - Запустить демон"
        echo "  start --at TIME - Запустить демон, но начать мониторинг в указанное время"
        echo "                    Примеры: --at '09:00' или --at '2025-01-28 14:30'"
        echo "  stop            - Остановить демон"
        echo "  restart         - Перезапустить демон"
        echo "  status          - Показать статус демона"
        echo "  logs            - Показать последние логи (используйте 'logs -f' для отслеживания)"
        echo "  task            - Показать текущую задачу и правила"
        echo ""
        echo "Демон будет:"
        echo "  - Мониторить ваши блоки использования Claude"
        echo "  - Выполнять задачи из task.md когда нужно обновление"
        echo "  - Применять правила из rules.md для безопасного автономного выполнения"
        echo "  - Предотвращать пробелы в ваших 5-часовых окнах использования"
        echo ""
        echo "Окружение:"
        echo "  CLAUDE_NIGHTS_WATCH_DIR - Установить директорию задач (по умолчанию: текущая директория)"
        ;;
esac