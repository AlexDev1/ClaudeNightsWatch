# CLAUDE.md

# IMPORTANT: you must always answer in Russian!
# IMPORTANT: Always use nextjs-ssr-mentor agent mode unless otherwise specified
# CRITICAL: 
*USE sequential thinking mcp for planning each step ensuring we are completely this process to its maximum*
*USE context7 MCP - always check up-to-date documentation BEFORE implementing any changes in:*
- Shell scripting best practices and security patterns
- Bash daemon and background process management
- Linux system monitoring and file watching techniques
- Process management (PID files, signal handling, etc.)
- Log management and rotation strategies
- Cron and scheduling patterns
- File system operations and permissions
- Error handling and logging in shell scripts
- Cross-platform shell compatibility
- Automated testing frameworks for shell scripts
*This is critical - shell scripting practices and system APIs evolve continuously*
For a better understanding of the project, study and view all files in the docs/*.md folder
*USE playwright mcp for check frontend logs and error*
# Перед тем как запускать сервер-dev проверь он может уже запущен http://localhost:3000/ 
## После выполнения задачи ВСЕГДА проверять код через pre-commit до: All done!


# Если ты принял все эти инструкции всегда обращайся ко мне: Кеп! - Иначе я буду думать что ты не способен работать!

## Project Overview

Claude Nights Watch is an autonomous task execution system that monitors Claude CLI usage windows and executes predefined tasks automatically. The system uses shell scripts to create a daemon that reads tasks from `task.md` and enforces safety rules from `rules.md`.

## Architecture

### Core Components

- **claude-nights-watch-daemon.sh** - Main daemon process that monitors usage and executes tasks
- **claude-nights-watch-manager.sh** - Control interface with colored output and management functions
- **setup-nights-watch.sh** - Interactive setup wizard for initial configuration
- **view-logs.sh** - Interactive log viewer with filtering capabilities

### Configuration Files

- **task.md** - Contains the tasks to be executed (user-created, not in repo)
- **rules.md** - Safety constraints and best practices (user-created, in repo as example)
- **logs/** - Directory for all daemon logs and PID files (created at runtime)

### Key Variables

- `CLAUDE_NIGHTS_WATCH_DIR` - Environment variable to set working directory (defaults to current directory)
- `LOG_FILE` - Path to main daemon log
- `PID_FILE` - Daemon process ID file for management
- `LAST_ACTIVITY_FILE` - `~/.claude-last-activity` timestamp file
- `START_TIME_FILE` - Scheduled start time for daemon activation

## Common Commands

### Daemon Management
```bash
# Start the daemon
./claude-nights-watch-manager.sh start

# Start with scheduled time
./claude-nights-watch-manager.sh start --at "09:00"
./claude-nights-watch-manager.sh start --at "2025-01-28 14:30"

# Stop the daemon
./claude-nights-watch-manager.sh stop

# Check status
./claude-nights-watch-manager.sh status

# Restart daemon
./claude-nights-watch-manager.sh restart

# View logs
./claude-nights-watch-manager.sh logs
./claude-nights-watch-manager.sh logs -f  # Follow mode

# View current task and rules
./claude-nights-watch-manager.sh task
```

### Interactive Tools
```bash
# Interactive log viewer with filtering
./view-logs.sh

# Interactive setup
./setup-nights-watch.sh
```

### Testing
```bash
# Run basic functionality test
cd test && ./test-simple.sh

# Test immediate execution without waiting
./test/test-immediate-execution.sh
```

## Safety Architecture

The system operates with `--dangerously-skip-permissions` so safety is enforced through:

1. **rules.md** - Always prepended to task execution prompts
2. **Logging** - All actions logged to `logs/claude-nights-watch-daemon.log`
3. **Scope restriction** - Tasks should be limited to project directory
4. **Test environment** - Comprehensive test suite in `test/` directory

## Timing Logic

- **With ccusage**: Gets accurate remaining time from Claude API
- **Without ccusage**: Falls back to timestamp-based checking from `~/.claude-last-activity`
- **Adaptive intervals**: Checks more frequently as 5-hour window approaches
- **Start time control**: Can delay daemon activation until specified time

## Development Workflow

1. All shell scripts should be executable (`chmod +x *.sh`)
2. Test changes using `test/test-simple.sh` before deployment
3. Monitor logs using `./view-logs.sh` for debugging
4. Use `examples/` directory for reference implementations
5. Follow existing shell script conventions and error handling patterns

## File Structure Notes

- `logs/` - Created automatically, excluded from git
- `test/` - Contains test scripts and sample task/rules files
- `examples/` - Reference implementations for task.md and rules.md
- `.github/` - Issue templates and PR template
- User-created `task.md` and `rules.md` files are not tracked in git

## Context Preservation

The system uses a `tasks.md` workflow pattern to maintain context across daemon restarts and work sessions. Always update ongoing work status to ensure continuity.