# Claude Nights Watch 🌙

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Language-Shell-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub stars](https://img.shields.io/github/stars/aniketkarne/ClaudeNightsWatch.svg?style=social&label=Star)](https://github.com/aniketkarne/ClaudeNightsWatch)

Система автономного выполнения задач для Claude CLI, которая мониторит ваши окна использования и автоматически выполняет предопределённые задачи. Построена на основе концепции claude-auto-renew, но вместо простых обновлений выполняет сложные задачи из файла task.md.

**⚠️ Предупреждение**: Этот инструмент использует `--dangerously-skip-permissions` для автономного выполнения. Используйте осторожно!

## 🎯 Обзор

Claude Nights Watch расширяет концепцию автоматического обновления для создания полностью автономной системы выполнения задач. Когда окно использования Claude подходит к концу, вместо простого "привет", система читает файл `task.md` и автономно выполняет определённые задачи.

### Ключевые возможности

- 🤖 **Автономное Выполнение**: Запускает задачи без ручного вмешательства
- 📋 **Рабочий Процесс на Основе Задач**: Определяйте задачи в простом markdown файле
- 🛡️ **Правила Безопасности**: Настройте ограничения безопасности в `rules.md`
- ⏰ **Умное Время**: Использует ccusage для точного хронометража или откат к проверке по времени
- 📅 **Запланированный Запуск**: Может быть настроен для запуска в определённое время
- 📊 **Комплексное Логирование**: Отслеживание всех действий и выполнений
- 🔄 **На Основе Проверенного Кода**: Построен на надёжном демоне claude-auto-renew

## 🚀 Быстрый Старт

### Предварительные условия

1. [Claude CLI](https://docs.anthropic.com/en/docs/claude-code/quickstart) установлен и настроен
2. (Опционально) [ccusage](https://www.npmjs.com/package/ccusage) для точного хронометража:
   ```bash
   npm install -g ccusage
   ```

### Установка

1. Клонируйте этот репозиторий:
   ```bash
   git clone https://github.com/aniketkarne/ClaudeNightsWatch.git
   cd ClaudeNightsWatch
   ```

2. Сделайте скрипты исполняемыми:
   ```bash
   chmod +x *.sh
   ```

3. Запустите интерактивную настройку:
   ```bash
   ./setup-nights-watch.sh
   ```

### Базовое использование

1. **Создайте файл задач** (`task.md`):
   ```markdown
   # Ежедневные Задачи Разработки

   1. Запустить линтинг всех исходных файлов
   2. Обновить зависимости до последних версий
   3. Запустить набор тестов
   4. Сгенерировать отчёт о покрытии
   5. Создать сводку изменений
   ```

2. **Создайте правила безопасности** (`rules.md`):
   ```markdown
   # Правила Безопасности

   - Никогда не удаляйте файлы без резервных копий
   - Работайте только в пределах директории проекта
   - Всегда создавайте функциональные ветки для изменений
   - Никогда не коммитьте конфиденциальную информацию
   ```

3. **Запустите демон**:
   ```bash
   ./claude-nights-watch-manager.sh start
   ```

## 📝 Конфигурация

### Файл Задач (task.md)

Файл задач содержит инструкции, которые Claude будет выполнять. Он должен быть ясным, конкретным и хорошо структурированным. Смотрите `examples/task.example.md` для подробного примера.

### Файл Правил (rules.md)

Файл правил определяет ограничения безопасности и лучшие практики. Он добавляется к каждому выполнению задачи для обеспечения безопасной автономной работы. Смотрите `examples/rules.example.md` для рекомендованных правил.

### Переменные Окружения

- `CLAUDE_NIGHTS_WATCH_DIR`: Установите директорию содержащую task.md и rules.md (по умолчанию: текущая директория)

## 🎮 Команды

### Команды Менеджера

```bash
# Запустить демон
./claude-nights-watch-manager.sh start

# Запустить с запланированным временем
./claude-nights-watch-manager.sh start --at "09:00"
./claude-nights-watch-manager.sh start --at "2025-01-28 14:30"

# Остановить демон
./claude-nights-watch-manager.sh stop

# Проверить статус
./claude-nights-watch-manager.sh status

# Просмотреть логи
./claude-nights-watch-manager.sh logs
./claude-nights-watch-manager.sh logs -f  # Режим отслеживания

# Использовать интерактивный просмотрщик логов
./view-logs.sh

# Просмотреть текущую задачу и правила
./claude-nights-watch-manager.sh task

# Перезапустить демон
./claude-nights-watch-manager.sh restart
```

## 🔧 Как Это Работает

1. **Мониторинг**: Демон непрерывно отслеживает ваши окна использования Claude
2. **Хронометраж**: При приближении к 5-часовому лимиту (в пределах 2 минут), готовится к выполнению
3. **Подготовка Задач**: Читает `rules.md` и `task.md`, объединяя их в один промпт
4. **Автономное Выполнение**: Выполняет задачу используя `claude --dangerously-skip-permissions`
5. **Логирование**: Все действия логируются в `logs/claude-nights-watch-daemon.log`

### Логика Хронометража

- **С ccusage**: Получает точное оставшееся время из API
- **Без ccusage**: Откат к проверке на основе временных меток
- **Адаптивные интервалы**:
  - \>30 минут осталось: Проверка каждые 10 минут
  - 5-30 минут осталось: Проверка каждые 2 минуты
  - <5 минут осталось: Проверка каждые 30 секунд

### 📌 Сохранение Контекста с помощью `tasks.md`

To make sure progress is not lost (especially when the daemon is restarted or after long breaks like sleeping), it’s recommended to **track and update your ongoing work inside a `tasks.md` file**. This file acts as the single source of truth for what has been done and what remains.

#### Workflow
1. **During Conversations / Work Sessions**  
   - After completing any significant task, **always update `tasks.md`** with:  
     - A short description of what was done.  
     - Any pending follow-up actions.  
     - Notes that will help resume work later.  

   Example entry in `tasks.md`:
   ```markdown
   - [x] Implemented daemon restart logic
   - [ ] Test the auto-renewal workflow with edge cases
   - Notes: Pending tests involve certificate expiry < 1 day.

2. **When Starting the Daemon (CCAutoRenew / NightsWatch)**

   * On startup, the daemon (or you, if running manually) should **refer back to `tasks.md`** to regain context.
   * Instead of starting from scratch, the system should **continue with `tasks.md`**, ensuring a smooth handover from the last session.


#### Why This Helps

* Prevents forgetting half-completed work.
* Makes it easy to **resume exactly where you left off**, even after long breaks.
* Provides a lightweight, version-controlled history of your progress.

## ⚠️ Соображения Безопасности

**ВАЖНО**: Этот инструмент запускает Claude с флагом `--dangerously-skip-permissions`, что означает выполнение задач без запроса подтверждения.

### Лучшие Практики:

1. **Всегда сначала тестируйте задачи вручную** перед настройкой автономного выполнения
2. **Используйте комплексный rules.md** для предотвращения разрушительных действий
3. **Начинайте с простых, безопасных задач** и постепенно увеличивайте сложность
4. **Регулярно отслеживайте логи** для обеспечения правильного выполнения
5. **Ведите резервные копии** важных данных
6. **Запускайте в изолированных средах** когда возможно
7. **Сохраняйте Контекст** с помощью tasks.md


### Рекомендованные Ограничения:

- Ограничьте доступ к файловой системе директориями проекта
- Запретите команды удаления
- Предотвратите изменения системы
- Ограничьте сетевой доступ
- Установите лимиты ресурсов

## 📁 Структура Файлов

```
claude-nights-watch/
├── claude-nights-watch-daemon.sh      # Основной процесс демона
├── claude-nights-watch-manager.sh     # Интерфейс управления демоном
├── setup-nights-watch.sh              # Интерактивный скрипт настройки
├── view-logs.sh                       # Интерактивный просмотрщик логов
├── README.md                          # Этот файл
├── LICENSE                            # MIT Лицензия
├── CONTRIBUTING.md                    # Руководство по вкладу
├── CHANGELOG.md                       # История версий
├── SUMMARY.md                         # Сводка проекта
├── .gitignore                         # Файл исключений Git
├── .github/                           # Шаблоны GitHub
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
├── logs/                              # Все логи хранятся здесь (создаётся при первом запуске)
├── examples/                          # Примеры файлов
│   ├── task.example.md                # Пример файла задач
│   └── rules.example.md               # Пример файла правил
└── test/                              # Тестовые скрипты и файлы
    ├── README.md                      # Документация по тестированию
    ├── test-immediate-execution.sh    # Тест прямого выполнения задач
    ├── test-simple.sh                 # Тест простой функциональности
    ├── test-task-simple.md            # Простая тестовая задача
    └── test-rules-simple.md           # Простые тестовые правила
```

## 📊 Логирование

Все логи хранятся в директории `logs/` внутри проекта. Каждый лог содержит:

- **Временные Метки**: Каждое действие помечается временем
- **Полные Промпты**: Полный промпт отправленный Claude (правила + задача)
- **Полные Ответы**: Всё что выводит Claude
- **Сообщения Статуса**: Индикаторы успеха/неудачи

### Просмотр Логов

Используйте интерактивный просмотрщик логов:
```bash
./view-logs.sh
```

Возможности:
- Просмотр всех файлов логов
- Просмотр полных логов или последних 50 строк
- Фильтрация для просмотра только промптов отправленных Claude
- Фильтрация для просмотра только ответов Claude
- Поиск ошибок
- Отслеживание логов в реальном времени

## 🧪 Тестирование

Тестовые скрипты доступны в директории `test/`:

```bash
cd test
./test-simple.sh  # Запустить простой тест
```

Смотрите `test/README.md` для подробных инструкций по тестированию.

## 🐛 Устранение Неполадок

### Демон не запускается
- Проверьте установлен ли Claude CLI: `which claude`
- Убедитесь что task.md существует в рабочей директории
- Проверьте логи: `./claude-nights-watch-manager.sh logs`

### Задачи не выполняются
- Убедитесь что у вас есть оставшееся использование Claude: `ccusage blocks`
- Проверьте не прошло ли запланированное время запуска
- Убедитесь что task.md не пуст
- Просмотрите логи на наличие ошибок

### Проблемы с хронометражем
- Установите ccusage для лучшей точности: `npm install -g ccusage`
- Проверьте правильность системного времени
- Проверьте временную метку `.claude-last-activity`

## 🤝 Вклад в Проект

Вклады приветствуются! Пожалуйста следуйте этим шагам:

1. **Форкните репозиторий** на GitHub
2. **Клонируйте ваш форк** локально
3. **Создайте функциональную ветку** (`git checkout -b feature/amazing-feature`)
4. **Внесите изменения** следуя нашим рекомендациям
5. **Тщательно тестируйте** используя набор тестов
6. **Закоммитьте ваши изменения** (`git commit -m 'Add amazing feature'`)
7. **Загрузите в ваш форк** (`git push origin feature/amazing-feature`)
8. **Создайте Pull Request** на GitHub

Пожалуйста убедитесь:
- Код следует существующему стилю
- Безопасность приоритизируется
- Документация обновлена
- Примеры предоставлены
- Тесты проходят

## История Звёзд
[![Star History Chart](https://api.star-history.com/svg?repos=aniketkarne/ClaudeNightsWatch&type=Date)](https://www.star-history.com/#aniketkarne/ClaudeNightsWatch&Date)



## Смотрите [CONTRIBUTING.md](CONTRIBUTING.md) для подробных рекомендаций.

## 📄 Лицензия

Этот проект лицензируется под лицензией MIT - смотрите файл [LICENSE](LICENSE) для подробностей.

## 🙏 Благодарности

- **Создано**: [Aniket Karne](https://github.com/aniketkarne)
- **Построено на основе**: Отличного проекта [CCAutoRenew](https://github.com/aniketkarne/CCAutoRenew)
- **Благодарность**: Команде Claude CLI за замечательный инструмент

---

**Помните**: С великой автоматизацией приходит великая ответственность. Всегда внимательно проверяйте ваши задачи и правила перед включением автономного выполнения! 🚨
