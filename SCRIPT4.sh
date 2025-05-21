#!/bin/bash
#
# Script 4: Functions and Advanced Techniques
# This script teaches: functions, return values, error handling, advanced awk/grep
# Function definition and calling
# Return values
# Global vs local variables
# Command line option parsing with getopts
# Error handling
# Advanced awk usage
# Case statements
# Complex data processing

# Commands demonstrated: Advanced awk, grep with regex, systemctl, ping, du, bc


# Global variables
LOG_FILE="/tmp/system_check.log"
DEBUG=false

# Function to display usage
usage() {
    echo "Usage: $0 [-d] [-h] <action>"
    echo "Actions:"
    echo "  check-system    - Perform system health check"
    echo "  find-large      - Find large files"
    echo "  analyze-logs    - Analyze system logs"
    echo "Options:"
    echo "  -d             - Enable debug mode"
    echo "  -h             - Show this help message"
    exit 1
}

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Debug messages only shown if DEBUG is true
    if [ "$level" = "DEBUG" ] && [ "$DEBUG" = false ]; then
        return
    fi
}

# Function to check system resources
check_system_resources() {
    log_message "INFO" "Starting system resource check..."
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    log_message "INFO" "CPU Usage: ${cpu_usage}%"
    
    # Memory usage
    local memory_info=$(free -m | awk 'NR==2{printf "Used: %sMB (%.2f%%), Free: %sMB", $3, $3*100/$2, $4}')
    log_message "INFO" "Memory: $memory_info"
    
    # Disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    log_message "INFO" "Disk Usage: $disk_usage"
    
    # Return status based on thresholds
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_message "WARN" "High CPU usage detected!"
        return 1
    fi
    
    return 0
}

# Function to find large files with advanced filtering
find_large_files() {
    local directory="${1:-/}"
    local size_limit="${2:-100M}"
    
    log_message "INFO" "Searching for files larger than $size_limit in $directory"
    
    # Validate directory
    if [ ! -d "$directory" ]; then
        log_message "ERROR" "Directory $directory does not exist"
        return 1
    fi
    
    # Find large files and format output
    find "$directory" -type f -size "+${size_limit}" 2>/dev/null | while read -r file; do
        local size=$(du -h "$file" | cut -f1)
        local modified=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        echo "$size	$modified	$file"
    done | sort -hr | column -t -s $'\t'
}

# Function to analyze log files
analyze_logs() {
    local log_file="${1:-/var/log/syslog}"
    local pattern="${2:-error|warning|critical}"
    
    log_message "INFO" "Analyzing $log_file for pattern: $pattern"
    
    if [ ! -f "$log_file" ]; then
        log_message "ERROR" "Log file $log_file not found"
        return 1
    fi
    
    # Count occurrences
    local total_lines=$(wc -l < "$log_file")
    local matches=$(grep -iE "$pattern" "$log_file" | wc -l)
    
    echo "Log Analysis Summary:"
    echo "Total lines: $total_lines"
    echo "Matches: $matches"
    echo -e "\nTop 10 most frequent patterns:"
    
    # Use awk to count and sort patterns
    grep -iE "$pattern" "$log_file" | \
        awk '{for(i=1;i<=NF;i++) if($i ~ /error|warning|critical/i) print $i}' | \
        sort | uniq -c | sort -nr | head -10
    
    echo -e "\nRecent matches (last 5):"
    grep -iE "$pattern" "$log_file" | tail -5
}

# Function to perform comprehensive system check
perform_system_check() {
    log_message "INFO" "Starting comprehensive system check..."
    
    local status=0
    
    # Check system resources
    if ! check_system_resources; then
        status=1
    fi
    
    # Check disk space
    echo -e "\nDisk Space Analysis:"
    df -h | awk 'NR==1 || $5+0 > 80 {print $0}'
    
    # Check running services
    echo -e "\nService Status:"
    for service in ssh cron; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "$service: active"
        else
            echo "$service: inactive"
            status=1
        fi
    done
    
    # Check for failed services
    echo -e "\nFailed Services:"
    systemctl --failed --no-pager
    
    # Network connectivity check
    echo -e "\nNetwork Connectivity:"
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo "Internet connectivity: OK"
    else
        echo "Internet connectivity: FAILED"
        status=1
    fi
    
    return $status
}

# Main function
main() {
    # Process command line options
    while getopts "dh" opt; do
        case $opt in
            d) DEBUG=true ;;
            h) usage ;;
            \?) usage ;;
        esac
    done
    
    # Shift past the options
    shift $((OPTIND-1))
    
    # Check for action argument
    if [ $# -eq 0 ]; then
        usage
    fi
    
    local action="$1"
    shift
    
    # Execute action
    case "$action" in
        check-system)
            perform_system_check
            ;;
        find-large)
            find_large_files "$@"
            ;;
        analyze-logs)
            analyze_logs "$@"
            ;;
        *)
            log_message "ERROR" "Unknown action: $action"
            usage
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
