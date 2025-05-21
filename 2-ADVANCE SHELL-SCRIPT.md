# Advanced DevOps Shell Scripting - Functions, Error Handling, and Automation 🚀

This guide focuses on advanced shell scripting techniques for DevOps automation, including robust error handling, input validation, integration with Terraform and Python, and building reusable script libraries.

## Table of Contents
1. [Advanced Functions and Libraries](#advanced-functions-and-libraries)
2. [Robust Error Handling](#robust-error-handling)
3. [Input Validation and Sanitization](#input-validation-and-sanitization)
4. [Logging and Debugging Framework](#logging-and-debugging-framework)
5. [Integration with Terraform](#integration-with-terraform)
6. [Integration with Python](#integration-with-python)
7. [Building a DevOps Script Library](#building-a-devops-script-library)
8. [Testing Shell Scripts](#testing-shell-scripts)
9. [Script Packaging and Distribution](#script-packaging-and-distribution)
10. [Real-World DevOps Examples](#real-world-devops-examples)

## Advanced Functions and Libraries

### Function Library Structure

```bash
#!/bin/bash
# lib/common.sh - Common functions library

# Source guard to prevent multiple inclusions
[[ -n "$_COMMON_SH_LOADED" ]] && return
readonly _COMMON_SH_LOADED=1

# Global constants
readonly LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "$LIB_DIR")"

# Function: Initialize library
# Usage: lib_init
lib_init() {
    # Set strict mode
    set -euo pipefail
    IFS=$'\n\t'
    
    # Enable extended globbing
    shopt -s extglob nullglob
    
    # Set default umask
    umask 022
}

# Function: Source other libraries
# Usage: lib_source "logging" "validation" "aws"
lib_source() {
    local libs=("$@")
    local lib
    
    for lib in "${libs[@]}"; do
        local lib_file="${LIB_DIR}/${lib}.sh"
        if [[ -f "$lib_file" ]]; then
            # shellcheck source=/dev/null
            source "$lib_file"
        else
            echo "ERROR: Library not found: $lib_file" >&2
            return 1
        fi
    done
}

# Function: Check dependencies
# Usage: check_deps "curl" "jq" "aws"
check_deps() {
    local deps=("$@")
    local missing=()
    local cmd
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies: ${missing[*]}" >&2
        echo "Please install the missing commands and try again." >&2
        return 1
    fi
}

# Export functions
export -f lib_init lib_source check_deps
```

### Advanced Function Patterns

```bash
#!/bin/bash
# lib/functions.sh - Advanced function patterns

# Function with named parameters
# Usage: deploy_app --name myapp --env prod --version 1.2.3
deploy_app() {
    local name env version debug=false
    
    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                name="$2"
                shift 2
                ;;
            --env)
                env="$2"
                shift 2
                ;;
            --version)
                version="$2"
                shift 2
                ;;
            --debug)
                debug=true
                shift
                ;;
            *)
                echo "Unknown parameter: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Validate required parameters
    [[ -n "$name" ]] || { echo "Missing --name parameter" >&2; return 1; }
    [[ -n "$env" ]] || { echo "Missing --env parameter" >&2; return 1; }
    [[ -n "$version" ]] || { echo "Missing --version parameter" >&2; return 1; }
    
    # Function body
    echo "Deploying $name version $version to $env"
    [[ "$debug" == "true" ]] && set -x
    
    # Deployment logic here
}

# Function with return values
# Usage: result=$(get_aws_account_id)
get_aws_account_id() {
    local account_id
    
    account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
        echo "ERROR: Failed to get AWS account ID" >&2
        return 1
    }
    
    echo "$account_id"
}

# Function with output parameters
# Usage: get_system_info cpu_info mem_info disk_info
get_system_info() {
    local -n _cpu_ref=$1
    local -n _mem_ref=$2
    local -n _disk_ref=$3
    
    _cpu_ref=$(grep -c ^processor /proc/cpuinfo)
    _mem_ref=$(free -h | awk '/^Mem:/ {print $2}')
    _disk_ref=$(df -h / | awk 'NR==2 {print $2}')
}

# Recursive function with memoization
declare -A _fibonacci_cache

fibonacci() {
    local n=$1
    
    # Check cache
    if [[ -n "${_fibonacci_cache[$n]:-}" ]]; then
        echo "${_fibonacci_cache[$n]}"
        return
    fi
    
    # Base cases
    if [[ $n -le 1 ]]; then
        _fibonacci_cache[$n]=$n
        echo $n
        return
    fi
    
    # Recursive case
    local result=$(($(fibonacci $((n-1))) + $(fibonacci $((n-2)))))
    _fibonacci_cache[$n]=$result
    echo $result
}

# Function with timeout
# Usage: with_timeout 10 long_running_command
with_timeout() {
    local timeout=$1
    shift
    
    # Execute command with timeout
    timeout "$timeout" "$@"
    local exit_code=$?
    
    case $exit_code in
        0) return 0 ;;
        124) echo "ERROR: Command timed out after ${timeout}s" >&2; return 124 ;;
        *) return $exit_code ;;
    esac
}

# Async function execution
# Usage: async_exec command1 command2 command3
async_exec() {
    local pids=()
    local exit_codes=()
    local cmd
    
    # Start all commands in background
    for cmd in "$@"; do
        eval "$cmd" &
        pids+=($!)
    done
    
    # Wait for all commands and collect exit codes
    for pid in "${pids[@]}"; do
        wait "$pid"
        exit_codes+=($?)
    done
    
    # Check if any command failed
    for exit_code in "${exit_codes[@]}"; do
        if [[ $exit_code -ne 0 ]]; then
            return 1
        fi
    done
    
    return 0
}
```

## Robust Error Handling

### Error Handling Framework

```bash
#!/bin/bash
# lib/error.sh - Error handling framework

# Global error state
declare -g ERROR_COUNT=0
declare -g ERROR_MESSAGES=()

# Error types
readonly ERR_GENERAL=1
readonly ERR_INVALID_ARG=2
readonly ERR_FILE_NOT_FOUND=3
readonly ERR_PERMISSION=4
readonly ERR_NETWORK=5
readonly ERR_TIMEOUT=6
readonly ERR_DEPENDENCY=7

# Function: Set up error handling
# Usage: error_setup
error_setup() {
    set -eE -o pipefail
    trap 'error_handler ${LINENO} "$BASH_LINENO" "${FUNCNAME[@]}" "$?" "$BASH_COMMAND"' ERR
    trap 'error_cleanup' EXIT
}

# Function: Error handler
error_handler() {
    local line=$1
    local linecallfunc=$2
    local funcstack=("${@:3:$#-5}")
    local exit_code=$((${@: -2:1}))
    local command="${@: -1}"
    
    local func
    local frame=0
    
    # Build error message
    local error_msg="Error on line ${line}: Command '${command}' exited with status ${exit_code}"
    
    # Add stack trace
    if [[ ${#funcstack[@]} -gt 1 ]]; then
        error_msg+="\nCall stack:"
        for func in "${funcstack[@]:1}"; do
            error_msg+="\n  at ${func} (line ${linecallfunc})"
            ((frame++))
        done
    fi
    
    # Record error
    ((ERROR_COUNT++))
    ERROR_MESSAGES+=("$error_msg")
    
    # Log error
    echo -e "ERROR: $error_msg" >&2
    
    # Don't exit if we're in a subshell
    [[ $BASH_SUBSHELL -eq 0 ]] && exit "$exit_code"
}

# Function: Cleanup on exit
error_cleanup() {
    local exit_code=$?
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        echo "Script failed with $ERROR_COUNT error(s)" >&2
        
        # Save error report if configured
        if [[ -n "${ERROR_LOG_FILE:-}" ]]; then
            {
                echo "Error Report - $(date)"
                echo "======================="
                printf '%s\n' "${ERROR_MESSAGES[@]}"
            } >> "$ERROR_LOG_FILE"
        fi
    fi
    
    # Custom cleanup handler
    if type -t custom_cleanup &>/dev/null; then
        custom_cleanup
    fi
    
    exit $exit_code
}

# Function: Try-catch block
# Usage: try command catch error_handler
try() {
    [[ $# -eq 0 ]] && return
    
    local cmd=("${@:1:$#-2}")
    local catch_func="${@: -1}"
    
    # Execute command
    if ! "${cmd[@]}"; then
        # Call catch function if provided
        if [[ "$catch_func" != "catch" ]] && type -t "$catch_func" &>/dev/null; then
            "$catch_func" "$?"
        fi
        return 1
    fi
}

# Function: Assert conditions
# Usage: assert "condition" "error message"
assert() {
    local condition=$1
    local message=${2:-"Assertion failed: $condition"}
    
    if ! eval "$condition"; then
        echo "ASSERTION FAILED: $message" >&2
        return 1
    fi
}

# Function: Retry with exponential backoff
# Usage: retry 5 1 curl https://api.example.com
retry() {
    local max_attempts=$1
    local initial_delay=$2
    shift 2
    
    local attempt=1
    local delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt $attempt/$max_attempts: $*" >&2
        
        if "$@"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "Failed, retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))
        fi
        
        ((attempt++))
    done
    
    echo "All $max_attempts attempts failed" >&2
    return 1
}

# Function: Handle specific error types
# Usage: handle_error $error_code
handle_error() {
    local error_code=$1
    
    case $error_code in
        $ERR_INVALID_ARG)
            echo "Invalid argument provided" >&2
            ;;
        $ERR_FILE_NOT_FOUND)
            echo "Required file not found" >&2
            ;;
        $ERR_PERMISSION)
            echo "Permission denied" >&2
            ;;
        $ERR_NETWORK)
            echo "Network error occurred" >&2
            ;;
        $ERR_TIMEOUT)
            echo "Operation timed out" >&2
            ;;
        $ERR_DEPENDENCY)
            echo "Missing dependency" >&2
            ;;
        *)
            echo "Unknown error occurred" >&2
            ;;
    esac
    
    return "$error_code"
}
```

## Input Validation and Sanitization

### Validation Framework

```bash
#!/bin/bash
# lib/validation.sh - Input validation framework

# Function: Validate string
# Usage: validate_string "$input" "pattern" "error message"
validate_string() {
    local input=$1
    local pattern=$2
    local error_msg=${3:-"Invalid input"}
    
    if [[ ! "$input" =~ $pattern ]]; then
        echo "ERROR: $error_msg: '$input'" >&2
        return 1
    fi
}

# Function: Validate integer
# Usage: validate_integer "$input" "min" "max"
validate_integer() {
    local input=$1
    local min=${2:--9223372036854775808}  # Min int64
    local max=${3:-9223372036854775807}   # Max int64
    
    # Check if integer
    if [[ ! "$input" =~ ^-?[0-9]+$ ]]; then
        echo "ERROR: Not a valid integer: '$input'" >&2
        return 1
    fi
    
    # Check range
    if [[ $input -lt $min ]] || [[ $input -gt $max ]]; then
        echo "ERROR: Integer out of range [$min, $max]: '$input'" >&2
        return 1
    fi
}

# Function: Validate email
# Usage: validate_email "$email"
validate_email() {
    local email=$1
    local email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    
    validate_string "$email" "$email_regex" "Invalid email address"
}

# Function: Validate IP address
# Usage: validate_ip "$ip"
validate_ip() {
    local ip=$1
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! "$ip" =~ $ip_regex ]]; then
        echo "ERROR: Invalid IP format: '$ip'" >&2
        return 1
    fi
    
    # Validate octets
    local IFS='.'
    local octets=($ip)
    local octet
    
    for octet in "${octets[@]}"; do
        if [[ $octet -gt 255 ]]; then
            echo "ERROR: Invalid IP octet: '$octet'" >&2
            return 1
        fi
    done
}

# Function: Validate URL
# Usage: validate_url "$url"
validate_url() {
    local url=$1
    local url_regex='^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/.*)?$'
    
    validate_string "$url" "$url_regex" "Invalid URL"
}

# Function: Validate file path
# Usage: validate_path "$path" "type"
validate_path() {
    local path=$1
    local type=${2:-"any"}  # any, file, dir, readable, writable, executable
    
    # Check for dangerous characters
    if [[ "$path" =~ [\`\$\(\)] ]]; then
        echo "ERROR: Path contains dangerous characters: '$path'" >&2
        return 1
    fi
    
    # Resolve path
    local resolved_path
    resolved_path=$(realpath -m "$path" 2>/dev/null) || {
        echo "ERROR: Invalid path: '$path'" >&2
        return 1
    }
    
    # Type-specific validation
    case $type in
        file)
            [[ -f "$resolved_path" ]] || {
                echo "ERROR: Not a file: '$resolved_path'" >&2
                return 1
            }
            ;;
        dir)
            [[ -d "$resolved_path" ]] || {
                echo "ERROR: Not a directory: '$resolved_path'" >&2
                return 1
            }
            ;;
        readable)
            [[ -r "$resolved_path" ]] || {
                echo "ERROR: Not readable: '$resolved_path'" >&2
                return 1
            }
            ;;
        writable)
            [[ -w "$resolved_path" ]] || {
                echo "ERROR: Not writable: '$resolved_path'" >&2
                return 1
            }
            ;;
        executable)
            [[ -x "$resolved_path" ]] || {
                echo "ERROR: Not executable: '$resolved_path'" >&2
                return 1
            }
            ;;
    esac
}

# Function: Validate environment variable
# Usage: validate_env "VAR_NAME" "pattern"
validate_env() {
    local var_name=$1
    local pattern=${2:-".*"}
    
    # Check if set
    if [[ -z "${!var_name:-}" ]]; then
        echo "ERROR: Environment variable not set: $var_name" >&2
        return 1
    fi
    
    # Validate value
    validate_string "${!var_name}" "$pattern" "Invalid value for $var_name"
}

# Function: Validate JSON
# Usage: validate_json "$json_string"
validate_json() {
    local json=$1
    
    if ! jq empty <<< "$json" 2>/dev/null; then
        echo "ERROR: Invalid JSON" >&2
        return 1
    fi
}

# Function: Validate YAML
# Usage: validate_yaml "$yaml_file"
validate_yaml() {
    local yaml_file=$1
    
    if ! command -v yq &>/dev/null; then
        echo "ERROR: yq not installed" >&2
        return 1
    fi
    
    if ! yq eval '.' "$yaml_file" &>/dev/null; then
        echo "ERROR: Invalid YAML file: $yaml_file" >&2
        return 1
    fi
}

# Function: Sanitize string
# Usage: sanitized=$(sanitize_string "$input")
sanitize_string() {
    local input=$1
    local allowed_chars=${2:-'A-Za-z0-9._-'}
    
    # Remove characters not in allowed set
    echo "$input" | tr -cd "$allowed_chars"
}

# Function: Sanitize path
# Usage: safe_path=$(sanitize_path "$path")
sanitize_path() {
    local path=$1
    
    # Remove dangerous characters and resolve path
    local safe_path
    safe_path=$(echo "$path" | tr -d '`$()' | xargs realpath -m 2>/dev/null) || {
        echo "ERROR: Failed to sanitize path: '$path'" >&2
        return 1
    }
    
    echo "$safe_path"
}
```

## Logging and Debugging Framework

### Comprehensive Logging System

```bash
#!/bin/bash
# lib/logging.sh - Logging and debugging framework

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Global logging configuration
declare -g LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}
declare -g LOG_FILE=${LOG_FILE:-""}
declare -g LOG_FORMAT=${LOG_FORMAT:-"json"}  # text, json
declare -g LOG_COLOR=${LOG_COLOR:-"true"}
declare -g LOG_CONTEXT=${LOG_CONTEXT:-""}

# ANSI colors
declare -A LOG_COLORS=(
    [DEBUG]=$'\e[36m'    # Cyan
    [INFO]=$'\e[32m'     # Green
    [WARN]=$'\e[33m'     # Yellow
    [ERROR]=$'\e[31m'    # Red
    [FATAL]=$'\e[35m'    # Magenta
    [RESET]=$'\e[0m'
)

# Function: Initialize logging
# Usage: log_init --level info --file app.log --format json
log_init() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --level)
                case ${2,,} in
                    debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
                    info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
                    warn) LOG_LEVEL=$LOG_LEVEL_WARN ;;
                    error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
                    fatal) LOG_LEVEL=$LOG_LEVEL_FATAL ;;
                    *) echo "Invalid log level: $2" >&2; return 1 ;;
                esac
                shift 2
                ;;
            --file)
                LOG_FILE="$2"
                shift 2
                ;;
            --format)
                LOG_FORMAT="$2"
                shift 2
                ;;
            --no-color)
                LOG_COLOR="false"
                shift
                ;;
            --context)
                LOG_CONTEXT="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Create log directory if needed
    if [[ -n "$LOG_FILE" ]]; then
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" || return 1
    fi
}

# Function: Core logging function
# Usage: log LEVEL "message" [key=value ...]
log() {
    local level=$1
    local message=$2
    shift 2
    
    # Check log level
    local level_num
    case ${level^^} in
        DEBUG) level_num=$LOG_LEVEL_DEBUG ;;
        INFO) level_num=$LOG_LEVEL_INFO ;;
        WARN) level_num=$LOG_LEVEL_WARN ;;
        ERROR) level_num=$LOG_LEVEL_ERROR ;;
        FATAL) level_num=$LOG_LEVEL_FATAL ;;
        *) level_num=$LOG_LEVEL_INFO ;;
    esac
    
    [[ $level_num -lt $LOG_LEVEL ]] && return
    
    # Build log entry
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Structured fields
    local fields=()
    local field
    for field in "$@"; do
        fields+=("$field")
    done
    
    # Add context
    [[ -n "$LOG_CONTEXT" ]] && fields+=("context=$LOG_CONTEXT")
    
    # Add caller information
    local caller="${FUNCNAME[2]:-main}"
    local line="${BASH_LINENO[1]:-0}"
    fields+=("caller=$caller" "line=$line")
    
    # Format output
    local output
    case $LOG_FORMAT in
        json)
            output=$(build_json_log "$timestamp" "$level" "$message" "${fields[@]}")
            ;;
        *)
            output=$(build_text_log "$timestamp" "$level" "$message" "${fields[@]}")
            ;;
    esac
    
    # Apply color for console output
    if [[ "$LOG_COLOR" == "true" ]] && [[ -t 2 ]]; then
        output="${LOG_COLORS[${level^^}]}${output}${LOG_COLORS[RESET]}"
    fi
    
    # Output to stderr
    echo -e "$output" >&2
    
    # Output to file if configured
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$output" >> "$LOG_FILE"
    fi
    
    # Fatal exits
    if [[ "$level" == "FATAL" ]]; then
        exit 1
    fi
}

# Function: Build JSON log entry
build_json_log() {
    local timestamp=$1
    local level=$2
    local message=$3
    shift 3
    
    local json="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\""
    
    # Add fields
    local field key value
    for field in "$@"; do
        if [[ "$field" =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Escape JSON value
            value=$(echo "$value" | jq -Rs .)
            json+=",\"$key\":$value"
        fi
    done
    
    json+="}"
    echo "$json"
}

# Function: Build text log entry
build_text_log() {
    local timestamp=$1
    local level=$2
    local message=$3
    shift 3
    
    local output="$timestamp [$level] $message"
    
    # Add fields
    local field
    for field in "$@"; do
        output+=" $field"
    done
    
    echo "$output"
}

# Convenience functions
log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }
log_fatal() { log FATAL "$@"; }

# Function: Debug mode
# Usage: debug_mode on|off
debug_mode() {
    case $1 in
        on)
            set -x
            LOG_LEVEL=$LOG_LEVEL_DEBUG
            PS4='+ [${BASH_SOURCE}:${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
            ;;
        off)
            set +x
            LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
    esac
}

# Function: Stack trace
# Usage: stack_trace
stack_trace() {
    local frame=0
    local func file line
    
    echo "Stack trace:" >&2
    while caller $frame; do
        ((frame++))
    done | while read -r line func file; do
        echo "  at $func ($file:$line)" >&2
    done
}

# Function: Dump variables
# Usage: dump_vars VAR1 VAR2 ...
dump_vars() {
    local var
    for var in "$@"; do
        if [[ -n "${!var+x}" ]]; then
            echo "$var=${!var}" >&2
        else
            echo "$var=<unset>" >&2
        fi
    done
}

# Function: Timing wrapper
# Usage: time_it "operation" command
time_it() {
    local operation=$1
    shift
    
    local start_time
    start_time=$(date +%s.%N)
    
    "$@"
    local exit_code=$?
    
    local end_time
    end_time=$(date +%s.%N)
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc)
    
    log_info "$operation completed" "duration=${duration}s" "exit_code=$exit_code"
    
    return $exit_code
}
```

## Integration with Terraform

### Terraform External Data Source Script

```bash
#!/bin/bash
# scripts/terraform-data-source.sh - Terraform external data source

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/validation.sh"

# Initialize
lib_init
log_init --level info --format json

# Read query from stdin
query=$(cat)
log_debug "Received query" "query=$query"

# Validate JSON
validate_json "$query" || {
    echo '{"error": "Invalid JSON input"}'
    exit 1
}

# Extract parameters
param1=$(echo "$query" | jq -r '.param1 // empty')
param2=$(echo "$query" | jq -r '.param2 // empty')

# Process request
result=$(process_terraform_request "$param1" "$param2")

# Return JSON response
echo "$result"
```

### Terraform Provisioner Script

```bash
#!/bin/bash
# scripts/terraform-provisioner.sh - Terraform remote-exec provisioner

set -euo pipefail

# Configuration passed from Terraform
ENVIRONMENT="${1:-}"
APP_NAME="${2:-}"
VERSION="${3:-}"

# Logging
LOG_FILE="/var/log/terraform-provisioner.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Validate inputs
[[ -n "$ENVIRONMENT" ]] || { log "ERROR: Environment not specified"; exit 1; }
[[ -n "$APP_NAME" ]] || { log "ERROR: App name not specified"; exit 1; }
[[ -n "$VERSION" ]] || { log "ERROR: Version not specified"; exit 1; }

log "Starting provisioning for $APP_NAME v$VERSION in $ENVIRONMENT"

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Update package cache
    case "$(uname -s)" in
        Linux*)
            if command -v apt-get &>/dev/null; then
                sudo apt-get update
                sudo apt-get install -y curl wget jq
            elif command -v yum &>/dev/null; then
                sudo yum install -y curl wget jq
            fi
            ;;
        Darwin*)
            if command -v brew &>/dev/null; then
                brew install curl wget jq
            fi
            ;;
    esac
}

# Configure application
configure_app() {
    log "Configuring application..."
    
    # Create directories
    sudo mkdir -p /opt/"$APP_NAME"/{bin,config,logs}
    
    # Download application
    curl -fsSL "https://releases.example.com/$APP_NAME/$VERSION/$APP_NAME" \
        -o "/tmp/$APP_NAME"
    
    # Install application
    sudo mv "/tmp/$APP_NAME" /opt/"$APP_NAME"/bin/
    sudo chmod +x /opt/"$APP_NAME"/bin/"$APP_NAME"
    
    # Create configuration
    cat <<EOF | sudo tee /opt/"$APP_NAME"/config/app.json
{
    "environment": "$ENVIRONMENT",
    "version": "$VERSION",
    "log_level": "info"
}
EOF
}

# Create systemd service
create_service() {
    log "Creating systemd service..."
    
    cat <<EOF | sudo tee /etc/systemd/system/"$APP_NAME".service
[Unit]
Description=$APP_NAME Service
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
WorkingDirectory=/opt/$APP_NAME
ExecStart=/opt/$APP_NAME/bin/$APP_NAME
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable "$APP_NAME"
    sudo systemctl start "$APP_NAME"
}

# Main execution
main() {
    install_dependencies
    configure_app
    create_service
    
    log "Provisioning completed successfully"
}

main
```

### Terraform Null Resource Script

```bash
#!/bin/bash
# scripts/terraform-null-resource.sh - Script for terraform null_resource

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/error.sh"

# Initialize
lib_init
error_setup
log_init --level info --file /tmp/terraform-null-resource.log

# Parse arguments
ACTION="${1:-create}"
RESOURCE_ID="${2:-}"
TRIGGER="${3:-}"

log_info "Terraform null_resource script" "action=$ACTION" "resource_id=$RESOURCE_ID" "trigger=$TRIGGER"

# Create resource
create_resource() {
    log_info "Creating resource" "id=$RESOURCE_ID"
    
    # Perform creation tasks
    # This could be anything from creating files to calling APIs
    echo "$RESOURCE_ID" > "/tmp/resource-${RESOURCE_ID}.txt"
    
    # Return state
    cat <<EOF
{
    "id": "$RESOURCE_ID",
    "trigger": "$TRIGGER",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Destroy resource
destroy_resource() {
    log_info "Destroying resource" "id=$RESOURCE_ID"
    
    # Perform cleanup
    rm -f "/tmp/resource-${RESOURCE_ID}.txt"
}

# Main execution
case "$ACTION" in
    create)
        create_resource
        ;;
    destroy)
        destroy_resource
        ;;
    *)
        log_error "Unknown action: $ACTION"
        exit 1
        ;;
esac
```

## Integration with Python

### Python-Shell Integration Library

```bash
#!/bin/bash
# lib/python-integration.sh - Python integration utilities

# Function: Execute Python inline
# Usage: python_exec "print('Hello from Python')"
python_exec() {
    local code=$1
    python3 -c "$code"
}

# Function: Execute Python script with arguments
# Usage: python_script script.py arg1 arg2
python_script() {
    local script=$1
    shift
    python3 "$script" "$@"
}

# Function: Pass data to Python via JSON
# Usage: python_json_exec "$json_data" "script"
python_json_exec() {
    local json_data=$1
    local python_code=$2
    
    echo "$json_data" | python3 -c "
import sys
import json
data = json.load(sys.stdin)
$python_code
"
}

# Function: Get Python output as JSON
# Usage: result=$(python_json_output "script")
python_json_output() {
    local python_code=$1
    
    python3 -c "
import json
$python_code
print(json.dumps(result))
"
}

# Function: Call Python function from shell
# Usage: result=$(python_call module.function arg1 arg2)
python_call() {
    local module_function=$1
    shift
    local args=("$@")
    
    # Convert arguments to JSON array
    local json_args
    json_args=$(printf '%s\n' "${args[@]}" | jq -R . | jq -s .)
    
    python3 -c "
import sys
import json
import importlib

# Parse module and function
module_path, function_name = '$module_function'.rsplit('.', 1)
module = importlib.import_module(module_path)
function = getattr(module, function_name)

# Parse arguments
args = json.loads('$json_args')

# Call function
result = function(*args)

# Return result as JSON
print(json.dumps(result))
"
}
```

### Shell Script for Python Automation

```bash
#!/bin/bash
# scripts/python-wrapper.sh - Wrapper for Python automation

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/python-integration.sh"

# Configuration
PYTHON_SCRIPT="${PYTHON_SCRIPT:-}"
PYTHON_MODULE="${PYTHON_MODULE:-}"
PYTHON_FUNCTION="${PYTHON_FUNCTION:-}"
VIRTUALENV="${VIRTUALENV:-}"

# Function: Setup Python environment
setup_python_env() {
    # Check Python version
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is required but not found"
        return 1
    fi
    
    local python_version
    python_version=$(python3 --version | awk '{print $2}')
    log_info "Python version: $python_version"
    
    # Activate virtual environment if specified
    if [[ -n "$VIRTUALENV" ]]; then
        if [[ -f "$VIRTUALENV/bin/activate" ]]; then
            log_info "Activating virtual environment: $VIRTUALENV"
            # shellcheck source=/dev/null
            source "$VIRTUALENV/bin/activate"
        else
            log_error "Virtual environment not found: $VIRTUALENV"
            return 1
        fi
    fi
    
    # Install requirements if present
    if [[ -f "requirements.txt" ]]; then
        log_info "Installing Python requirements"
        pip install -r requirements.txt
    fi
}

# Function: Execute Python automation
execute_python() {
    local input_data=$1
    local output_file=${2:-/dev/stdout}
    
    # Prepare Python code
    local python_code="
import sys
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load input data
try:
    input_data = json.loads('''$input_data''')
    logger.info(f'Loaded input data: {input_data}')
except json.JSONDecodeError as e:
    logger.error(f'Failed to parse input JSON: {e}')
    sys.exit(1)

# Import and execute specified module/function
try:
    if '$PYTHON_MODULE' and '$PYTHON_FUNCTION':
        import importlib
        module = importlib.import_module('$PYTHON_MODULE')
        func = getattr(module, '$PYTHON_FUNCTION')
        result = func(input_data)
    elif '$PYTHON_SCRIPT':
        exec(open('$PYTHON_SCRIPT').read())
        result = locals().get('result', {})
    else:
        logger.error('No Python script or module specified')
        sys.exit(1)
    
    # Output result
    output = json.dumps(result, indent=2)
    print(output)
    
except Exception as e:
    logger.error(f'Python execution failed: {e}')
    import traceback
    logger.error(traceback.format_exc())
    sys.exit(1)
"
    
    # Execute Python code
    if python3 -c "$python_code" > "$output_file"; then
        log_info "Python execution completed successfully"
        return 0
    else
        log_error "Python execution failed"
        return 1
    fi
}

# Main execution
main() {
    local input_file=${1:-/dev/stdin}
    local output_file=${2:-/dev/stdout}
    
    log_info "Starting Python wrapper" \
        "input=$input_file" \
        "output=$output_file" \
        "script=$PYTHON_SCRIPT" \
        "module=$PYTHON_MODULE" \
        "function=$PYTHON_FUNCTION"
    
    # Setup environment
    setup_python_env || exit 1
    
    # Read input data
    local input_data
    input_data=$(cat "$input_file")
    
    # Execute Python code
    execute_python "$input_data" "$output_file"
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --script)
            PYTHON_SCRIPT="$2"
            shift 2
            ;;
        --module)
            PYTHON_MODULE="$2"
            shift 2
            ;;
        --function)
            PYTHON_FUNCTION="$2"
            shift 2
            ;;
        --virtualenv)
            VIRTUALENV="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

main "$@"
```

### Python Script Called from Shell

```python
#!/usr/bin/env python3
# scripts/automation_task.py - Example Python script for shell integration

import sys
import json
import logging
import subprocess
from typing import Dict, List, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def execute_shell_command(command: List[str]) -> Dict[str, Any]:
    """Execute shell command and return result"""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True
        )
        
        return {
            "success": True,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.CalledProcessError as e:
        return {
            "success": False,
            "stdout": e.stdout,
            "stderr": e.stderr,
            "returncode": e.returncode,
            "error": str(e)
        }

def process_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Process data from shell script"""
    logger.info(f"Processing data: {data}")
    
    # Perform operations
    action = data.get("action", "default")
    
    if action == "execute":
        command = data.get("command", [])
        result = execute_shell_command(command)
    elif action == "transform":
        # Data transformation logic
        result = {
            "transformed": True,
            "original": data,
            "processed": {
                "keys": list(data.keys()),
                "values": list(data.values())
            }
        }
    else:
        result = {
            "error": f"Unknown action: {action}"
        }
    
    return result

def main():
    """Main entry point"""
    # Read input from stdin
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse input JSON: {e}")
        sys.exit(1)
    
    # Process data
    result = process_data(input_data)
    
    # Output result
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
```

## Building a DevOps Script Library

### Core DevOps Functions Library

```bash
#!/bin/bash
# lib/devops.sh - Core DevOps functions

# AWS Functions
aws_get_instance_id() {
    curl -s http://169.254.169.254/latest/meta-data/instance-id
}

aws_get_region() {
    curl -s http://169.254.169.254/latest/meta-data/placement/region
}

aws_tag_resource() {
    local resource_id=$1
    local key=$2
    local value=$3
    
    aws ec2 create-tags \
        --resources "$resource_id" \
        --tags "Key=$key,Value=$value"
}

# Docker Functions
docker_build() {
    local dockerfile=${1:-Dockerfile}
    local image_name=$2
    local build_args=${3:-}
    
    local cmd="docker build -f $dockerfile -t $image_name"
    
    # Add build args
    if [[ -n "$build_args" ]]; then
        local arg
        for arg in $build_args; do
            cmd+=" --build-arg $arg"
        done
    fi
    
    cmd+=" ."
    eval "$cmd"
}

docker_push() {
    local image_name=$1
    local registry=${2:-}
    
    if [[ -n "$registry" ]]; then
        docker tag "$image_name" "$registry/$image_name"
        docker push "$registry/$image_name"
    else
        docker push "$image_name"
    fi
}

# Kubernetes Functions
k8s_wait_for_deployment() {
    local deployment=$1
    local namespace=${2:-default}
    local timeout=${3:-300}
    
    kubectl wait deployment "$deployment" \
        --namespace "$namespace" \
        --for condition=Available \
        --timeout="${timeout}s"
}

k8s_rolling_update() {
    local deployment=$1
    local image=$2
    local namespace=${3:-default}
    
    kubectl set image deployment/"$deployment" \
        "*=$image" \
        --namespace "$namespace" \
        --record
    
    k8s_wait_for_deployment "$deployment" "$namespace"
}

# Git Functions
git_current_branch() {
    git rev-parse --abbrev-ref HEAD
}

git_commit_hash() {
    git rev-parse --short HEAD
}

git_tag_version() {
    local version=$1
    local message=${2:-"Release version $version"}
    
    git tag -a "v$version" -m "$message"
    git push origin "v$version"
}

# CI/CD Functions
cicd_build_info() {
    cat <<EOF
{
    "build_id": "${BUILD_ID:-local}",
    "build_number": "${BUILD_NUMBER:-0}",
    "git_branch": "$(git_current_branch)",
    "git_commit": "$(git_commit_hash)",
    "build_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "builder": "${USER:-unknown}"
}
EOF
}

# Health Check Functions
health_check_http() {
    local url=$1
    local expected_status=${2:-200}
    local timeout=${3:-30}
    
    local actual_status
    actual_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url")
    
    if [[ "$actual_status" == "$expected_status" ]]; then
        log_info "Health check passed" "url=$url" "status=$actual_status"
        return 0
    else
        log_error "Health check failed" "url=$url" "expected=$expected_status" "actual=$actual_status"
        return 1
    fi
}

# Notification Functions
notify_slack() {
    local webhook_url=$1
    local message=$2
    local channel=${3:-}
    local username=${4:-"DevOps Bot"}
    
    local payload
    payload=$(jq -n \
        --arg msg "$message" \
        --arg ch "$channel" \
        --arg un "$username" \
        '{text: $msg, channel: $ch, username: $un}')
    
    curl -X POST \
        -H 'Content-type: application/json' \
        --data "$payload" \
        "$webhook_url"
}

# Monitoring Functions
monitor_disk_usage() {
    local threshold=${1:-80}
    local partitions=()
    
    while IFS= read -r line; do
        local usage
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        
        if [[ $usage -gt $threshold ]]; then
            partitions+=("$line")
        fi
    done < <(df -h | grep '^/')
    
    if [[ ${#partitions[@]} -gt 0 ]]; then
        log_warn "Disk usage above threshold" "threshold=$threshold%"
        printf '%s\n' "${partitions[@]}"
        return 1
    fi
    
    return 0
}

# Backup Functions
backup_directory() {
    local source_dir=$1
    local backup_dir=$2
    local backup_name=${3:-"backup"}
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/${backup_name}_${timestamp}.tar.gz"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create backup
    tar czf "$backup_path" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"
    
    # Verify backup
    if tar tzf "$backup_path" >/dev/null; then
        log_info "Backup created successfully" "path=$backup_path"
        echo "$backup_path"
    else
        log_error "Backup verification failed" "path=$backup_path"
        rm -f "$backup_path"
        return 1
    fi
}
```

### Infrastructure Automation Library

```bash
#!/bin/bash
# lib/infrastructure.sh - Infrastructure automation functions

# Function: Deploy application stack
deploy_stack() {
    local stack_name=$1
    local environment=$2
    local version=$3
    
    log_info "Deploying stack" "name=$stack_name" "env=$environment" "version=$version"
    
    # Pre-deployment checks
    check_prerequisites "$environment" || return 1
    
    # Build and push images
    build_and_push_images "$version" || return 1
    
    # Update infrastructure
    update_infrastructure "$stack_name" "$environment" || return 1
    
    # Deploy application
    deploy_application "$stack_name" "$environment" "$version" || return 1
    
    # Run health checks
    run_health_checks "$stack_name" "$environment" || return 1
    
    log_info "Stack deployment completed successfully"
}

# Function: Blue-green deployment
blue_green_deploy() {
    local service_name=$1
    local new_version=$2
    local rollback_on_failure=${3:-true}
    
    log_info "Starting blue-green deployment" "service=$service_name" "version=$new_version"
    
    # Identify current environment
    local current_env
    current_env=$(get_active_environment "$service_name")
    local new_env=$([[ "$current_env" == "blue" ]] && echo "green" || echo "blue")
    
    # Deploy to inactive environment
    log_info "Deploying to $new_env environment"
    deploy_to_environment "$service_name" "$new_env" "$new_version" || {
        log_error "Deployment to $new_env failed"
        return 1
    }
    
    # Run smoke tests
    log_info "Running smoke tests on $new_env"
    run_smoke_tests "$service_name" "$new_env" || {
        log_error "Smoke tests failed"
        if [[ "$rollback_on_failure" == "true" ]]; then
            cleanup_environment "$service_name" "$new_env"
        fi
        return 1
    }
    
    # Switch traffic
    log_info "Switching traffic to $new_env"
    switch_traffic "$service_name" "$new_env" || {
        log_error "Traffic switch failed"
        if [[ "$rollback_on_failure" == "true" ]]; then
            rollback_deployment "$service_name" "$current_env"
        fi
        return 1
    }
    
    log_info "Blue-green deployment completed successfully"
}

# Function: Canary deployment
canary_deploy() {
    local service_name=$1
    local new_version=$2
    local canary_percentage=${3:-10}
    local canary_duration=${4:-300}
    
    log_info "Starting canary deployment" \
        "service=$service_name" \
        "version=$new_version" \
        "percentage=$canary_percentage"
    
    # Deploy canary version
    deploy_canary "$service_name" "$new_version" "$canary_percentage" || return 1
    
    # Monitor canary
    log_info "Monitoring canary for ${canary_duration}s"
    monitor_canary "$service_name" "$canary_duration" || {
        log_error "Canary monitoring detected issues"
        rollback_canary "$service_name"
        return 1
    }
    
    # Gradual rollout
    local percentages=(25 50 75 100)
    for percentage in "${percentages[@]}"; do
        log_info "Increasing traffic to $percentage%"
        adjust_canary_traffic "$service_name" "$percentage" || {
            log_error "Failed to adjust traffic to $percentage%"
            rollback_canary "$service_name"
            return 1
        }
        
        # Brief monitoring period
        sleep 60
        
        # Check metrics
        check_canary_metrics "$service_name" || {
            log_error "Metrics check failed at $percentage%"
            rollback_canary "$service_name"
            return 1
        }
    done
    
    log_info "Canary deployment completed successfully"
}

# Function: Zero-downtime database migration
zero_downtime_migration() {
    local db_name=$1
    local migration_script=$2
    local rollback_script=$3
    
    log_info "Starting zero-downtime migration" "database=$db_name"
    
    # Create backup
    local backup_file
    backup_file=$(backup_database "$db_name") || return 1
    
    # Run pre-migration checks
    pre_migration_checks "$db_name" || return 1
    
    # Execute migration
    log_info "Executing migration script"
    execute_migration "$db_name" "$migration_script" || {
        log_error "Migration failed, initiating rollback"
        rollback_database "$db_name" "$backup_file"
        return 1
    }
    
    # Verify migration
    verify_migration "$db_name" || {
        log_error "Migration verification failed, initiating rollback"
        execute_migration "$db_name" "$rollback_script"
        return 1
    }
    
    log_info "Zero-downtime migration completed successfully"
}
```

## Testing Shell Scripts

### Shell Script Testing Framework

```bash
#!/bin/bash
# lib/testing.sh - Shell script testing framework

# Test suite setup
declare -g TEST_SUITE_NAME=""
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SKIPPED=0

# Function: Initialize test suite
# Usage: test_suite "My Test Suite"
test_suite() {
    TEST_SUITE_NAME="$1"
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0
    
    echo "=== Test Suite: $TEST_SUITE_NAME ==="
    echo "Started at: $(date)"
    echo
}

# Function: Test assertion
# Usage: assert_equals "actual" "expected" "test description"
assert_equals() {
    local actual=$1
    local expected=$2
    local description=${3:-"Test"}
    
    if [[ "$actual" == "$expected" ]]; then
        echo "✓ PASS: $description"
        ((TEST_PASSED++))
    else
        echo "✗ FAIL: $description"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        ((TEST_FAILED++))
    fi
}

# Function: Assert command success
# Usage: assert_success command args...
assert_success() {
    local description=${1:-"Command should succeed"}
    shift
    
    if "$@"; then
        echo "✓ PASS: $description"
        ((TEST_PASSED++))
    else
        echo "✗ FAIL: $description"
        echo "  Command: $*"
        echo "  Exit code: $?"
        ((TEST_FAILED++))
    fi
}

# Function: Assert command failure
# Usage: assert_failure command args...
assert_failure() {
    local description=${1:-"Command should fail"}
    shift
    
    if ! "$@"; then
        echo "✓ PASS: $description"
        ((TEST_PASSED++))
    else
        echo "✗ FAIL: $description"
        echo "  Command: $*"
        echo "  Expected failure but succeeded"
        ((TEST_FAILED++))
    fi
}

# Function: Assert output contains
# Usage: assert_contains "$(command)" "expected substring"
assert_contains() {
    local output=$1
    local substring=$2
    local description=${3:-"Output should contain substring"}
    
    if [[ "$output" == *"$substring"* ]]; then
        echo "✓ PASS: $description"
        ((TEST_PASSED++))
    else
        echo "✗ FAIL: $description"
        echo "  Output: '$output'"
        echo "  Should contain: '$substring'"
        ((TEST_FAILED++))
    fi
}

# Function: Skip test
# Usage: skip_test "reason"
skip_test() {
    local reason=$1
    echo "- SKIP: $reason"
    ((TEST_SKIPPED++))
}

# Function: Test fixture setup
# Usage: setup() { ... }
setup() {
    :  # Override in test files
}

# Function: Test fixture teardown
# Usage: teardown() { ... }
teardown() {
    :  # Override in test files
}

# Function: Run test
# Usage: run_test test_function_name
run_test() {
    local test_name=$1
    
    echo "--- Test: $test_name ---"
    
    # Run setup
    setup
    
    # Run test
    "$test_name"
    
    # Run teardown
    teardown
    
    echo
}

# Function: Test suite summary
# Usage: test_summary
test_summary() {
    echo "=== Test Summary ==="
    echo "Passed:  $TEST_PASSED"
    echo "Failed:  $TEST_FAILED"
    echo "Skipped: $TEST_SKIPPED"
    echo "Total:   $((TEST_PASSED + TEST_FAILED + TEST_SKIPPED))"
    echo
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        echo "All tests passed! ✓"
        return 0
    else
        echo "Some tests failed! ✗"
        return 1
    fi
}

# Function: Mock command
# Usage: mock_command original_command mock_function
mock_command() {
    local original_command=$1
    local mock_function=$2
    
    # Create temporary function with original command name
    eval "${original_command}() { ${mock_function} \"\$@\"; }"
    
    # Export the function
    export -f "$original_command"
}

# Function: Restore mocked command
# Usage: restore_command command_name
restore_command() {
    local command_name=$1
    unset -f "$command_name"
}
```

### Example Test File

```bash
#!/bin/bash
# tests/test_deployment.sh - Example test file

source "$(dirname "$0")/../lib/testing.sh"
source "$(dirname "$0")/../lib/devops.sh"

# Test fixtures
setup() {
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || exit 1
}

teardown() {
    # Cleanup
    cd / || exit 1
    rm -rf "$TEST_DIR"
}

# Test functions
test_git_current_branch() {
    # Mock git command
    mock_command git 'echo "main"'
    
    local branch
    branch=$(git_current_branch)
    
    assert_equals "$branch" "main" "Should return current git branch"
    
    restore_command git
}

test_docker_build() {
    # Mock docker command
    mock_command docker 'echo "Building image: $*"'
    
    local output
    output=$(docker_build Dockerfile test-image "ARG1=value1")
    
    assert_contains "$output" "Building image" "Should call docker build"
    assert_contains "$output" "test-image" "Should include image name"
    assert_contains "$output" "ARG1=value1" "Should include build args"
    
    restore_command docker
}

test_health_check_http() {
    # Mock curl for successful response
    mock_command curl 'echo "200"'
    
    assert_success "HTTP health check should pass" \
        health_check_http "http://example.com" 200
    
    # Mock curl for failed response
    mock_command curl 'echo "500"'
    
    assert_failure "HTTP health check should fail" \
        health_check_http "http://example.com" 200
    
    restore_command curl
}

test_backup_directory() {
    # Create test directory structure
    mkdir -p test_source/{dir1,dir2}
    touch test_source/file1.txt
    touch test_source/dir1/file2.txt
    
    # Create backup
    local backup_path
    backup_path=$(backup_directory test_source backups test_backup)
    
    assert_success "Backup should be created" test -f "$backup_path"
    
    # Verify backup contents
    local contents
    contents=$(tar tzf "$backup_path")
    assert_contains "$contents" "file1.txt" "Backup should contain file1.txt"
    assert_contains "$contents" "dir1/file2.txt" "Backup should contain nested file"
}

# Run tests
main() {
    test_suite "Deployment Functions Test Suite"
    
    run_test test_git_current_branch
    run_test test_docker_build
    run_test test_health_check_http
    run_test test_backup_directory
    
    test_summary
}

main
```

## Script Packaging and Distribution

### Package Structure

```bash
#!/bin/bash
# scripts/package.sh - Package scripts for distribution

# Package structure:
# devops-scripts/
# ├── bin/              # Executable scripts
# ├── lib/              # Library functions
# ├── conf/             # Configuration files
# ├── docs/             # Documentation
# ├── tests/            # Test files
# ├── install.sh        # Installation script
# └── README.md         # Documentation

VERSION=${1:-"1.0.0"}
PACKAGE_NAME="devops-scripts-${VERSION}"

# Create package directory
mkdir -p "${PACKAGE_NAME}"/{bin,lib,conf,docs,tests}

# Copy files
cp -r lib/* "${PACKAGE_NAME}/lib/"
cp -r scripts/* "${PACKAGE_NAME}/bin/"
cp -r tests/* "${PACKAGE_NAME}/tests/"
cp -r conf/* "${PACKAGE_NAME}/conf/"
cp README.md "${PACKAGE_NAME}/"

# Create installation script
cat > "${PACKAGE_NAME}/install.sh" << 'EOF'
#!/bin/bash
# Installation script for DevOps Scripts

INSTALL_DIR="/usr/local/devops-scripts"
BIN_DIR="/usr/local/bin"

# Check permissions
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy files
cp -r lib "$INSTALL_DIR/"
cp -r conf "$INSTALL_DIR/"
chmod +x bin/*

# Install executables
for script in bin/*; do
    script_name=$(basename "$script")
    cp "$script" "$BIN_DIR/$script_name"
    chmod +x "$BIN_DIR/$script_name"
done

# Create configuration directory
mkdir -p /etc/devops-scripts
cp conf/* /etc/devops-scripts/

echo "DevOps Scripts installed successfully!"
echo "Scripts are available in: $BIN_DIR"
echo "Libraries are installed in: $INSTALL_DIR/lib"
echo "Configuration files are in: /etc/devops-scripts"
EOF

chmod +x "${PACKAGE_NAME}/install.sh"

# Create tarball
tar czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}"

# Create checksum
sha256sum "${PACKAGE_NAME}.tar.gz" > "${PACKAGE_NAME}.tar.gz.sha256"

echo "Package created: ${PACKAGE_NAME}.tar.gz"
```

### Script Auto-Update Mechanism

```bash
#!/bin/bash
# scripts/auto-update.sh - Auto-update DevOps scripts

REPO_URL="https://github.com/company/devops-scripts.git"
INSTALL_DIR="/usr/local/devops-scripts"
UPDATE_CHECK_FILE="/var/lib/devops-scripts/last-update"

source "${INSTALL_DIR}/lib/logging.sh"

# Function: Check for updates
check_updates() {
    local current_version
    local remote_version
    
    current_version=$(cat "${INSTALL_DIR}/VERSION")
    remote_version=$(curl -s "${REPO_URL}/raw/main/VERSION")
    
    if [[ "$current_version" != "$remote_version" ]]; then
        log_info "Update available: $current_version -> $remote_version"
        return 0
    else
        log_info "Already on latest version: $current_version"
        return 1
    fi
}

# Function: Download and install update
install_update() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    log_info "Downloading update..."
    git clone --depth 1 "$REPO_URL" "$temp_dir" || {
        log_error "Failed to download update"
        rm -rf "$temp_dir"
        return 1
    }
    
    log_info "Installing update..."
    cd "$temp_dir" || return 1
    ./install.sh || {
        log_error "Failed to install update"
        rm -rf "$temp_dir"
        return 1
    }
    
    rm -rf "$temp_dir"
    log_info "Update completed successfully"
    
    # Update last check time
    mkdir -p "$(dirname "$UPDATE_CHECK_FILE")"
    date > "$UPDATE_CHECK_FILE"
}

# Main
if check_updates; then
    install_update
fi
```

## Real-World DevOps Examples

### Complete Deployment Pipeline Script

```bash
#!/bin/bash
# scripts/deploy-pipeline.sh - Complete deployment pipeline

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/error.sh"
source "$(dirname "$0")/../lib/validation.sh"
source "$(dirname "$0")/../lib/devops.sh"

# Configuration
readonly APP_NAME="${APP_NAME}"
readonly ENVIRONMENT="${ENVIRONMENT}"
readonly VERSION="${VERSION}"
readonly DRY_RUN="${DRY_RUN:-false}"

# Initialize
lib_init
error_setup
log_init --level info --file "/var/log/deployments/${APP_NAME}-${ENVIRONMENT}.log"

# Custom cleanup function
custom_cleanup() {
    log_info "Running deployment cleanup..."
    
    # Cleanup temporary files
    rm -f /tmp/deploy-*
    
    # Notify team
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        local status="completed"
        [[ $ERROR_COUNT -gt 0 ]] && status="failed"
        
        notify_slack "$SLACK_WEBHOOK" \
            "Deployment $status: $APP_NAME v$VERSION to $ENVIRONMENT"
    fi
}

# Function: Validate deployment parameters
validate_deployment() {
    log_info "Validating deployment parameters..."
    
    # Validate required parameters
    assert "[ -n '$APP_NAME' ]" "APP_NAME is required"
    assert "[ -n '$ENVIRONMENT' ]" "ENVIRONMENT is required"
    assert "[ -n '$VERSION' ]" "VERSION is required"
    
    # Validate environment
    validate_string "$ENVIRONMENT" "^(dev|staging|prod)$" "Invalid environment"
    
    # Validate version format
    validate_string "$VERSION" "^[0-9]+\.[0-9]+\.[0-9]+$" "Invalid version format"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_fatal "AWS credentials not configured"
    fi
    
    log_info "Validation completed successfully"
}

# Function: Pre-deployment tasks
pre_deployment() {
    log_info "Running pre-deployment tasks..."
    
    # Create deployment record
    local deployment_id
    deployment_id=$(date +%Y%m%d%H%M%S)
    echo "$deployment_id" > "/tmp/deploy-${APP_NAME}-${ENVIRONMENT}.id"
    
    # Check dependencies
    check_deps "docker" "kubectl" "aws" "jq"
    
    # Backup current deployment
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        backup_current_deployment
    fi
    
    # Run pre-deployment scripts
    if [[ -d "deploy/pre" ]]; then
        for script in deploy/pre/*.sh; do
            log_info "Running pre-deployment script: $script"
            bash "$script" || log_error "Pre-deployment script failed: $script"
        done
    fi
}

# Function: Build and push Docker image
build_and_push() {
    local image_name="${APP_NAME}:${VERSION}"
    local registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    log_info "Building Docker image: $image_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build: docker build -t $image_name ."
        return 0
    fi
    
    # Build image
    docker_build "Dockerfile" "$image_name" \
        "VERSION=$VERSION BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Tag for registry
    docker tag "$image_name" "$registry/$image_name"
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$registry"
    
    # Push image
    docker_push "$image_name" "$registry"
}

# Function: Deploy to Kubernetes
deploy_kubernetes() {
    local manifest="deploy/k8s/${ENVIRONMENT}/${APP_NAME}.yaml"
    
    log_info "Deploying to Kubernetes cluster..."
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Kubernetes manifest not found: $manifest"
        return 1
    fi
    
    # Substitute variables in manifest
    local temp_manifest="/tmp/deploy-manifest-${APP_NAME}.yaml"
    envsubst < "$manifest" > "$temp_manifest"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would apply: kubectl apply -f $temp_manifest"
        cat "$temp_manifest"
        return 0
    fi
    
    # Apply manifest
    kubectl apply -f "$temp_manifest"
    
    # Wait for deployment
    k8s_wait_for_deployment "$APP_NAME" "$ENVIRONMENT" 300
}

# Function: Run deployment tests
run_deployment_tests() {
    log_info "Running deployment tests..."
    
    # Health check
    local health_url="https://${APP_NAME}-${ENVIRONMENT}.example.com/health"
    retry 5 10 health_check_http "$health_url" 200
    
    # Smoke tests
    if [[ -f "tests/smoke.sh" ]]; then
        ENVIRONMENT="$ENVIRONMENT" VERSION="$VERSION" bash tests/smoke.sh
    fi
    
    # Integration tests (non-prod only)
    if [[ "$ENVIRONMENT" != "prod" ]] && [[ -f "tests/integration.sh" ]]; then
        ENVIRONMENT="$ENVIRONMENT" bash tests/integration.sh
    fi
}

# Function: Post-deployment tasks
post_deployment() {
    log_info "Running post-deployment tasks..."
    
    # Update deployment tracking
    local deployment_id
    deployment_id=$(cat "/tmp/deploy-${APP_NAME}-${ENVIRONMENT}.id")
    
    # Tag resources
    aws_tag_resource "deployment/$deployment_id" \
        "app" "$APP_NAME" \
        "environment" "$ENVIRONMENT" \
        "version" "$VERSION" \
        "deployed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    # Clear caches
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        clear_cdn_cache "$APP_NAME"
    fi
    
    # Run post-deployment scripts
    if [[ -d "deploy/post" ]]; then
        for script in deploy/post/*.sh; do
            log_info "Running post-deployment script: $script"
            bash "$script" || log_error "Post-deployment script failed: $script"
        done
    fi
}

# Function: Main deployment flow
main() {
    log_info "Starting deployment" \
        "app=$APP_NAME" \
        "environment=$ENVIRONMENT" \
        "version=$VERSION" \
        "dry_run=$DRY_RUN"
    
    # Deployment steps
    validate_deployment
    pre_deployment
    build_and_push
    deploy_kubernetes
    run_deployment_tests
    post_deployment
    
    log_info "Deployment completed successfully"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            APP_NAME="$2"
            shift 2
            ;;
        --env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Execute deployment
main
```

### Infrastructure Health Check Script

```bash
#!/bin/bash
# scripts/health-checker.sh - Infrastructure health monitoring

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/devops.sh"

# Configuration
readonly CHECK_INTERVAL=${CHECK_INTERVAL:-60}
readonly ALERT_THRESHOLD=${ALERT_THRESHOLD:-3}
readonly CHECKS_CONFIG=${CHECKS_CONFIG:-"/etc/devops-scripts/health-checks.yaml"}

# Health check state
declare -A FAILURE_COUNTS
declare -A LAST_STATES

# Function: Load health check configuration
load_checks() {
    if [[ ! -f "$CHECKS_CONFIG" ]]; then
        log_error "Health checks configuration not found: $CHECKS_CONFIG"
        exit 1
    fi
    
    # Parse YAML configuration
    yq eval -o=j "$CHECKS_CONFIG"
}

# Function: Execute health check
execute_check() {
    local check_name=$1
    local check_type=$2
    local check_config=$3
    
    case "$check_type" in
        http)
            local url endpoint expected_status
            url=$(echo "$check_config" | jq -r '.url')
            endpoint=$(echo "$check_config" | jq -r '.endpoint // ""')
            expected_status=$(echo "$check_config" | jq -r '.expected_status // 200')
            
            health_check_http "${url}${endpoint}" "$expected_status"
            ;;
        
        tcp)
            local host port timeout
            host=$(echo "$check_config" | jq -r '.host')
            port=$(echo "$check_config" | jq -r '.port')
            timeout=$(echo "$check_config" | jq -r '.timeout // 5')
            
            timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
            ;;
        
        process)
            local process_name
            process_name=$(echo "$check_config" | jq -r '.name')
            
            pgrep -x "$process_name" >/dev/null
            ;;
        
        disk_space)
            local path threshold
            path=$(echo "$check_config" | jq -r '.path // "/"')
            threshold=$(echo "$check_config" | jq -r '.threshold // 80')
            
            local usage
            usage=$(df "$path" | awk 'NR==2 {print $5}' | tr -d '%')
            [[ $usage -lt $threshold ]]
            ;;
        
        custom)
            local script
            script=$(echo "$check_config" | jq -r '.script')
            
            bash "$script"
            ;;
        
        *)
            log_error "Unknown check type: $check_type"
            return 1
            ;;
    esac
}

# Function: Handle check result
handle_check_result() {
    local check_name=$1
    local result=$2
    
    # Update state
    local previous_state=${LAST_STATES[$check_name]:-"unknown"}
    LAST_STATES[$check_name]=$result
    
    if [[ $result -eq 0 ]]; then
        # Check passed
        FAILURE_COUNTS[$check_name]=0
        
        if [[ "$previous_state" != "0" ]]; then
            log_info "Health check recovered: $check_name"
            send_alert "$check_name" "recovered"
        fi
    else
        # Check failed
        FAILURE_COUNTS[$check_name]=$((${FAILURE_COUNTS[$check_name]:-0} + 1))
        
        log_warn "Health check failed: $check_name" \
            "consecutive_failures=${FAILURE_COUNTS[$check_name]}"
        
        # Send alert if threshold reached
        if [[ ${FAILURE_COUNTS[$check_name]} -ge $ALERT_THRESHOLD ]]; then
            send_alert "$check_name" "failed" "${FAILURE_COUNTS[$check_name]}"
        fi
    fi
}

# Function: Send alert
send_alert() {
    local check_name=$1
    local status=$2
    local failure_count=${3:-0}
    
    local message="Health check $check_name $status"
    if [[ $failure_count -gt 0 ]]; then
        message+=" (failed $failure_count times)"
    fi
    
    # Send Slack notification
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        notify_slack "$SLACK_WEBHOOK" "$message"
    fi
    
    # Send email alert
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "$message" | mail -s "Health Check Alert: $check_name" "$ALERT_EMAIL"
    fi
    
    # Execute custom alert handler
    if [[ -f "/etc/devops-scripts/alert-handler.sh" ]]; then
        bash /etc/devops-scripts/alert-handler.sh "$check_name" "$status" "$failure_count"
    fi
}

# Function: Run health checks
run_checks() {
    local checks
    checks=$(load_checks)
    
    echo "$checks" | jq -c '.checks[]' | while read -r check; do
        local name type enabled config
        name=$(echo "$check" | jq -r '.name')
        type=$(echo "$check" | jq -r '.type')
        enabled=$(echo "$check" | jq -r '.enabled // true')
        config=$(echo "$check" | jq -c '.config')
        
        if [[ "$enabled" != "true" ]]; then
            continue
        fi
        
        log_debug "Running health check: $name"
        
        if execute_check "$name" "$type" "$config"; then
            handle_check_result "$name" 0
        else
            handle_check_result "$name" 1
        fi
    done
}

# Function: Main monitoring loop
main() {
    log_info "Starting health monitoring" "interval=${CHECK_INTERVAL}s"
    
    # Main loop
    while true; do
        run_checks
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
trap 'log_info "Health monitoring stopped"; exit 0' SIGTERM SIGINT

# Start monitoring
main
```

### CI/CD Integration Script

```bash
#!/bin/bash
# scripts/cicd-integration.sh - CI/CD pipeline integration

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/validation.sh"
source "$(dirname "$0")/../lib/devops.sh"

# CI/CD Environment Detection
detect_ci_environment() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github"
    elif [[ -n "${GITLAB_CI:-}" ]]; then
        echo "gitlab"
    elif [[ -n "${JENKINS_URL:-}" ]]; then
        echo "jenkins"
    elif [[ -n "${CIRCLECI:-}" ]]; then
        echo "circleci"
    elif [[ -n "${TRAVIS:-}" ]]; then
        echo "travis"
    else
        echo "unknown"
    fi
}

# Extract CI/CD metadata
get_ci_metadata() {
    local ci_env
    ci_env=$(detect_ci_environment)
    
    case "$ci_env" in
        github)
            cat <<EOF
{
    "ci_env": "github",
    "build_id": "${GITHUB_RUN_ID}",
    "build_number": "${GITHUB_RUN_NUMBER}",
    "commit": "${GITHUB_SHA}",
    "branch": "${GITHUB_REF#refs/heads/}",
    "pr_number": "${GITHUB_EVENT_NAME:-}",
    "actor": "${GITHUB_ACTOR}",
    "repository": "${GITHUB_REPOSITORY}"
}
EOF
            ;;
        gitlab)
            cat <<EOF
{
    "ci_env": "gitlab",
    "build_id": "${CI_PIPELINE_ID}",
    "build_number": "${CI_PIPELINE_IID}",
    "commit": "${CI_COMMIT_SHA}",
    "branch": "${CI_COMMIT_REF_NAME}",
    "tag": "${CI_COMMIT_TAG:-}",
    "actor": "${GITLAB_USER_LOGIN}",
    "repository": "${CI_PROJECT_PATH}"
}
EOF
            ;;
        jenkins)
            cat <<EOF
{
    "ci_env": "jenkins",
    "build_id": "${BUILD_ID}",
    "build_number": "${BUILD_NUMBER}",
    "commit": "${GIT_COMMIT}",
    "branch": "${GIT_BRANCH}",
    "job_name": "${JOB_NAME}",
    "workspace": "${WORKSPACE}"
}
EOF
            ;;
        *)
            cat <<EOF
{
    "ci_env": "unknown",
    "build_id": "local-$(date +%s)",
    "build_number": "0",
    "commit": "$(git rev-parse HEAD)",
    "branch": "$(git rev-parse --abbrev-ref HEAD)",
    "actor": "$(whoami)",
    "repository": "$(basename "$(git rev-parse --show-toplevel)")"
}
EOF
            ;;
    esac
}

# CI/CD specific setup
setup_ci_environment() {
    local ci_env
    ci_env=$(detect_ci_environment)
    
    log_info "Setting up CI environment: $ci_env"
    
    case "$ci_env" in
        github)
            # Configure GitHub Actions
            echo "::group::Environment Setup"
            
            # Set outputs
            echo "build_id=${GITHUB_RUN_ID}" >> "$GITHUB_OUTPUT"
            echo "commit_short=$(git rev-parse --short HEAD)" >> "$GITHUB_OUTPUT"
            
            echo "::endgroup::"
            ;;
        
        gitlab)
            # Configure GitLab CI
            echo -e "\e[0Ksection_start:$(date +%s):setup_env\r\e[0KEnvironment Setup"
            
            # GitLab specific setup
            export DOCKER_HOST="${DOCKER_HOST:-tcp://docker:2375/}"
            
            echo -e "\e[0Ksection_end:$(date +%s):setup_env\r\e[0K"
            ;;
        
        jenkins)
            # Configure Jenkins
            echo "Environment Setup for Jenkins"
            
            # Set build description
            currentBuild.description = "Commit: ${GIT_COMMIT:0:7}"
            ;;
    esac
    
    # Common setup
    export CI=true
    export TERM=xterm-256color
}

# Build status reporting
report_build_status() {
    local status=$1
    local description=${2:-"Build ${status}"}
    local ci_env
    ci_env=$(detect_ci_environment)
    
    case "$ci_env" in
        github)
            # Create GitHub commit status
            if [[ -n "${GITHUB_TOKEN:-}" ]]; then
                curl -X POST \
                    -H "Authorization: token ${GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/${GITHUB_REPOSITORY}/statuses/${GITHUB_SHA}" \
                    -d "{\"state\": \"${status}\", \"description\": \"${description}\", \"context\": \"ci/build\"}"
            fi
            ;;
        
        gitlab)
            # GitLab commit status is handled automatically
            case "$status" in
                success) exit 0 ;;
                failure) exit 1 ;;
                pending) ;; # No action needed
            esac
            ;;
        
        jenkins)
            # Update Jenkins build status
            case "$status" in
                success) currentBuild.result = 'SUCCESS' ;;
                failure) currentBuild.result = 'FAILURE' ;;
                pending) currentBuild.result = 'UNSTABLE' ;;
            esac
            ;;
    esac
}

# Artifact handling
handle_artifacts() {
    local artifact_path=$1
    local artifact_name=$2
    local ci_env
    ci_env=$(detect_ci_environment)
    
    log_info "Handling artifacts" "path=$artifact_path" "name=$artifact_name"
    
    case "$ci_env" in
        github)
            # Upload to GitHub Actions artifacts
            echo "::group::Upload Artifacts"
            echo "Uploading $artifact_name from $artifact_path"
            echo "::endgroup::"
            ;;
        
        gitlab)
            # GitLab artifacts are handled in .gitlab-ci.yml
            # But we can create artifact metadata
            cat > "$artifact_path.json" <<EOF
{
    "name": "$artifact_name",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "size": $(stat -f%z "$artifact_path" 2>/dev/null || stat -c%s "$artifact_path"),
    "sha256": "$(sha256sum "$artifact_path" | cut -d' ' -f1)"
}
EOF
            ;;
        
        jenkins)
            # Archive artifacts in Jenkins
            echo "Archiving artifact: $artifact_name"
            ;;
    esac
}

# Main CI/CD workflow
main() {
    local command=${1:-"build"}
    
    # Setup CI environment
    setup_ci_environment
    
    # Get CI metadata
    local metadata
    metadata=$(get_ci_metadata)
    log_info "CI/CD metadata" "data=$metadata"
    
    # Report initial status
    report_build_status "pending" "Build started"
    
    # Execute command
    case "$command" in
        build)
            log_info "Running build"
            make build || {
                report_build_status "failure" "Build failed"
                exit 1
            }
            ;;
        
        test)
            log_info "Running tests"
            make test || {
                report_build_status "failure" "Tests failed"
                exit 1
            }
            ;;
        
        deploy)
            log_info "Running deployment"
            ./scripts/deploy-pipeline.sh \
                --app "${APP_NAME}" \
                --env "${ENVIRONMENT}" \
                --version "${VERSION}" || {
                report_build_status "failure" "Deployment failed"
                exit 1
            }
            ;;
        
        *)
            log_error "Unknown command: $command"
            report_build_status "failure" "Unknown command"
            exit 1
            ;;
    esac
    
    # Handle artifacts
    if [[ -d "artifacts" ]]; then
        for artifact in artifacts/*; do
            handle_artifacts "$artifact" "$(basename "$artifact")"
        done
    fi
    
    # Report success
    report_build_status "success" "Build completed successfully"
}

# Execute
main "$@"
```

## 
# ${var-default} - Use default only if var is unset (not if empty)
# ${variable:-default} - Use default if variable is unset or empty
# ${var:=default} - Assign default to var if unset/empty
# ${var+replacement} - Use replacement if var is set
# ${var:?error message} - Display error if var is unset/empty
## Conclusion

This comprehensive guide covers advanced shell scripting techniques specifically tailored for DevOps automation:

1. **Advanced Functions and Libraries** - Modular, reusable code with sophisticated parameter handling
2. **Robust Error Handling** - Complete error handling framework with stack traces and custom handlers
3. **Input Validation** - Comprehensive validation for various data types and security considerations
4. **Logging and Debugging** - Professional logging system with structured output and debugging capabilities
5. **Integration with Terraform** - Scripts for external data sources, provisioners, and null resources
6. **Integration with Python** - Seamless Python-Shell integration for complex automation
7. **DevOps Script Library** - Reusable functions for common DevOps tasks
8. **Testing Framework** - Complete testing framework for shell scripts
9. **Packaging and Distribution** - Professional script packaging and auto-update mechanisms
10. **Real-World Examples** - Production-ready deployment pipelines and monitoring scripts

These advanced techniques enable you to build robust, maintainable, and professional-grade shell scripts for DevOps automation that can seamlessly integrate with modern infrastructure tools like Terraform and Python.
