# OCI A1 Instance Availability Checker

This directory contains scripts to monitor Oracle Cloud Infrastructure (OCI) A1 instance availability and send notifications when instances become available.

## Components

- **check_a1_availability.sh**: Basic A1 instance availability checker (standalone)
- **check_a1_availability_with_pushover.sh**: Enhanced A1 checker with Pushover notifications and morning reports

## Features

- Automated A1.Flex instance availability checking
- OCI CLI integration for instance provisioning attempts
- Pushover notifications when instances become available
- Morning report generation with yesterday's statistics
- Configurable check intervals and thresholds
- Comprehensive logging and error handling

## Configuration

All configuration is managed via the main `config.json` file in the parent directory. The A1 monitoring system uses several configuration sections:
- `oci`: OCI credentials and resource identifiers
- `a1_instance`: A1-specific settings and shape configuration
- `pushover`: Notification settings
- `logging`: Log file paths and settings

## Usage

Run the enhanced A1 checker:
```bash
./check_a1_availability_with_pushover.sh
```

Send morning report:
```bash
./check_a1_availability_with_pushover.sh --morning-report
```

## How It Works

1. The script attempts to provision an A1.Flex instance
2. If successful, it immediately terminates the instance (test mode)
3. Notifications are sent via Pushover when instances become available
4. Check intervals are configurable to avoid excessive API calls

## OCI Configuration

The scripts require:
- OCI CLI properly configured with authentication
- Appropriate permissions to create/terminate instances
- Valid compartment, subnet, and image IDs

## Logging

All activities are logged to files specified in the main configuration. Logs include:
- Instance availability check results
- API call outcomes
- Notification delivery status
- Error conditions and debugging information

## Dependencies

- OCI CLI (python3 -m oci)
- curl (for Pushover notifications)
- Standard bash utilities
- Access to main config.json file