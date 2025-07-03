# US Treasury Bonds Interest Rate Monitor

This directory contains the US Treasury bonds interest rate monitoring system that tracks bond yields and sends alerts when rates exceed specified thresholds.

## Components

- **us_bond_checker.py**: Main US Treasury bonds interest rate monitoring script
- **us_bonds_data.json**: Historical bond rate data storage

## Features

- Real-time US Treasury bond rate monitoring
- Configurable interest rate thresholds (default: 5% for 10-year bonds)
- Pushover notifications when rates exceed thresholds
- Morning report generation with daily summaries
- Historical data storage and tracking
- Support for multiple bond types (2-year, 10-year, 30-year)

## Configuration

All configuration is managed via the main `config.json` file in the parent directory. The US bonds monitoring system uses the `us_bonds` section of the configuration.

## Usage

Run the bonds monitoring system:
```bash
python3 us_bond_checker.py
```

Send morning report:
```bash
python3 us_bond_checker.py --morning-report
```

## Data Sources

Currently uses sample data for testing. In production, this should be connected to:
- Treasury.gov API for official bond rate data
- FRED API for Federal Reserve economic data
- Other financial data providers

## Data Storage

- Historical data: `us_bonds_data.json` (in same directory)
- Configuration: `../config.json` (parent directory)
- Logs: As specified in main configuration

## Alert Thresholds

The system monitors for:
- 10-year Treasury bond yields exceeding configurable threshold (default: 5%)
- Significant rate changes over time
- Custom threshold alerts as configured

## Dependencies

- requests: For API calls
- json: For data serialization
- datetime: For timestamp handling
- os: For file operations
- logging: For structured logging

## API Integration

- **Treasury.gov API**: For official bond rate data (to be implemented)
- **Pushover API**: For notifications (configured in main config)