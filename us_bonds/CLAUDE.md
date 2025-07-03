# US Treasury Bonds Monitor - Claude Context

This file provides guidance to Claude Code when working with the US Treasury bonds interest rate monitoring system.

## Project Overview

This system monitors US Treasury bond interest rates and:
- Tracks bond yields for multiple durations (2-year, 10-year, 30-year)
- Sends alerts when rates exceed configurable thresholds
- Provides morning reports with rate summaries
- Maintains historical data for trend analysis

## Key Files

- **us_bond_checker.py**: Main monitoring script with alert logic
- **us_bonds_data.json**: Historical bond rate data storage

## Configuration

The system uses the main `config.json` file located in the parent directory (`../config.json`). Key configuration sections:
- `us_bonds.monitoring`: Threshold settings and data file paths
- `pushover`: Notification settings
- `logging`: Log file paths and settings

## Dependencies

All required dependencies are listed in the main `requirements.txt` file in the parent directory.

## API Integration

- **Treasury.gov API**: Planned for official bond rate data
- **Pushover API**: Used for notifications (configured in main config)

## Data Flow

1. us_bond_checker.py fetches current bond rates (currently using sample data)
2. Compares rates against configured thresholds
3. Sends alerts via Pushover when thresholds are exceeded
4. Stores historical data in local JSON file
5. Generates morning reports with daily summaries

## Common Tasks

- **Update rate sources**: Modify API endpoints in us_bond_checker.py
- **Adjust thresholds**: Update `config.json` in parent directory
- **Add new bond types**: Extend the monitoring logic
- **Customize alerts**: Modify notification messages in script

## Alert Logic

The system currently monitors:
- 10-year Treasury bond yields exceeding 5% (configurable)
- Additional thresholds can be added for other bond types
- Morning reports include yesterday's rate summaries

## Error Handling

The script includes comprehensive error handling for:
- API call failures
- Data parsing errors
- File I/O operations
- Network connectivity issues

## Testing

Test the system by running:
```bash
python3 us_bond_checker.py
```

For morning reports:
```bash
python3 us_bond_checker.py --morning-report
```

## Future Enhancements

- Integration with real Treasury.gov API
- Support for additional bond types
- Trend analysis and prediction
- Enhanced reporting capabilities