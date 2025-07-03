# OCI A1 Instance Availability Checker - Claude Context

This file provides guidance to Claude Code when working with the OCI A1 instance availability checking system.

## Project Overview

This system monitors Oracle Cloud Infrastructure (OCI) A1 instance availability by:
- Periodically attempting to provision A1.Flex instances
- Sending notifications when instances become available
- Providing morning reports with availability statistics
- Maintaining comprehensive logs of all activities

## Key Files

- **check_a1_availability_with_pushover.sh**: Main enhanced script with notifications
- **check_a1_availability.sh**: Basic standalone version (legacy)

## Configuration

The system uses the main `config.json` file located in the parent directory (`../config.json`). Key configuration sections:
- `oci`: OCI credentials, compartment, and resource IDs
- `a1_instance`: A1-specific settings including shape and resource allocation
- `pushover`: Notification settings
- `logging`: Log file paths and settings

## Dependencies

The scripts require:
- OCI CLI installed and configured
- curl for HTTP requests
- Standard bash utilities
- Proper OCI authentication and permissions

## API Integration

- **OCI API**: Used for instance provisioning attempts
- **Pushover API**: Used for notifications (configured in main config)

## Data Flow

1. Script reads configuration from parent directory
2. Attempts to provision A1.Flex instance using OCI CLI
3. If successful, immediately terminates instance (test mode)
4. Sends Pushover notification on availability
5. Logs all activities for reporting

## Common Tasks

- **Update instance configuration**: Modify `config.json` in parent directory
- **Adjust check intervals**: Update `check_interval_minutes` in config
- **Customize notifications**: Modify notification messages in script
- **Add new features**: Extend the main script with additional functionality

## Error Handling

The scripts include comprehensive error handling for:
- OCI API failures
- Network connectivity issues
- Configuration file problems
- Permission errors

## Testing

Test the system by running:
```bash
./check_a1_availability_with_pushover.sh
```

For morning reports:
```bash
./check_a1_availability_with_pushover.sh --morning-report
```

## Security Notes

- OCI credentials are stored in main config file
- SSH keys are configured for instance access
- Proper file permissions should be maintained on configuration files