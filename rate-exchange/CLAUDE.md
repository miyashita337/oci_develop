# USD/JPY Exchange Rate Monitor - Claude Context

This file provides guidance to Claude Code when working with the USD/JPY exchange rate monitoring system.

## Project Overview

This system monitors USD/JPY exchange rates and:
- Tracks real-time exchange rate data using ExchangeRate.host API
- Sends alerts when rates change by more than 5% (configurable)
- Provides morning reports with rate summaries
- Maintains historical rate data for trend analysis

## Key Files

- **rate-exchange.py**: Main monitoring script with alert logic
- **usd_jpy_rate.json**: Historical exchange rate data storage
- **deploy-to-oci.sh**: Deployment script for OCI infrastructure
- **requirements.txt**: Python dependencies specific to this project

## Configuration

The system uses the main `config.json` file located in the parent directory (`../config.json`). Key configuration sections:
- `rate_exchange`: Rate monitoring settings and thresholds
- `pushover`: Notification settings
- `logging`: Log file paths and settings

## Dependencies

Local dependencies are listed in `requirements.txt`. The main requirement is:
- requests: For API calls to ExchangeRate.host

## API Integration

- **ExchangeRate.host API**: Used for USD/JPY exchange rate data
- **Pushover API**: Used for notifications (configured in main config)

## Data Flow

1. rate-exchange.py fetches current USD/JPY rate from ExchangeRate.host API
2. Compares rate against previous rate to calculate change percentage
3. Sends alerts via Pushover when change exceeds threshold (default: 5%)
4. Stores historical data in local JSON file
5. Generates morning reports with daily summaries

## Common Tasks

- **Update rate sources**: Modify API endpoints in rate-exchange.py
- **Adjust thresholds**: Update `config.json` in parent directory
- **Add new currency pairs**: Extend the monitoring logic
- **Customize alerts**: Modify notification messages in script

## Alert Logic

The system monitors:
- USD/JPY exchange rate changes exceeding 5% (configurable)
- Significant rate movements over time
- Custom threshold alerts as configured

## Error Handling

The script includes comprehensive error handling for:
- API call failures
- Data parsing errors
- File I/O operations
- Network connectivity issues

## Testing

Test the system by running:
```bash
python3 rate-exchange.py
```

For morning reports:
```bash
python3 rate-exchange.py --morning-report
```

## Deployment

Use the provided deployment script:
```bash
./deploy-to-oci.sh <VM_IP_ADDRESS> <SSH_KEY_PATH>
```

## OCI Integration

The system is designed to run on Oracle Cloud Infrastructure Free Tier:
- VM.Standard.E2.1.Micro instances
- Automated cron scheduling
- Minimal resource usage optimized for free tier limits