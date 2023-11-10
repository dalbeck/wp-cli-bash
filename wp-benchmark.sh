#!/bin/bash

# Check if WP CLI is installed
if ! command -v wp &> /dev/null
then
    echo "WP CLI is not installed. Please install it first."
    exit 1
fi

# Function to install a WP CLI package if it's not already installed
install_wp_cli_package() {
    PACKAGE_NAME=$1
    PACKAGE_INSTALL_COMMAND=$2
    if ! wp package list | grep -q "$PACKAGE_NAME"; then
        echo "Installing $PACKAGE_NAME..."
        $PACKAGE_INSTALL_COMMAND
    else
        echo "$PACKAGE_NAME is already installed."
    fi
}

# Install WP CLI Profile command
install_wp_cli_package "wp-cli/profile-command" "wp package install wp-cli/profile-command:@stable"

# Install WP CLI Doctor command
install_wp_cli_package "wp-cli/doctor-command" "wp package install wp-cli/doctor-command:@stable"

# Run Code Profiler Pro and output to CSV
{
    echo "Running Code Profiler Pro..."
    wp code-profiler-pro run
} > "code-profiler-pro-results.csv"

# Run WP CLI Profile and output to CSV
{
    echo "Running WP CLI Profile..."
    wp profile stage
} > "profile-stage-results.csv"

# Run WP CLI Doctor Check --all and output to CSV
{
    echo "Running WP CLI Doctor Check --all..."
    wp doctor check --all
} > "doctor-check-all-results.csv"

# Run WP CLI Doctor Check cron-count and output to CSV
{
    echo "Running WP CLI Doctor Check cron-count..."
    wp doctor check cron-count
} > "doctor-check-cron-count-results.csv"

echo "All tasks completed. Check the CSV files for results."
