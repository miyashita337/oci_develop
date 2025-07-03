# Bitcoin Monitoring System - Claude Context

This file provides guidance to Claude Code when working with the Bitcoin monitoring system.

## Project Overview

This is a Bitcoin price monitoring and chart generation system that:
- Tracks Bitcoin price data using CoinGecko API
- Generates visual charts (line charts and candlestick charts)
- Sends price alerts via Pushover notifications
- Provides morning reports with price summaries

## Key Files

- **bitcoin_tracker.py**: Core price tracking and data collection
- **bitcoin_chart.py**: Chart generation with matplotlib
- **bitcoin_trading_tool.py**: Main execution script with command-line interface

## Configuration

The system uses the main `config.json` file located in the parent directory (`../config.json`). Key configuration sections:
- `bitcoin.api`: API settings for CoinGecko
- `bitcoin.trading`: Trading pair and monitoring settings
- `bitcoin.chart`: Chart appearance and output settings
- `bitcoin.alerts`: Price change thresholds and notification settings

## Dependencies

All required dependencies are listed in the main `requirements.txt` file in the parent directory.

## API Integration

- **CoinGecko API**: Used for Bitcoin price data
- **Pushover API**: Used for notifications (configured in main config)

## Data Flow

1. bitcoin_tracker.py fetches current price from CoinGecko API
2. Data is stored in JSON format in `/tmp/` directory
3. bitcoin_chart.py reads stored data and generates charts
4. Alerts are sent via Pushover when price thresholds are exceeded

## Common Tasks

- **Update price monitoring**: Modify `bitcoin_tracker.py`
- **Customize charts**: Modify `bitcoin_chart.py`
- **Add new features**: Use `bitcoin_trading_tool.py` as main entry point
- **Adjust thresholds**: Update `config.json` in parent directory

## Error Handling

All scripts include comprehensive error handling and logging. Logs are configured via the main config file.

## Testing

Test the system by running:
```bash
python3 bitcoin_trading_tool.py --action both
```