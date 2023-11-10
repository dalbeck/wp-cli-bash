# WP CLI Benchmarking Script

This repository contains a Bash script designed for running various benchmarks and profiling tools on WordPress installations using WP CLI.

## Description

The script automates the following tasks:

- Running the Code Profiler Pro.
- Executing WP CLI Profile stage.
- Performing WP CLI Doctor checks.
- Additional WP CLI Doctor check for cron-count.

## Installation

To use this script:

1. Clone the repository to your local machine.
2. Make sure you have WP CLI installed.
3. Navigate to the root directory of your WordPress installation.
4. Run the script using `./wp-benchmark.sh`.

## Usage

Execute the script within the root directory of your WordPress installation. The script will automatically install necessary WP CLI packages if they are not already installed.

```bash
chmod +x wp-benchmark.sh
./wp-benchmark.sh
