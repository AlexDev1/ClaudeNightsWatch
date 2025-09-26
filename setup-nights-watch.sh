#!/bin/bash

# Скрипт Настройки Claude Nights Watch
# Интерактивная настройка для автономного выполнения задач

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MANAGER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/claude-nights-watch-manager.sh"
TASK_FILE="task.md"
RULES_FILE="rules.md"

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Настройка Claude Nights Watch${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

check_claude() {
    if command -v claude &> /dev/null; then
        print_success "Claude CLI найден"
        return 0
    else
        print_error "Claude CLI не найден"
        echo "Пожалуйста, сначала установите Claude CLI: https://docs.anthropic.com/en/docs/claude-code/quickstart"
        return 1
    fi
}

check_ccusage() {
    if command -v ccusage &> /dev/null || command -v bunx &> /dev/null || command -v npx &> /dev/null; then
        print_success "ccusage доступен (для точного хронометража)"
        return 0
    else
        print_warning "ccusage не найден (будем использовать проверку по времени)"
        echo "Для установки ccusage: npm install -g ccusage"
        return 0  # Not a fatal error
    fi
}

create_task_file() {
    if [ -f "$TASK_FILE" ]; then
        print_warning "task.md уже существует"
        read -p "Хотите посмотреть/отредактировать его? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$TASK_FILE"
        fi
    else
        echo ""
        echo "Создание файла task.md..."
        echo "Введите вашу задачу (нажмите Ctrl+D когда завершите):"
        echo ""
        cat > "$TASK_FILE"
        print_success "Создан task.md"
    fi
}

create_rules_file() {
    if [ -f "$RULES_FILE" ]; then
        print_warning "rules.md уже существует"
        read -p "Хотите посмотреть/отредактировать его? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} "$RULES_FILE"
        fi
    else
        echo ""
        read -p "Хотите создать правила безопасности? (рекомендуется) (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat > "$RULES_FILE" << 'EOF'
# Safety Rules for Claude Nights Watch

## CRITICAL RULES - NEVER VIOLATE THESE:

1. **NO DESTRUCTIVE COMMANDS**: Never run commands that could delete or damage files:
   - No `rm -rf` commands
   - No deletion of system files
   - No modifications to system configurations

2. **NO SENSITIVE DATA**: Never:
   - Access or expose passwords, API keys, or secrets
   - Commit sensitive information to repositories
   - Log sensitive data

3. **NO NETWORK ATTACKS**: Never perform:
   - Port scanning
   - DDoS attempts
   - Unauthorized access attempts

4. **STAY IN PROJECT SCOPE**: 
   - Only work within the designated project directory
   - Do not access or modify files outside the project

5. **GIT SAFETY**:
   - Never force push to main/master branches
   - Always create feature branches for changes
   - Never rewrite published history

## BEST PRACTICES:

1. **TEST BEFORE PRODUCTION**: Always test changes in a safe environment
2. **BACKUP IMPORTANT DATA**: Create backups before major changes
3. **DOCUMENT CHANGES**: Keep clear records of what was modified
4. **RESPECT RATE LIMITS**: Don't overwhelm external services
5. **ERROR HANDLING**: Implement proper error handling and logging

## ALLOWED ACTIONS:

- Create and modify project files
- Run tests and builds
- Create git commits on feature branches
- Install project dependencies
- Generate documentation
- Refactor code
- Fix bugs
- Add new features as specified
EOF
            print_success "Создан rules.md с правилами безопасности по умолчанию"
            echo ""
            read -p "Хотите отредактировать правила? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} "$RULES_FILE"
            fi
        fi
    fi
}

setup_daemon() {
    echo ""
    echo "=== Конфигурация Демона ==="
    echo ""
    
    read -p "Хотите запустить демон после настройки? (y/n) " -n 1 -r
    echo
    START_NOW=$REPLY
    
    if [[ $START_NOW =~ ^[Yy]$ ]]; then
        read -p "Хотите назначить время запуска? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Введите время запуска (HH:MM для сегодня, или YYYY-MM-DD HH:MM):"
            read START_TIME
            START_ARGS="--at $START_TIME"
        else
            START_ARGS=""
        fi
    fi
}

main() {
    print_header
    
    # Проверяем предварительные условия
    echo "Проверка предварительных условий..."
    check_claude || exit 1
    check_ccusage
    echo ""
    
    # Создаём/редактируем файл задач
    echo "=== Конфигурация Задач ==="
    create_task_file
    echo ""
    
    # Создаём/редактируем файл правил
    echo "=== Конфигурация Правил Безопасности ==="
    create_rules_file
    echo ""
    
    # Настраиваем демон
    setup_daemon
    
    # Сводка
    echo ""
    echo "=== Настройка Завершена ==="
    print_success "Файл задач: $(pwd)/$TASK_FILE"
    if [ -f "$RULES_FILE" ]; then
        print_success "Файл правил: $(pwd)/$RULES_FILE"
    fi
    print_success "Менеджер: $MANAGER_SCRIPT"
    echo ""
    
    # Показываем доступные команды
    echo "Доступные команды:"
    echo "  ./claude-nights-watch-manager.sh start    - Запустить демон"
    echo "  ./claude-nights-watch-manager.sh stop     - Остановить демон"
    echo "  ./claude-nights-watch-manager.sh status   - Проверить статус демона"
    echo "  ./claude-nights-watch-manager.sh logs     - Посмотреть логи"
    echo "  ./claude-nights-watch-manager.sh task     - Посмотреть текущую задачу"
    echo ""
    
    # Запускаем демон если запрошено
    if [[ $START_NOW =~ ^[Yy]$ ]]; then
        echo "Запуск демона..."
        "$MANAGER_SCRIPT" start $START_ARGS
    else
        echo "Чтобы запустить демон позже, выполните:"
        echo "  ./claude-nights-watch-manager.sh start"
    fi
    
    echo ""
    print_warning "Помните: Демон будет выполнять задачи автономно!"
    print_warning "Всегда внимательно проверяйте ваши файлы task.md и rules.md."
}

# Запускаем основную функцию
main