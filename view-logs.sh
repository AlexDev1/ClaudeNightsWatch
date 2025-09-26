#!/bin/bash

# Просмотрщик Логов Claude Nights Watch

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"
LOG_DIR="$TASK_DIR/logs"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

show_menu() {
    echo -e "${BLUE}=== Логи Claude Nights Watch ===${NC}"
    echo ""
    echo "Доступные файлы логов:"
    echo ""
    
    if [ -d "$LOG_DIR" ]; then
        local i=1
        for log in "$LOG_DIR"/*.log; do
            if [ -f "$log" ]; then
                local basename=$(basename "$log")
                local size=$(du -h "$log" | cut -f1)
                local lines=$(wc -l < "$log")
                echo "  $i) $basename (${size}, ${lines} строк)"
                ((i++))
            fi
        done
    else
        echo "  Логи не найдены в $LOG_DIR"
        exit 1
    fi
    
    echo ""
    echo "Опции:"
    echo "  f) Отслеживать последний лог (tail -f)"
    echo "  a) Показать все логи объединённые"
    echo "  p) Показать только промпты, отправленные Claude"
    echo "  r) Показать только ответы Claude"
    echo "  e) Показать только ошибки"
    echo "  q) Выход"
    echo ""
}

view_log() {
    local log_file="$1"
    local mode="$2"
    
    case "$mode" in
        "full")
            less "$log_file"
            ;;
        "tail")
            tail -50 "$log_file"
            ;;
        "follow")
            tail -f "$log_file"
            ;;
        "prompts")
            awk '/=== PROMPT SENT TO CLAUDE ===/,/=== END OF PROMPT ===/' "$log_file" | less
            ;;
        "responses")
            awk '/=== CLAUDE RESPONSE START ===/,/=== CLAUDE RESPONSE END ===/' "$log_file" | less
            ;;
        "errors")
            grep -E "(ERROR|FAILED|Failed)" "$log_file" | less
            ;;
    esac
}

# Основной цикл
while true; do
    clear
    show_menu
    
    read -p "Выберите опцию: " choice
    
    case "$choice" in
        [0-9]*)
            # Числовой выбор - посмотреть конкретный лог
            log_files=("$LOG_DIR"/*.log)
            selected_log="${log_files[$((choice-1))]}"
            if [ -f "$selected_log" ]; then
                echo ""
                echo "1) Посмотреть полный лог"
                echo "2) Посмотреть последние 50 строк"
                echo "3) Посмотреть только промпты"
                echo "4) Посмотреть только ответы"
                echo "5) Посмотреть только ошибки"
                read -p "Выберите режим просмотра: " view_mode
                
                case "$view_mode" in
                    1) view_log "$selected_log" "full" ;;
                    2) view_log "$selected_log" "tail" ;;
                    3) view_log "$selected_log" "prompts" ;;
                    4) view_log "$selected_log" "responses" ;;
                    5) view_log "$selected_log" "errors" ;;
                esac
            fi
            ;;
        f|F)
            # Отслеживаем последний лог
            latest_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
            if [ -f "$latest_log" ]; then
                echo "Отслеживание $(basename "$latest_log")... (Ctrl+C для остановки)"
                view_log "$latest_log" "follow"
            fi
            ;;
        a|A)
            # Показываем все логи
            cat "$LOG_DIR"/*.log | less
            ;;
        p|P)
            # Показываем все промпты
            cat "$LOG_DIR"/*.log | awk '/=== PROMPT SENT TO CLAUDE ===/,/=== END OF PROMPT ===/' | less
            ;;
        r|R)
            # Показываем все ответы
            cat "$LOG_DIR"/*.log | awk '/=== CLAUDE RESPONSE START ===/,/=== CLAUDE RESPONSE END ===/' | less
            ;;
        e|E)
            # Показываем все ошибки
            grep -h -E "(ERROR|FAILED|Failed)" "$LOG_DIR"/*.log | less
            ;;
        q|Q)
            echo "До свидания!"
            exit 0
            ;;
    esac
    
    echo ""
    read -p "Нажмите Enter для продолжения..."
done