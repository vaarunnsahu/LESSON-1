#!/bin/bash
#
# Script 3: Loops - For and While
# This script teaches: for loops, while loops, arrays, awk processing
#For loops (different styles)
# While loops
# Arrays in bash
# Reading files line by line
# C-style for loops
# Nested loops
# Loop control with break
# Commands demonstrated: find, wc, pgrep, ps, awk, sort

echo "=== Loop Examples Script ==="

# Simple for loop with list
echo -e "\n1. Checking common directories:"
for dir in /etc /var /usr /opt /tmp; do
    if [ -d "$dir" ]; then
        # Count files in directory
        FILE_COUNT=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
        echo "$dir exists - Contains $FILE_COUNT files"
    else
        echo "$dir does not exist"
    fi
done

# For loop with command substitution
echo -e "\n2. Analyzing .conf files in /etc:"
for config_file in $(find /etc -name "*.conf" 2>/dev/null | head -5); do
    echo "Config file: $config_file"
    echo "  Size: $(stat -f%z "$config_file" 2>/dev/null || stat -c%s "$config_file" 2>/dev/null) bytes"
    echo "  Lines: $(wc -l < "$config_file")"
done

# C-style for loop
echo -e "\n3. Creating test files:"
for ((i=1; i<=5; i++)); do
    TEST_FILE="/tmp/test_file_$i.txt"
    echo "Creating $TEST_FILE"
    echo "This is test file number $i" > "$TEST_FILE"
done

# Array and for loop
echo -e "\n4. Processing an array of services:"
SERVICES=("ssh" "cron" "nginx" "mysql" "redis")
for service in "${SERVICES[@]}"; do
    if pgrep -x "$service" > /dev/null; then
        echo "$service is running (PID: $(pgrep -x "$service" | head -1))"
    else
        echo "$service is not running"
    fi
done

# While loop reading from file
echo -e "\n5. Reading /etc/passwd with while loop:"
echo "First 5 users with /bin/bash shell:"
COUNT=0
while IFS=: read -r username password uid gid gecos home shell; do
    if [ "$shell" = "/bin/bash" ] && [ "$COUNT" -lt 5 ]; then
        echo "User: $username (UID: $uid) - Home: $home"
        ((COUNT++))
    fi
done < /etc/passwd

# While loop with condition
echo -e "\n6. Monitoring disk usage:"
THRESHOLD=80
while true; do
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "Current disk usage: $DISK_USAGE%"
    
    if [ "$DISK_USAGE" -gt "$THRESHOLD" ]; then
        echo "WARNING: Disk usage above $THRESHOLD%!"
    else
        echo "Disk usage is healthy"
    fi
    
    # Break after one check (remove this for continuous monitoring)
    break
    # sleep 60  # Uncomment for continuous monitoring every minute
done

# Nested loops
echo -e "\n7. Finding large files in multiple directories:"
DIRS=("/var/log" "/tmp" "/var/tmp")
SIZE_LIMIT=1048576  # 1MB in bytes

for dir in "${DIRS[@]}"; do
    echo "Checking $dir:"
    find "$dir" -type f -size +${SIZE_LIMIT}c 2>/dev/null | while read -r file; do
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "  Large file: $file ($(( SIZE / 1024 / 1024 )) MB)"
    done
done

# Using awk in a loop
echo -e "\n8. Process information with awk:"
echo "Top 5 CPU consuming processes:"
ps aux | awk 'NR>1 {print $11, $3"%"}' | sort -k2 -rn | head -5 | while read -r process cpu; do
    echo "  Process: $process - CPU: $cpu"
done
