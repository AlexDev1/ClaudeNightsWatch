#!/bin/bash

# Простой тест для проверки базовой функциональности

echo "=== Простой Тест Claude Nights Watch ==="
echo ""

# Устанавливаем пути
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export CLAUDE_NIGHTS_WATCH_DIR="$(dirname "$SCRIPT_DIR")"
TASK_FILE="test-task-simple.md"
RULES_FILE="test-rules-simple.md"

# Временно используем тестовые файлы
cd "$CLAUDE_NIGHTS_WATCH_DIR"
mv task.md task.md.bak 2>/dev/null || true
mv rules.md rules.md.bak 2>/dev/null || true
cp test/$TASK_FILE task.md
cp test/$RULES_FILE rules.md

echo "Тестовые файлы подготовлены:"
echo "- Задача: test-task-simple.md"
echo "- Правила: test-rules-simple.md"
echo ""

# Запускаем тест
echo "Запуск тестового выполнения..."
./test/test-immediate-execution.sh

# Восстанавливаем оригинальные файлы
mv task.md.bak task.md 2>/dev/null || true
mv rules.md.bak rules.md 2>/dev/null || true

echo ""
echo "=== Тест Завершён ==="
echo "Проверьте файл логов: $CLAUDE_NIGHTS_WATCH_DIR/logs/claude-nights-watch-test.log"
echo "Проверьте был ли создан test-output.txt"