#!/bin/bash

# Set database name
DB_NAME=$(wp config get DB_NAME 2>/dev/null)

# Database Summary
echo "Compiling database summary report..."
echo "Thank you for your patience."

# Fetch WP CLI info
INSTALL_NAME=$(wp option get siteurl 2>/dev/null)
WP_VERSION=$(wp core version 2>/dev/null)
DB_SIZE=$(wp db size --size_format=mb 2>/dev/null)

# Define a format string for printf
STAGE_TWO_FORMAT="%-18s %-10s\t%-18s %-10s\t%-18s %-10s\n"
FORMAT="%-20s %8s\t%-20s %8s\t%-20s %8s\n"

# Convert database size to GB if it exceeds 1024 MB
DB_SIZE_GB=$(awk "BEGIN {printf \"%.2f\", ${DB_SIZE}/1024}")
DB_SIZE_DISPLAY="$DB_SIZE MB"
if [ $(awk "BEGIN {print ($DB_SIZE > 1024)}") -eq 1 ]; then
    DB_SIZE_DISPLAY="$DB_SIZE MB ($DB_SIZE_GB GB)"
fi

# Output summary
echo ""
echo "Database Summary Report:"
echo "Install name:" "$INSTALL_NAME"
echo "Database name:" "$DB_NAME"
echo "Total database size:" "$DB_SIZE_DISPLAY"
echo "WordPress core version:" "$WP_VERSION"

# Tables and Rows Count
# Fetch table and row counts
TABLES_ROWS=$(wp db query "SELECT ENGINE, COUNT(*) AS Total, SUM(TABLE_ROWS) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$DB_NAME' GROUP BY ENGINE;" --skip-column-names 2>/dev/null)

# Parsing logic to extract MyISAM and InnoDB counts
MYISAM_COUNT=$(echo "$TABLES_ROWS" | grep 'MyISAM' | awk '{print $2 " tables: " $3 " rows"}')
INNODB_COUNT=$(echo "$TABLES_ROWS" | grep 'InnoDB' | awk '{print $2 " tables: " $3 " rows"}')
TOTAL_TABLES=$(echo "$TABLES_ROWS" | awk '{total += $2} END {print total}')
TOTAL_ROWS=$(echo "$TABLES_ROWS" | awk '{total += $3} END {print total}')

# Output
echo ""
echo "Tables and Rows counts:"
printf "$STAGE_TWO_FORMAT" "MyISAM tables:" "${MYISAM_TABLES:-0}" "InnoDB tables:" "${INNODB_TABLES:-0}" "Total tables:" "$TOTAL_TABLES"
printf "$STAGE_TWO_FORMAT" "MyISAM rows:" "${MYISAM_ROWS:-0}" "InnoDB Rows:" "${INNODB_ROWS:-0}" "Total rows:" "$TOTAL_ROWS"

# Key Optimization Counts
# Fetch counts
REVISIONS=$(wp post list --post_type='revision' --format=count 2>/dev/null)
TRASHED_POSTS=$(wp post list --post_status='trash' --format=count 2>/dev/null)
ORPHANED_POSTMETA=$(wp db query "SELECT COUNT(*) FROM wp_postmeta pm LEFT JOIN wp_posts wp ON pm.post_id = wp.ID WHERE wp.ID IS NULL;" --skip-column-names 2>/dev/null)
SPAM_COMMENTS=$(wp comment list --status='spam' --format=count 2>/dev/null)
TRASHED_COMMENTS=$(wp comment list --status='trash' --format=count 2>/dev/null)
ORPHANED_COMMENTMETA=$(wp db query "SELECT COUNT(*) FROM wp_commentmeta cm LEFT JOIN wp_comments c ON cm.comment_id = c.comment_ID WHERE c.comment_ID IS NULL;" --skip-column-names 2>/dev/null)
TRANSIENTS=$(wp transient list --format=count 2>/dev/null)

# Output
echo ""

# Header
echo "Key optimization counts:"

# First row of data
printf "$FORMAT" "Revisions:" $REVISIONS "Trashed Posts:" $TRASHED_POSTS "Orphaned Postmeta:" $ORPHANED_POSTMETA

# Second row of data
printf "$FORMAT" "Spam Comments:" $SPAM_COMMENTS "Trashed Comments:" $TRASHED_COMMENTS "Orphaned Commentmeta:" $ORPHANED_COMMENTMETA

# Third row (single column)
printf "%-20s %8s\n" "Transients:" $TRANSIENTS

echo ""

# Autoload Data
# Count total rows in wp_options
TOTAL_OPTIONS=$(wp db query "SELECT COUNT(*) FROM wp_options;" --skip-column-names 2>/dev/null)

# Count autoload rows in wp_options
AUTOLOAD_OPTIONS=$(wp db query "SELECT COUNT(*) FROM wp_options WHERE autoload = 'yes';" --skip-column-names 2>/dev/null)

# Check if autoload is indexed
INDEX_CHECK=$(wp db query "SELECT COUNT(1) IndexIsThere FROM INFORMATION_SCHEMA.STATISTICS WHERE table_schema=DATABASE() AND table_name='wp_options' AND index_name='autoload';" --skip-column-names 2>/dev/null)

# Define ANSI escape codes for colors and bold
RED="\033[31m\033[1m"
GREEN="\033[32m\033[1m"
RESET="\033[0m"

# Determine index status message
COLORED_INDEX_STATUS=""

if [ "$INDEX_CHECK" -eq 1 ]; then
    COLORED_INDEX_STATUS="${GREEN}Success:${RESET} your autoload is indexed!"
else
    COLORED_INDEX_STATUS="${RED}FAIL:${RESET} autoload is not indexed!"
fi

# Output for Autoload / Total rows and index check
echo ""
echo "Autoload / Total rows in wp_options:"
printf "%s / %s\n" "$AUTOLOAD_OPTIONS" "$TOTAL_OPTIONS"
echo -e "$COLORED_INDEX_STATUS"

# Fetch top 5 Autoload data
AUTOLOAD_DATA=$(wp db query "SELECT option_name, LENGTH(option_value) AS size FROM wp_options WHERE autoload='yes' ORDER BY size DESC LIMIT 5;" --skip-column-names 2>/dev/null)

# Output for top 5 Autoload items
echo ""
echo "Top 5 Autoload items from wp_options:"
echo "+---------------+------------------------------------+"
echo "| Size in bytes | option_name                        |"
echo "+---------------+------------------------------------+"
echo "$AUTOLOAD_DATA" | awk '{printf "| %13s | %-34s |\n", $2, $1}'
echo "+---------------+------------------------------------+"


# Top 20 InnoDB Database Tables
# Fetch top 20 InnoDB tables
TOP_TABLES=$(wp db query "SELECT TABLE_NAME, TABLE_ROWS, DATA_LENGTH, INDEX_LENGTH, round(((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024), 2) AS Total_size_MB FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$DB_NAME' AND ENGINE='InnoDB' ORDER BY TABLE_ROWS DESC LIMIT 20;" --skip-column-names 2>/dev/null)

# Output
# Fetch top 20 InnoDB tables
TOP_TABLES=$(wp db query "SELECT TABLE_NAME, 'InnoDB' AS Engine, TABLE_ROWS, round(DATA_LENGTH / 1024 / 1024, 2) AS Data_size_in_MB, round(INDEX_LENGTH / 1024 / 1024, 2) AS Index_size_in_MB, round((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS Total_size_MB FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$DB_NAME' AND ENGINE='InnoDB' ORDER BY TABLE_ROWS DESC LIMIT 20;" --skip-column-names 2>/dev/null)

# Fetch total autoload data size in bytes
TOTAL_AUTOLOAD_SIZE=$(wp db query "SELECT SUM(LENGTH(option_value)) FROM wp_options WHERE autoload='yes';" --skip-column-names 2>/dev/null)

# Convert to MB for display
TOTAL_AUTOLOAD_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", ${TOTAL_AUTOLOAD_SIZE}/1024/1024}")

# ANSI escape codes for colors and bold
RED="\033[31m\033[1m"
GREEN="\033[32m\033[1m"
RESET="\033[0m"

# Define success and fail messages with color
if [ "$TOTAL_AUTOLOAD_SIZE" -le 921600 ]; then # 900k bytes in decimal
    COLORED_STATUS_MESSAGE="${GREEN}Success: Your autoload data is within reason, under 900k.${RESET}"
else
    COLORED_STATUS_MESSAGE="${RED}FAIL: Your autoload data exceeds the threshold, this is creating a negative impact.${RESET}"
fi

# Output for total autoload data size
echo ""
echo "Total autoload data (in bytes): $TOTAL_AUTOLOAD_SIZE (${TOTAL_AUTOLOAD_SIZE_MB} MB)"
echo -e "$COLORED_STATUS_MESSAGE"


# Output
echo ""
echo "Top 20 InnoDB database tables sorted by table_rows: $DB_NAME"
echo "+----------------------------------+--------+----------+-----------------+------------------+---------------+"
echo "| Table                            | Engine | Rows     | Data_size_in_MB | Index_size_in_MB | Total_size_MB |"
echo "+----------------------------------+--------+----------+-----------------+------------------+---------------+"
echo "$TOP_TABLES" | awk '{printf "| %-32s | %-6s | %8s | %15s | %16s | %13s |\n", $1, $2, $3, $4, $5, $6}'
echo "+----------------------------------+--------+----------+-----------------+------------------+---------------+"
