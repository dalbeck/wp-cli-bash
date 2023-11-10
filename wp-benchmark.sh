#!/bin/bash

# Define output directory
OUTPUT_DIR="wp-benchmarks"

# Define the URL of the Code Profiler Pro plugin zip file
PLUGIN_URL="https://code-profiler.com/pro/?action=d&l=335ED-56FA7-941EC-65BDD-4E61B-95ECB"
CODE_PROFILER_PROLICENSE_KEY="335ED-56FA7-941EC-65BDD-4E61B-95ECB"

# Create the directory if it does not exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir "$OUTPUT_DIR"
fi

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

# Check if Code Profiler Pro plugin is installed and active
if ! wp plugin is-installed code-profiler-pro --allow-root; then
    echo "Installing Code Profiler Pro plugin from $PLUGIN_URL..."
    wp plugin install $PLUGIN_URL --activate --allow-root
    echo "Setting license for Code Profiler Pro..."
    wp code-profiler-pro license $CODE_PROFILER_PROLICENSE_KEY --allow-root
else
    if ! wp plugin is-active code-profiler-pro --allow-root; then
        echo "Activating Code Profiler Pro plugin..."
        wp plugin activate code-profiler-pro --allow-root
    fi
fi

# Install WP CLI Profile command
install_wp_cli_package "wp-cli/profile-command" "wp package install wp-cli/profile-command:@stable"

# Install WP CLI Doctor command
install_wp_cli_package "wp-cli/doctor-command" "wp package install wp-cli/doctor-command:@stable"

# Run Code Profiler Pro and output to TXT in the wp-benchmarks directory
{
    echo "Running Code Profiler Pro..."
    wp code-profiler-pro run
} > "$OUTPUT_DIR/code-profiler-pro-results.txt"

# Run WP CLI Profile and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Profile..."
    wp profile stage --all --orderby=time --allow-root
} > "$OUTPUT_DIR/profile-stage-results.csv"

# Additional WP CLI Profile commands with output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Profile stage bootstrap..."
    wp profile stage bootstrap --fields=hook,time,cache_ratio --spotlight --orderby=time --allow-root
} > "$OUTPUT_DIR/profile-stage-bootstrap-results.csv"

{
    echo "Running WP CLI Profile hook init..."
    wp profile hook init --orderby=query_time --allow-root
} > "$OUTPUT_DIR/profile-hook-init-results.csv"

{
    echo "Running WP CLI Profile hook wp_loaded:after..."
    wp profile hook wp_loaded:after --orderby=query_time --allow-root
} > "$OUTPUT_DIR/profile-hook-wp-loaded-after-results.csv"

# Run WP CLI Doctor Check cron-count and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check cron-count..."
    wp doctor check cron-count --allow-root
} > "$OUTPUT_DIR/doctor-check-cron-count-results.csv"

# Run WP CLI Doctor Check autoload-options-size and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check autoload-options-size..."
    wp doctor check autoload-options-size --allow-root
} > "$OUTPUT_DIR/doctor-check-autoload-options-size-results.csv"

# Run WP DB query and output largest autoloaded rows to CSV in the wp-benchmarks directory
{
    echo "Running WP DB Query for Largest Autoloaded Data Rows..."
    wp db query "SELECT 'autoloaded data in KiB' as name, ROUND(SUM(LENGTH(option_value))/ 1024) as value FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION SELECT 'autoloaded data count', count(*) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION (SELECT option_name, length(option_value) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' ORDER BY length(option_value) DESC LIMIT 10)"
} > "$OUTPUT_DIR/db-query-autoloaded-data-results.csv"

# Run WP CLI Doctor Check --all and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check --all..."
    wp doctor check --all --allow-root
} > "$OUTPUT_DIR/doctor-check-all-results.csv"

echo "All tasks completed. Check the $OUTPUT_DIR directory for results."

# Force stop the script
exit 0
