# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive monitoring system that tracks multiple financial markets and OCI infrastructure. The system is now organized into independent project directories:

- **USD/JPY Exchange Rate Monitoring**: `rate-exchange/rate-exchange.py`
- **Bitcoin Price Monitoring**: `bitcoin/bitcoin_tracker.py`, `bitcoin/bitcoin_chart.py`, `bitcoin/bitcoin_trading_tool.py`
- **US Treasury Bond Rates**: `us_bonds/us_bond_checker.py`
- **OCI A1 Instance Availability**: `check_a1/check_a1_availability_with_pushover.sh`

All components use Pushover for notifications and run on OCI infrastructure with automated cron scheduling.

## Directory Structure

```
├── config.json                    # Global configuration file
├── deploy-all-to-oci.sh          # Unified deployment script
├── system-health-check.sh        # System monitoring script
├── rate-exchange/                 # USD/JPY monitoring
│   ├── rate-exchange.py
│   ├── requirements.txt
│   ├── README.md
│   └── CLAUDE.md
├── bitcoin/                       # Bitcoin monitoring and charts
│   ├── bitcoin_tracker.py
│   ├── bitcoin_chart.py
│   ├── bitcoin_trading_tool.py
│   ├── README.md
│   └── CLAUDE.md
├── check_a1/                      # OCI A1 instance monitoring
│   ├── check_a1_availability.sh
│   ├── check_a1_availability_with_pushover.sh
│   ├── README.md
│   └── CLAUDE.md
├── us_bonds/                      # US Treasury bonds monitoring
│   ├── us_bond_checker.py
│   ├── us_bonds_data.json
│   ├── README.md
│   └── CLAUDE.md
└── youtube-live-chat-flow/        # Independent project (unchanged)
```

## Architecture

- **Distributed monitoring system**: Multiple specialized scripts running on OCI
- **Data persistence**: Each monitor uses JSON files for historical data storage
- **External APIs**: 
  - ExchangeRate.host API for USD/JPY currency data
  - CoinGecko API for Bitcoin price data
  - Treasury.gov API for US bond rates data
  - OCI API for infrastructure monitoring
  - Pushover API for unified notifications
- **Common functions across all monitors**:
  - API data fetching with error handling
  - Historical data loading/saving
  - Pushover notification sending
  - Morning report generation (`--morning-report` flag)
  - Threshold-based alerting (default 5%)

## Dependencies

All monitoring scripts require:
- `requests`: For API calls
- `json`: For data serialization (built-in)
- `datetime`: For timestamp handling (built-in)
- `os`: For file operations (built-in)
- `logging`: For structured logging (built-in)

Install dependencies with:
```bash
pip install requests
```

## Configuration

All configuration is centralized in `config.json`:
- **Pushover credentials**: Shared across all monitoring scripts
- **API endpoints**: ExchangeRate.host, CoinGecko, OCI API
- **Thresholds**: Default 5% for financial monitors, configurable per script
- **Logging**: Centralized log file paths for each monitor
- **Intervals**: Cron scheduling and API rate limits

## OCI Deployment and System Health

### Current OCI Instance Configuration
- **Instance**: Oracle Linux 8, 1GB RAM, 2 CPU cores
- **Location**: OCI Tokyo region (ap-tokyo-1)
- **IP**: 138.2.28.222 (primary connection)

### Cron Schedule (Optimized for System Stability)
```bash
# 15-minute intervals (optimized from 5-minute to reduce load)
*/15 * * * * cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh
*/15 * * * * cd /home/opc/rate-exchange && python3 rate-exchange.py
*/15 * * * * cd /home/opc/bitcoin && python3 bitcoin_tracker.py
*/15 * * * * cd /home/opc/us_bonds && python3 us_bond_checker.py

# Daily morning reports (10:00 AM JST)
0 10 * * * cd /home/opc/check_a1 && ./check_a1_availability_with_pushover.sh --morning-report
0 10 * * * cd /home/opc/rate-exchange && python3 rate-exchange.py --morning-report
0 10 * * * cd /home/opc/bitcoin && python3 bitcoin_tracker.py --morning-report
0 10 * * * cd /home/opc/us_bonds && python3 us_bond_checker.py --morning-report
```

## System Stability and Performance Guidelines

### CRITICAL: Before Adding New Monitoring Scripts

**ALWAYS perform system health check and load balancing analysis:**

1. **Memory Usage Assessment**
   ```bash
   # Check current memory usage on OCI
   ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'free -h && cat /proc/loadavg'
   
   # Check for memory pressure indicators
   ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'ps aux --sort=-%cpu | head -10'
   ```

2. **Swap Usage Monitoring** 
   ```bash
   # Check swap usage (should be <200MB for system stability)
   ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'swapon --show && free -h'
   
   # Monitor kswapd0 process (high CPU time indicates memory pressure)
   ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'ps aux | grep kswapd'
   ```

3. **Cron Load Analysis**
   ```bash
   # Review current cron frequency and timing
   ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'crontab -l | grep -v "^#"'
   
   # Check for simultaneous execution conflicts
   # Avoid multiple scripts running at same minute marks
   ```

### Load Balancing Rules

- **15-minute minimum intervals**: Never schedule more frequently than */15
- **Stagger execution times**: Distribute scripts across different minute offsets
- **Memory budget**: Each new Python script ~10-15MB RAM baseline
- **API rate limits**: Respect external API quotas (CoinGecko: 30/min, ExchangeRate: unlimited, Treasury.gov: 10/min)

### System Health Thresholds

| Metric | Warning | Critical | Action Required |
|--------|---------|----------|-----------------|
| Load Average (15min) | >5.0 | >15.0 | Reduce cron frequency |
| Memory Available | <300MB | <100MB | Optimize scripts or reduce frequency |
| Swap Usage | >500MB | >1GB | Immediate optimization needed |
| Log File Size | >10MB | >50MB | Implement log rotation |

### Pre-Deployment Checklist for New Scripts

- [ ] **Memory impact test**: Run script locally and measure RSS memory usage
- [ ] **Error handling**: Implement proper try/catch with logging
- [ ] **API timeout**: Set reasonable timeout values (30s max)
- [ ] **Config integration**: Use centralized `config.json` for all settings
- [ ] **Morning report**: Implement `--morning-report` flag for 10:00 summary
- [ ] **Log rotation**: Ensure logs don't grow indefinitely
- [ ] **Cron timing**: Schedule at non-conflicting minute offsets

### Automated System Health Check

**MANDATORY: Run before adding any new monitoring script**

```bash
# Execute comprehensive health assessment
./system-health-check.sh

# This script automatically:
# - Checks memory usage and swap status
# - Analyzes current cron load
# - Evaluates system capacity for new scripts
# - Provides specific recommendations
```

The health check provides color-coded status:
- ✅ **Green**: Safe to add new scripts
- ⚠️ **Yellow**: Proceed with caution, use longer intervals
- ❌ **Red**: System optimization required before adding scripts

### Emergency Performance Recovery

If system becomes unresponsive due to high load:

```bash
# 1. Reduce cron frequency immediately
ssh -i ~/.ssh/id_rsa opc@138.2.28.222 '
crontab -l | sed "s/\*\/5/\*\/30/g" | sed "s/\*\/15/\*\/30/g" | crontab -
'

# 2. Clear memory caches (if accessible)
ssh -i ~/.ssh/id_rsa opc@138.2.28.222 'sync && echo 3 > /proc/sys/vm/drop_caches'

# 3. Rotate large log files
ssh -i ~/.ssh/id_rsa opc@138.2.28.222 '
for log in /home/opc/*.log; do
  if [ -f "$log" ] && [ $(stat -c%s "$log") -gt 10485760 ]; then
    tail -n 1000 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
  fi
done'
```

## Deployment

Deploy all monitoring systems to OCI:

```bash
# Deploy all projects to OCI instance
./deploy-all-to-oci.sh 138.2.28.222

# This script will:
# - Create project directories on OCI
# - Upload all project files to their respective directories
# - Set up proper permissions
# - Install dependencies
# - Configure cron jobs for each project
# - Test all monitoring systems
```

The deployment script creates the same directory structure on OCI and ensures all scripts run from their proper working directories.

## Key Implementation Notes

- **Independent projects**: Each monitoring system operates in its own directory
- **Centralized configuration**: All projects share the main `config.json` file
- **Proper working directories**: Cron jobs use `cd` to ensure scripts run from correct locations
- All scripts save historical data regardless of notification triggers
- Notifications use 5% default threshold (configurable per monitor)
- Japanese language used for user-facing notifications  
- UTC timestamps ensure consistency across time zones
- Morning reports provide daily system health summaries