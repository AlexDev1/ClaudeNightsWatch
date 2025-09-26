#!/bin/bash

# Тестовый скрипт для немедленного выполнения задачи без ожидания окна обновления

LOG_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}/logs/claude-nights-watch-test.log"
TASK_FILE="${TASK_FILE:-task.md}"
RULES_FILE="${RULES_FILE:-rules.md}"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"

# Убеждаемся что директория логов существует
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Функция для логирования сообщений
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
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
        log_message "ОШИБКА: Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        return 1
    fi
    
    echo -e "$prompt"
}

# Основное выполнение
main() {
    log_message "=== Начало Тестового Выполнения Claude Nights Watch ==="
    log_message "Директория задач: $TASK_DIR"
    log_message "Файл логов: $LOG_FILE"
    
    # Check if task file exists
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        log_message "ОШИБКА: Файл задач не найден по пути $TASK_DIR/$TASK_FILE"
        exit 1
    fi
    
    # Check if rules file exists
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        log_message "Rules file found at $TASK_DIR/$RULES_FILE"
    else
        log_message "No rules file found. Consider creating $RULES_FILE for safety constraints"
    fi
    
    # Prepare the full prompt with rules and task
    log_message "Preparing task prompt..."
    local full_prompt=$(prepare_task_prompt)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    log_message "Task prompt prepared ($(echo -e "$full_prompt" | wc -l) lines)"
    
    # Show what will be sent to Claude
    echo ""
    echo "=== PROMPT PREVIEW ==="
    echo -e "$full_prompt" | head -20
    echo "..."
    echo "=== END PREVIEW ==="
    echo ""
    
    read -p "Execute this task with Claude? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_message "Execution cancelled by user"
        exit 0
    fi
    
    log_message "Executing task with Claude (autonomous mode)..."
    
    # Log the full prompt being sent
    echo "" >> "$LOG_FILE"
    echo "=== PROMPT SENT TO CLAUDE ===" >> "$LOG_FILE"
    echo -e "$full_prompt" >> "$LOG_FILE"
    echo "=== END OF PROMPT ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Execute task with Claude and log everything
    log_message "=== CLAUDE RESPONSE START ==="
    echo -e "$full_prompt" | claude --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"
    local result=${PIPESTATUS[0]}
    log_message "=== CLAUDE RESPONSE END ==="
    
    if [ $result -eq 0 ]; then
        log_message "Task execution completed successfully"
    else
        log_message "ERROR: Task execution failed with code $result"
    fi
    
    log_message "=== Test Execution Completed ==="
    echo ""
    echo "Full log saved to: $LOG_FILE"
}

# Run main function
main