#!/bin/bash
#
# Script 2: If-Else Conditions and Command Line Arguments
# This script teaches: if-else, command line arguments, file tests
#
###### Concepts covered: ######
# Command line arguments ($1, $2, $#)
# If-else statements with multiple conditions
# File tests (-f, -d, -r, -w)
# Default values (${VAR:-default})
# Using grep for searching
# File size checking with stat
# Using awk for memory information
######################################


# $1 -> first argyment
# $2 -> second argument
# $0
# $#

# Check for command line arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename> [search_term]"
    echo "Example: $0 /var/log/syslog error"
    exit 1
fi

# Store command line arguments in variables
FILE="$1"
SEARCH_TERM="${2:-ERROR}"  # Default value if not provided

echo "Analyzing file: $FILE"
echo "Search term: $SEARCH_TERM"

# Check if file exists
if [ -f "$FILE" ]; then
    echo "File exists!"
    
    # Check file size
    FILE_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
    
    if [ "$FILE_SIZE" -gt 1048576 ]; then
        echo "Warning: Large file (>1MB). Size: $FILE_SIZE bytes"
    elif [ "$FILE_SIZE" -eq 0 ]; then
        echo "File is empty!"
        exit 1
    else
        echo "File size: $FILE_SIZE bytes"
    fi
    
    # Search for term in file
    echo -e "\nSearching for '$SEARCH_TERM' in file..."
    if grep -q "$SEARCH_TERM" "$FILE"; then
        echo "Found matches!"
        echo "Number of occurrences: $(grep -c "$SEARCH_TERM" "$FILE")"
        echo -e "\nFirst 5 matches:"
        grep -n "$SEARCH_TERM" "$FILE" | head -5
    else
        echo "No matches found for '$SEARCH_TERM'"
    fi
    
    # Check file permissions
    if [ -r "$FILE" ]; then
        echo -e "\nFile is readable"
    else
        echo -e "\nFile is not readable"
    fi
    
    if [ -w "$FILE" ]; then
        echo "File is writable"
    else
        echo "File is not writable"
    fi
    
elif [ -d "$FILE" ]; then
    echo "Error: '$FILE' is a directory, not a file"
    echo "Contents of directory:"
    ls -la "$FILE" | head -10
else
    echo "Error: File '$FILE' does not exist"
    echo "Searching for similar files..."
    find . -name "*$(basename "$FILE")*" -type f 2>/dev/null | head -5
fi

# Demonstrate nested if statements
echo -e "\nChecking system resources..."
AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%d", $7}')

if [ "$AVAILABLE_MEMORY" -lt 1000 ]; then
    echo "Low memory warning! Available: ${AVAILABLE_MEMORY}MB"
    if [ "$AVAILABLE_MEMORY" -lt 500 ]; then
        echo "CRITICAL: Very low memory!"
    fi
else
    echo "Memory OK. Available: ${AVAILABLE_MEMORY}MB"
fi
