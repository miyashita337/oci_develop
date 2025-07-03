# Bitcoin Monitoring System

This directory contains the Bitcoin price monitoring and chart generation system that tracks Bitcoin price data and generates visual charts.

## Components

- **bitcoin_tracker.py**: Main Bitcoin price tracking script using CoinGecko API
- **bitcoin_chart.py**: Chart generation tool for Bitcoin price visualization
- **bitcoin_trading_tool.py**: Main execution script that combines tracking and charting

## Features

- Real-time Bitcoin price monitoring via CoinGecko API
- Historical data generation and storage
- Interactive chart generation (line charts and candlestick charts)
- Price alert notifications via Pushover
- Configurable monitoring thresholds
- Morning report generation

## Configuration

All configuration is managed via the main `config.json` file in the parent directory. The Bitcoin monitoring system uses the `bitcoin` section of the configuration.

## Usage

Run the monitoring system:
```bash
python3 bitcoin_tracker.py
```

Generate charts:
```bash
python3 bitcoin_chart.py
```

Run both tracking and charting:
```bash
python3 bitcoin_trading_tool.py --action both
```

## Data Storage

- Historical data: `/tmp/bitcoin_historical_data.json`
- Current price data: `/tmp/bitcoin_current_price.json`
- Charts: Saved according to config settings

## Dependencies

- requests: For API calls
- matplotlib: For chart generation
- pandas: For data processing
- numpy: For numerical operations