# WP CLI Benchmarking Script with WebPageTest.org Integration

This repository contains a Bash script designed for running various benchmarks and profiling tools on WordPress installations using WP CLI and integrating WebPageTest.org for website performance testing.

## Description

The script automates tasks including:

- Code Profiler Pro execution.
- WP CLI Profile commands (stage, bootstrap, hook init, etc.).
- WP CLI Doctor checks.
- Custom WP DB queries for analyzing autoloaded data.
- Initiating tests on WebPageTest.org and retrieving results.

Outputs are organized in `wp-benchmarks` directory.

## Installation

1. Clone the repository.
2. Ensure WP CLI is installed.
3. Navigate to WordPress root directory.
4. Run `./wp-benchmark.sh`.

## Usage

Execute within the WordPress root directory. The script installs necessary WP CLI packages and creates `wp-benchmarks` for outputs.

```bash
chmod +x wp-benchmark.sh
./wp-benchmark.sh
```

## WebPageTest.org Integration

To use WebPageTest.org:

1. Set `WPT_API_KEY` or enter it when prompted.
2. The script sends requests to WebPageTest.org and monitors test progress.
3. On completion, it provides a URL to detailed performance results.

## Interpreting Profiling Results

- `wp profile` breaks down the WordPress execution process into stages for detailed analysis.
- Look for high `cache_ratio`, more `cache_hits` than `cache_misses`, and low `query_time`.
- Use `grep` for investigating specific hooks.
```bash
grep -rHin "hook_name_here" wp-content/themes
```

This script offers a comprehensive view of WordPress site performance, helping inform optimization strategies.
