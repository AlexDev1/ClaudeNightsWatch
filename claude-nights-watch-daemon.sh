#!/bin/bash

# Claude Nights Watch Daemon - Autonomous Task Execution
# Based on claude-auto-renew-daemon but executes tasks instead of simple renewals

LOG_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-daemon.log"
PID_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-daemon.pid"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
START_TIME_FILE="${CLAUDE_NIGHTS_WATCH_DIR:-$(dirname "$0")}/logs/claude-nights-watch-start-time"
TASK_FILE="task.md"
RULES_FILE="rules.md"
TASK_DIR="${CLAUDE_NIGHTS_WATCH_DIR:-$(pwd)}"

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to handle shutdown
cleanup() {
    log_message "Daemon shutting down..."
    rm -f "$PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Function to check if we're past the start time
is_start_time_reached() {
    if [ ! -f "$START_TIME_FILE" ]; then
        # No start time set, always active
        return 0
    fi
    
    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    
    if [ "$current_epoch" -ge "$start_epoch" ]; then
        return 0  # Start time reached
    else
        return 1  # Still waiting
    fi
}

# Function to get time until start
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

# Function to get ccusage command
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

# Function to get minutes until reset
get_minutes_until_reset() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Try to get time remaining from ccusage
    local output=$($ccusage_cmd blocks 2>/dev/null | grep -i "time remaining" | head -1)
    
    if [ -z "$output" ]; then
        output=$($ccusage_cmd blocks --live 2>/dev/null | grep -i "remaining" | head -1)
    fi
    
    # Parse time
    local hours=0
    local minutes=0
    
    if [[ "$output" =~ ([0-9]+)h[[:space:]]*([0-9]+)m ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=${BASH_REMATCH[2]}
    elif [[ "$output" =~ ([0-9]+)m ]]; then
        minutes=${BASH_REMATCH[1]}
    fi
    
    echo $((hours * 60 + minutes))
}

# Function to prepare task with rules
prepare_task_prompt() {
    local prompt=""
    
    # Add rules if they exist
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        prompt="IMPORTANT RULES TO FOLLOW:\n\n"
        prompt+=$(cat "$TASK_DIR/$RULES_FILE")
        prompt+="\n\n---END OF RULES---\n\n"
        log_message "Applied rules from $RULES_FILE"
    fi
    
    # Add task content
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

# Function to execute task
execute_task() {
    log_message "Starting task execution from $TASK_FILE..."
    
    if ! command -v claude &> /dev/null; then
        log_message "ERROR: claude command not found"
        return 1
    fi
    
    # Check if task file exists
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        log_message "ERROR: Task file not found at $TASK_DIR/$TASK_FILE"
        return 1
    fi
    
    # Prepare the full prompt with rules and task
    local full_prompt=$(prepare_task_prompt)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_message "Executing task with Claude (autonomous mode)..."
    
    # Log the full prompt being sent
    echo "" >> "$LOG_FILE"
    echo "=== PROMPT SENT TO CLAUDE ===" >> "$LOG_FILE"
    echo -e "$full_prompt" >> "$LOG_FILE"
    echo "=== END OF PROMPT ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Execute task with Claude in autonomous mode
    # Log everything - both the execution and the response
    log_message "=== CLAUDE RESPONSE START ==="
    (echo -e "$full_prompt" | claude --dangerously-skip-permissions 2>&1) | tee -a "$LOG_FILE" &
    local pid=$!
    
    # Monitor execution (no timeout for complex tasks)
    log_message "Task execution started (PID: $pid)"
    
    # Wait for completion
    wait $pid
    local result=$?
    
    log_message "=== CLAUDE RESPONSE END ==="
    
    if [ $result -eq 0 ]; then
        log_message "Task execution completed successfully"
        date +%s > "$LAST_ACTIVITY_FILE"
        return 0
    else
        log_message "ERROR: Task execution failed with code $result"
        return 1
    fi
}

# Function to calculate next check time
calculate_sleep_duration() {
    local minutes_remaining=$(get_minutes_until_reset)
    
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        log_message "Time remaining: $minutes_remaining minutes"
        
        if [ "$minutes_remaining" -le 5 ]; then
            # Check every 30 seconds when close to reset
            echo 30
        elif [ "$minutes_remaining" -le 30 ]; then
            # Check every 2 minutes when within 30 minutes
            echo 120
        else
            # Check every 10 minutes otherwise
            echo 600
        fi
    else
        # Fallback: check based on last activity
        if [ -f "$LAST_ACTIVITY_FILE" ]; then
            local last_activity=$(cat "$LAST_ACTIVITY_FILE")
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_activity))
            local remaining=$((18000 - time_diff))  # 5 hours = 18000 seconds
            
            if [ "$remaining" -le 300 ]; then  # 5 minutes
                echo 30
            elif [ "$remaining" -le 1800 ]; then  # 30 minutes
                echo 120
            else
                echo 600
            fi
        else
            # No info available, check every 5 minutes
            echo 300
        fi
    fi
}

# Main daemon loop
main() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Daemon already running with PID $OLD_PID"
            exit 1
        else
            log_message "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi
    
    # Save PID
    echo $$ > "$PID_FILE"
    
    log_message "=== Claude Nights Watch Daemon Started ==="
    log_message "PID: $$"
    log_message "Logs: $LOG_FILE"
    log_message "Task directory: $TASK_DIR"
    
    # Check for task file
    if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
        log_message "WARNING: Task file not found at $TASK_DIR/$TASK_FILE"
        log_message "Please create a task.md file with your tasks"
    fi
    
    # Check for rules file
    if [ -f "$TASK_DIR/$RULES_FILE" ]; then
        log_message "Rules file found at $TASK_DIR/$RULES_FILE"
    else
        log_message "No rules file found. Consider creating $RULES_FILE for safety constraints"
    fi
    
    # Check for start time
    if [ -f "$START_TIME_FILE" ]; then
        start_epoch=$(cat "$START_TIME_FILE")
        log_message "Start time configured: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
    else
        log_message "No start time set - will begin monitoring immediately"
    fi
    
    # Check ccusage availability
    if ! get_ccusage_cmd &> /dev/null; then
        log_message "WARNING: ccusage not found. Using time-based checking."
        log_message "Install ccusage for more accurate timing: npm install -g ccusage"
    fi
    
    # Main loop
    while true; do
        # Check if we're past start time
        if ! is_start_time_reached; then
            time_until_start=$(get_time_until_start)
            hours=$((time_until_start / 3600))
            minutes=$(((time_until_start % 3600) / 60))
            seconds=$((time_until_start % 60))
            
            if [ "$hours" -gt 0 ]; then
                log_message "Waiting for start time (${hours}h ${minutes}m remaining)..."
                sleep 300  # Check every 5 minutes when waiting
            elif [ "$minutes" -gt 2 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 60   # Check every minute when close
            elif [ "$time_until_start" -gt 10 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 10   # Check every 10 seconds when very close
            else
                log_message "Waiting for start time (${seconds}s remaining)..."
                sleep 2    # Check every 2 seconds when imminent
            fi
            continue
        fi
        
        # If we just reached start time, log it
        if [ -f "$START_TIME_FILE" ]; then
            # Check if this is the first time we're active
            if [ ! -f "${START_TIME_FILE}.activated" ]; then
                log_message "✅ Start time reached! Beginning task execution monitoring..."
                touch "${START_TIME_FILE}.activated"
            fi
        fi
        
        # Get minutes until reset
        minutes_remaining=$(get_minutes_until_reset)
        
        # Check if we should execute task
        should_execute=false
        
        if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
            if [ "$minutes_remaining" -le 2 ]; then
                should_execute=true
                log_message "Reset imminent ($minutes_remaining minutes), preparing to execute task..."
            fi
        else
            # Fallback check
            if [ -f "$LAST_ACTIVITY_FILE" ]; then
                last_activity=$(cat "$LAST_ACTIVITY_FILE")
                current_time=$(date +%s)
                time_diff=$((current_time - last_activity))
                
                if [ $time_diff -ge 18000 ]; then
                    should_execute=true
                    log_message "5 hours elapsed since last activity, executing task..."
                fi
            else
                # No activity recorded, safe to start
                should_execute=true
                log_message "No previous activity recorded, starting initial task execution..."
            fi
        fi
        
        # Execute task if needed
        if [ "$should_execute" = true ]; then
            # Check if task file exists before execution
            if [ ! -f "$TASK_DIR/$TASK_FILE" ]; then
                log_message "ERROR: Cannot execute - task file not found at $TASK_DIR/$TASK_FILE"
                log_message "Waiting 5 minutes before next check..."
                sleep 300
                continue
            fi
            
            # Wait a bit to ensure we're in the renewal window
            sleep 60
            
            # Try to execute task
            if execute_task; then
                log_message "Task execution completed!"
                # Sleep for 5 minutes after successful execution
                sleep 300
            else
                log_message "Task execution failed, will retry in 1 minute"
                sleep 60
            fi
        fi
        
        # Calculate how long to sleep
        sleep_duration=$(calculate_sleep_duration)
        log_message "Next check in $((sleep_duration / 60)) minutes"
        
        # Sleep until next check
        sleep "$sleep_duration"
    done
}

# Start the daemon
main