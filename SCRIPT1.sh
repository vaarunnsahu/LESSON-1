#!/bin/bash
#
# Script 1: Basic Variables and User Input
# This script teaches: variables, echo, read, basic commands
#

# Variables - storing values
NAME="DevOps Learner"
CURRENT_DIR=$(pwd)      # Command substitution
DATE=$(date +%Y-%m-%d)  # Formatted date

# Display variables
echo "Welcome, $NAME!"
echo "Current directory: $CURRENT_DIR"
echo "Today's date: $DATE"

# Get user input
echo -e "\nLet's get some information from you..."
read -p "What's your name? " USER_NAME
read -p "What directory do you want to explore? " TARGET_DIR

# Using variables with commands
echo -e "\nHello, $USER_NAME! Let's explore $TARGET_DIR"

# Check if directory exists
if [ -d "$TARGET_DIR" ]; then
    echo "Directory exists! Here's what's inside:"
    ls -la "$TARGET_DIR"
else
    echo "Directory doesn't exist. Let's search for similar directories:"
    find / -type d -name "*${TARGET_DIR}*" 2>/dev/null | head -5
fi

# Using grep to search for files
echo -e "\nLet's search for .txt files in your home directory:"
find ~ -name "*.txt" -type f 2>/dev/null | head -5

# Simple calculations with variables
RANDOM_NUM=$((RANDOM % 100))
echo -e "\nYour lucky number today is: $RANDOM_NUM"
