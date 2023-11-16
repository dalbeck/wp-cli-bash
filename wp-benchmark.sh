#!/bin/bash

echo "========================================================================="
echo "                                                                         "
echo " Welcome to the automated WordPress benchmarking assistant.              "
echo " First, create a label for your test. Then we will set the URL to test.  "
echo " You can profile that URL or run a front-end test with WebPageTest.org.  "
echo " Additionally, you can run a security scan with Wordfence.               "
echo "                                                                         "
echo " Script By: Danny Albeck                                                 "
echo " dalbeck@albeckconsulting.com                                            "
echo "                                                                         "
echo " V1.5.0                                                                  "
echo "                                                                         "
echo "========================================================================="

# Prompt for test label/description
read -p "Enter a label or description for this test set (e.g., Page Name, New code added, etc.): " TEST_LABEL

# Generate a timestamp for the current run
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d-%H%M")

# Define output directory
OUTPUT_DIR="wp-benchmarks"

# Replacing spaces in TEST_LABEL with underscores for directory naming
SAFE_TEST_LABEL=$(echo "$TEST_LABEL" | tr ' ' '_')
# Define the subdirectory using the timestamp
RUN_DIR="$OUTPUT_DIR/$CURRENT_TIMESTAMP-$SAFE_TEST_LABEL"

# Create the directory if it does not exist
if [ ! -d "$RUN_DIR" ]; then
    mkdir -p "$RUN_DIR"
fi

read -p "Would you like to run a security scan with Wordfence? (yes/no) " SECURITY_SCAN

if [ "$SECURITY_SCAN" = "yes" ]; then
    if ! wp package list | grep -q "wp-vulnerability-scanner"; then
        echo "Installing WP-CLI vulnerability scanner..."
        wp package install git@github.com:10up/wp-vulnerability-scanner.git
    fi

    #VULN_API_TOKEN=""
    VULN_API_PROVIDER="wordfence"

    # if [ -z "$VULN_API_TOKEN" ]; then
    #     read -p "Enter your WPScan API token: " VULN_API_TOKEN
    # fi

    # Set the API token
    # if ! grep -q "VULN_API_TOKEN" wp-config.php; then
    #     wp config set VULN_API_TOKEN $VULN_API_TOKEN
    # fi

    # Set the Security Provider
    if ! grep -q "VULN_API_PROVIDER" wp-config.php; then
        wp config set VULN_API_PROVIDER $VULN_API_PROVIDER
    fi

    # Run the security scan
    wp vuln status --allow-root --reference --format=csv > "$RUN_DIR/14-security-results.csv" 2>> "$RUN_DIR/error.txt"
fi

# Prompt for the profiling URL
read -p "What URL do you want to profile? " PROFILING_URL

# New prompt for initiating WebPageTest.org test
read -p "Would you like to initiate a WebPageTest.org test? (yes/no) " WPT_TEST

if [ "$WPT_TEST" = "yes" ]; then

    WPT_API_KEY="e306a8d4-a2ab-42e4-9292-fe03ed7f27fc"

    # Check if WPT_API_KEY is already set
    if [ -z "$WPT_API_KEY" ]; then
        # Prompt for WebPageTest API Key if not set
        read -p "Enter your WebPageTest API key: " WPT_API_KEY
    fi

    # Building the WebPageTest API URL
    WPT_API_URL="https://www.webpagetest.org/runtest.php?url=$PROFILING_URL&k=$WPT_API_KEY&label=$TEST_LABEL&runs=9&video=1&tcpdump=1&timeline=1&htmlbody=1&lighthouse=1&timeline=1&f=json"

    # Sending the request and capturing the response
    WPT_RESPONSE=$(curl -s "$WPT_API_URL")

    # Extract the Test ID from the initial response
    TEST_ID=$(echo $WPT_RESPONSE | grep -o '"testId":"[^"]*' | awk -F\" '{print $4}')

    # Initialize the flag
    firstTime100=true

    # Check test status in a loop
    while true; do
        STATUS_RESPONSE=$(curl -s "https://www.webpagetest.org/testStatus.php?test=$TEST_ID")
        STATUS=$(echo $STATUS_RESPONSE | grep -o '"statusCode":[0-9]*' | head -1 | cut -d: -f2 | tr -d '[:space:]')

        if [[ $STATUS -eq 100 ]]; then
            if [[ $firstTime100 == true ]]; then
                echo "[>] Test has started..."
                firstTime100=false
            else
                echo "[>] Test is in progress..."
            fi
        elif [[ $STATUS -eq 101 ]]; then
            echo "[>] Test is in the queue..."
        elif [[ $STATUS -eq 102 ]]; then
            echo "[>] Test server is currently unreachable..."
        elif [[ $STATUS -eq 200 ]]; then
            # Extract additional details
            LABEL=$(echo $STATUS_RESPONSE | grep -o '"label":"[^"]*' | awk -F\" '{print $4}')
            RUNS=$(echo $STATUS_RESPONSE | grep -o '"runs":[0-9]*' | head -1 | awk -F: '{print $2}')
            LOCATION=$(echo $STATUS_RESPONSE | grep -o '"testInfo":{[^}]*"location":"[^"]*' | sed 's/.*"location":"\([^"]*\).*/\1/')
            CONNECTIVITY=$(echo $STATUS_RESPONSE | grep -o '"connectivity":"[^"]*' | awk -F\" '{print $4}')

            # Fetch and display results URL
            RESULTS_RESPONSE=$(curl -s "https://www.webpagetest.org/jsonResult.php?test=$TEST_ID")
            RESULTS_URL=$(echo $RESULTS_RESPONSE | grep -o '"summary":"[^"]*' | awk -F\" '{print $4}' | sed 's/\\//g')

            echo " "
            echo "========================================================================="
            echo "                                                                         "
            echo "     WebPageTest.org | Test Complete                                     "
            echo "                                                                         "
            echo " Test Name: $LABEL                                                       "
            echo " Number of runs: $RUNS                                                   "
            echo " Test Geo Location: $LOCATION                                            "
            echo " Test Connection Speed: $CONNECTIVITY                                    "
            echo " Test URL: $RESULTS_URL                                                  "
            echo "                                                                         "
            echo "========================================================================="
            echo "                                                                         "

            break
        else
            echo "Error: Test status code $STATUS"
            break
        fi

        sleep 12 # Wait for 12 seconds before checking again
    done

    else
        echo "Skipping WebPageTest.org test."
fi

read -p "Would you like to perform doctor checks on WordPress? (yes/no) " DOCTOR_CHECKS

read -p "Would you like to run Database Checks? (yes/no) " DB_CHECKS

read -p "Would you like to run Profiling Checks? (yes/no) " PROFILING_CHECKS

read -p "Would you like to check MySQL optimizations? (yes/no) " MYSQL_CHECK

if [ "$PROFILING_CHECKS" = "yes" ]; then
    # Introductory line
    echo "========================================================================="
    echo "                                                                         "
    echo "                              Notice                                     "
    echo "     Larger scripts could take longer, or exhaust timeouts/memory.       "
    echo "          --      Profiling Scripts Starting Now       --                "
    echo "                                                                         "
    echo "========================================================================="
    echo " "

    # Define the URL of the Code Profiler Pro plugin zip file
    PLUGIN_URL="https://code-profiler.com/pro/?action=d&l=335ED-56FA7-941EC-65BDD-4E61B-95ECB"
    CODE_PROFILER_PRO_LICENSE_KEY="335ED-56FA7-941EC-65BDD-4E61B-95ECB"

    # Trap to catch unexpected exits
    trap 'echo "Script exited unexpectedly. Last command at line $LINENO failed."' EXIT

    # Redirect standard error to a file
    exec 2> "$RUN_DIR/error.txt"

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
            echo "================================================"
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
        echo "Test: wp code-profiler-pro run"
        wp code-profiler-pro run --dest="$PROFILING_URL"
    } > "$RUN_DIR/01-code-profiler-pro-results.txt"
    echo "[1] Code Profiler Pro completed."

    # Run WP CLI Profile and output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp profile stage"
        wp profile stage --all --orderby=time --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/02-profile-stage-results.csv"

    # Append a comment with the date and a custom message to the CSV file
    {
        echo "Test Name: $TEST_LABEL"
        echo "Notes:"
        echo "This data was captured on $(date)"
        echo "Profiled URL: $PROFILING_URL"
        echo "Your main focus should generally be on the time column. You want your cache_ratio to be high for example, greater than 70%. Generally, you want cache_hits to be greater than cache_misses and, query_time should be low."
    } >> "$RUN_DIR/02-profile-stage-results.csv"

    echo "[2] WP CLI Profile stage completed."

    # Additional WP CLI Profile commands with output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp profile stage bootstrap"
        wp profile stage bootstrap --fields=hook,time,cache_ratio --spotlight --orderby=time --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/03-profile-stage-bootstrap-results.csv"

    # Append a comment with the date and a custom message to the CSV file
    {
        echo "Test Name: $TEST_LABEL"
        echo "Notes:"
        echo "This data was captured on $(date)"
        echo "Profiled URL: $PROFILING_URL"
        echo "bootstrap is where WordPress is setting itself up, loading plugins and the main theme, and firing the init hook. You can dive into hooks for each stage with wp profile stage <stage>"
    } >> "$RUN_DIR/03-profile-stage-bootstrap-results.csv"

    echo "[3] WP CLI Profile stage bootstrap completed."

    # Additional WP CLI Profile commands with output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp profile stage main_query"
        wp profile stage main_query --fields=hook,time,cache_ratio --spotlight --orderby=time --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/04-profile-main_query-results.csv"

    # Append a comment with the date and a custom message to the CSV file
    {
        echo "Test Name: $TEST_LABEL"
        echo "Notes:"
        echo "This data was captured on $(date)"
        echo "Profiled URL: $PROFILING_URL"
        echo "main_query is how WordPress transforms the request (e.g. /about/) into the primary WP_Query. You can dive into hooks for each stage with wp profile stage <stage>"
    } >> "$RUN_DIR/04-profile-main_query-results.csv"

    echo "[4] WP CLI Profile stage main_query completed."

    # Additional WP CLI Profile commands with output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp profile stage template"
        wp profile stage template --fields=hook,time,cache_ratio --spotlight --orderby=time --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/05-profile-template-results.csv"

    # Append a comment with the date and a custom message to the CSV file
    {
        echo "Test Name: $TEST_LABEL"
        echo "Notes:"
        echo "This data was captured on $(date)"
        echo "Profiled URL: $PROFILING_URL"
        echo "template is where WordPress determines which theme template to render based on the main query, and renders it. You can dive into hooks for each stage with wp profile stage <stage>"
    } >> "$RUN_DIR/05-profile-template-results.csv"

    echo "[5] WP CLI Profile stage template completed."

    {
        echo "Test: wp cli profile hook init"
        wp profile hook init --orderby=query_time --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/06-profile-hook-init-results.csv"
    echo "[6] WP CLI Profile hook init completed."

    {
        echo "Test: wp cli profile hook --all --spotlight"
        wp profile hook --all --spotlight --allow-root --format=csv --url="$PROFILING_URL"
    } > "$RUN_DIR/07-profile-hook-all-spotlight-results.csv"

    # Append a comment with the date, the profiling URL, and a custom message to the CSV file
    {
        echo "Test Name: $TEST_LABEL"
        echo "Notes:"
        echo "This data was captured on $(date)"
        echo "Profiled URL: $PROFILING_URL"
        echo "We can check for all hooks in use on a page. If you believe there is a problem with a hook you can run 'grep -ril hook_name_here wp-content/themes'"
    } >> "$RUN_DIR/07-profile-hook-all-spotlight-results.csv"

    echo "[7] WP CLI Profile hook all spotlight completed."

    # Run WP CLI Doctor Check cron-count and output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp cli doctor check cron-count"
        wp doctor check cron-count --allow-root --format=csv
    } > "$RUN_DIR/08-doctor-check-cron-count-results.csv"
    echo "[8] WP CLI Doctor Check cron-count completed."

    # Run WP CLI Doctor Check cron-duplicates and output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp cli doctor check cron-duplicates"
        wp doctor check cron-duplicates --allow-root --format=csv
    } > "$RUN_DIR/09-doctor-check-cron-duplicates-results.csv"
    echo "[9] WP CLI Doctor Check cron-duplicates completed."
fi

if [ "$DOCTOR_CHECKS" = "yes" ]; then
    # Run WP CLI Doctor Check running crons and output to CSV in the wp-benchmarks directory
    {
        echo "Test: wp cron event list"
        wp cron event list --format=csv
    } > "$RUN_DIR/10-check-cron-active-results.csv"
    echo "[10] WP CLI Check Active crons completed."

    # Run WP CLI Doctor Check --all and output to CSV in the wp-benchmarks directory
    echo "[11] Running individual WP CLI Doctor checks. This might take some time for larger sites."

    # Write column headers to the CSV file
    echo "name,status,message" > "$RUN_DIR/11-doctor-check-all-results.csv"

    commands=(
        "autoload-options-size"
        "constant-savequeries-falsy"
        "constant-wp-debug-falsy"
        "core-update"
        "core-verify-checksums"
        "cron-count"
        "cron-duplicates"
        "file-eval"
        "option-blog-public"
        "plugin-active-count"
        "plugin-deactivated"
        "plugin-update"
        "theme-update"
        "cache-flush"
        "php-in-upload"
        "language-update"
    )

    # Loop through each command and append only data rows to the CSV file
    for cmd in "${commands[@]}"
    do
        {
            echo "Running check: $cmd"
            wp doctor check "$cmd" --allow-root --format=csv | tail -n +2
        } >> "$RUN_DIR/11-doctor-check-all-results.csv" 2>> "$RUN_DIR/error.txt"
    done

    echo "[11] WP CLI Doctor individual checks completed."
fi

if [ "$DB_CHECKS" = "yes" ]; then
    # Run WP DB query and output largest autoloaded rows to CSV in the wp-benchmarks directory
    {
        echo "Running WP DB Query for Largest Autoloaded Data Rows..."
        wp db query "SELECT 'autoloaded data in KiB' as name, ROUND(SUM(LENGTH(option_value))/ 1024) as value FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION SELECT 'autoloaded data count', count(*) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' UNION (SELECT option_name, length(option_value) FROM $(wp db prefix --allow-root)options WHERE autoload='yes' ORDER BY length(option_value) DESC LIMIT 10)"
    } > "$RUN_DIR/12-db-query-autoloaded-data-results.csv"
    echo "[12] WP DB Query for Largest Autoloaded Data Rows completed."
    # Run WP DB query to check for orphaned postmeta entries
    {
        echo "Running WP DB Query for Orphaned Postmeta Entries..."
        QUERY_RESULT=$(wp db query "SELECT COUNT(pm.meta_id) as row_count FROM $(wp db prefix --allow-root)postmeta pm LEFT JOIN $(wp db prefix --allow-root)posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;")
        echo "Orphaned postmeta entries: $QUERY_RESULT"
    } > "$RUN_DIR/13-db-query-orphaned-postmeta-results.csv"
    echo "[13] WP DB Query for Orphaned Postmeta Entries completed."
fi

if [ "$MYSQL_CHECK" = "yes" ]; then

    # Define MySQL Tuner directory as the current directory
    MYSQL_TUNER_DIR="$(pwd)/mysqltuner"

    # Define the path for the MySQL Tuner script
    MYSQL_TUNER_PATH="$MYSQL_TUNER_DIR/mysqltuner.pl"

    # Prompt for MySQL credentials
    read -p "Enter MySQL username: " MYSQL_USER
    read -sp "Enter MySQL password: " MYSQL_PASS
    echo

    # Define path for .my.cnf file
    MY_CNF_PATH="$HOME/.my.cnf"

    # Create or update .my.cnf file with credentials
    {
        echo "[client]"
        echo "user=$MYSQL_USER"
        echo "password=$MYSQL_PASS"
    } > "$MY_CNF_PATH"

    # Set file permissions to ensure only the user can read it
    chmod 600 "$MY_CNF_PATH"

    # Create the MySQL Tuner directory if it does not exist
    if [ ! -d "$MYSQL_TUNER_DIR" ]; then
        mkdir -p "$MYSQL_TUNER_DIR"
    fi

    if [ ! -f "$MYSQL_TUNER_PATH" ]; then
        echo "Downloading MySQL Tuner..."

        # Download MySQL Tuner
        wget http://mysqltuner.pl/ -O "$MYSQL_TUNER_PATH"

        # Make the script executable
        chmod +x "$MYSQL_TUNER_PATH"
    else
        echo "MySQL Tuner is already installed."
    fi

    # Define the output file path for MySQL Tuner results in the current run directory
    MYSQL_TUNER_OUTPUT="$RUN_DIR/15-mysql-tuner-results.txt"

    # Run MySQL Tuner and save the output to the specified file
    perl "$MYSQL_TUNER_PATH" --outputfile "$MYSQL_TUNER_OUTPUT" --buffers --dbstat --idxstat --sysstat --pfstat --tbstat 2>> "$RUN_DIR/error.txt"
    echo "MySQL Tuner output saved to $MYSQL_TUNER_OUTPUT."
fi

# Force stop the script
exit 0

# Disabling the trap before the final echo
trap - EXIT

echo "====== All tasks completed. Check the $RUN_DIR directory for results. ======"
