#!/bin/bash

# Introductory line
echo "====== Profiling Scripts Starting Now ======"

# Define output directory
OUTPUT_DIR="wp-benchmarks"

# Define the URL of the Code Profiler Pro plugin zip file
PLUGIN_URL="https://code-profiler.com/pro/?action=d&l=335ED-56FA7-941EC-65BDD-4E61B-95ECB"
CODE_PROFILER_PROLICENSE_KEY="335ED-56FA7-941EC-65BDD-4E61B-95ECB"

# Trap to catch unexpected exits
trap 'echo "Script exited unexpectedly. Last command at line $LINENO failed."' EXIT

# Create the directory if it does not exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir "$OUTPUT_DIR"
fi

# Redirect standard error to a file
exec 2> "$OUTPUT_DIR/error.txt"

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
        echo "> $PACKAGE_NAME is already installed."
    fi
}

# Check if Code Profiler Pro plugin is installed and active
if ! wp plugin is-installed code-profiler-pro --allow-root; then
    echo "Installing Code Profiler Pro plugin..."
    timeout 180 wp plugin install $PLUGIN_URL --allow-root
    if wp plugin is-installed code-profiler-pro --allow-root; then
        echo "Plugin installed successfully, now activating..."
        wp plugin activate code-profiler-pro --allow-root
    else
        echo "Failed to install Code Profiler Pro plugin within the time limit."
        exit 1
    fi
fi

if ! wp plugin is-active code-profiler-pro --allow-root; then
    echo "Activating Code Profiler Pro plugin..."
    wp plugin activate code-profiler-pro --allow-root
fi

echo "Setting license for Code Profiler Pro..."
timeout 180 wp code-profiler-pro license $CODE_PROFILER_PRO_LICENSE_KEY --allow-root &
wait $!
echo "License set for Code Profiler Pro."

# Install WP CLI Profile command
install_wp_cli_package "wp-cli/profile-command" "wp package install wp-cli/profile-command:@stable"

# Install WP CLI Doctor command
install_wp_cli_package "wp-cli/doctor-command" "wp package install wp-cli/doctor-command:@stable"

# Run Code Profiler Pro and output to TXT in the wp-benchmarks directory
{
    echo "Running Code Profiler Pro..."
    wp code-profiler-pro run
} > "$OUTPUT_DIR/code-profiler-pro-results.txt"
echo "> Code Profiler Pro completed."

# Run WP CLI Profile and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Profile..."
    wp profile stage --all --orderby=time --allow-root
} > "$OUTPUT_DIR/profile-stage-results.csv"
echo "> WP CLI Profile stage completed."

# Additional WP CLI Profile commands with output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Profile stage bootstrap..."
    wp profile stage bootstrap --fields=hook,time,cache_ratio --spotlight --orderby=time --allow-root
} > "$OUTPUT_DIR/profile-stage-bootstrap-results.csv"
echo "> WP CLI Profile stage bootstrap completed."

{
    echo "Running WP CLI Profile hook init..."
    wp profile hook init --orderby=query_time --allow-root
} > "$OUTPUT_DIR/profile-hook-init-results.csv"
echo "> WP CLI Profile hook init completed."

{
    echo "Running WP CLI Profile hook wp_loaded:after..."
    wp profile hook wp_loaded:after --orderby=query_time --allow-root
} > "$OUTPUT_DIR/profile-hook-wp-loaded-after-results.csv"
echo "> WP CLI Profile hook wp_loaded:after completed."

# Run WP CLI Doctor Check cron-count and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check cron-count..."
    wp doctor check cron-count --allow-root
} > "$OUTPUT_DIR/doctor-check-cron-count-results.csv"
echo "> WP CLI Doctor Check cron-count completed."

# Run WP CLI Doctor Check cron-duplicates and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check cron-duplicates..."
    wp doctor check cron-duplicates --allow-root
} > "$OUTPUT_DIR/doctor-check-cron-duplicates-results.csv"
echo "> WP CLI Doctor Check cron-duplicates completed."

# Run WP CLI Doctor Check running crons and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check running crons..."
    wp cron event list --allow-root
} > "$OUTPUT_DIR/doctor-check-cron-active-results.csv"
echo "> WP CLI Doctor Check cron-active completed."

# Run WP CLI Doctor Check active plugin count and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check active plugins..."
    wp doctor check plugin-active-count --allow-root
} > "$OUTPUT_DIR/doctor-check-active-plugins-results.csv"
echo "> WP CLI Doctor Check active plugins count completed."

# Run WP CLI Doctor Check autoload-options-size and output to CSV in the wp-benchmarks directory
{
    echo "Running WP CLI Doctor Check autoload-options-size..."
    wp doctor check autoload-options-size --allow-root
} > "$OUTPUT_DIR/doctor-check-autoload-options-size-results.csv"
echo "> WP CLI Doctor Check autoload-options-size completed."

# Run WP DB query and output largest autoloaded rows to CSV in the wp-benchmarks directory
{
    echo "Running WP DB Query for Largest Autoloaded Data Rows..."
    wp db query "SELECT 'autoloaded data in KiB' as name, ROUND(SUM(LENGTH(option_value))/ 1024) as value FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION SELECT 'autoloaded data count', count(*) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION (SELECT option_name, length(option_value) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' ORDER BY length(option_value) DESC LIMIT 10)"
} > "$OUTPUT_DIR/db-query-autoloaded-data-results.csv"
echo "> WP DB Query for Largest Autoloaded Data Rows completed."

# Run WP CLI Doctor Check --all and output to CSV in the wp-benchmarks directory
echo "Running WP CLI Doctor Check Warning and Errors."
timeout 180 wp doctor check --all --spotlight --allow-root > "$OUTPUT_DIR/doctor-check-all-results.csv"
if [ $? -eq 0 ]; then
    echo "> WP CLI Doctor Check --all completed."
else
    echo "WP CLI Doctor Check --all command failed or timed out."
    exit 1
fi

# Force stop the script
exit 0

# Disabling the trap before the final echo
trap - EXIT

echo "====== All tasks completed. Check the $OUTPUT_DIR directory for results. ======"
