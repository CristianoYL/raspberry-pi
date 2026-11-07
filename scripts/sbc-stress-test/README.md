# SBC Stress Test

A comprehensive stress test script for single-board computers (SBCs) like Raspberry Pi. Tests CPU, memory, and I/O under sustained load while monitoring thermals.

## Requirements

- `stress-ng` - the stress testing tool
- Root privileges (run with `sudo`)

Install on Debian/Ubuntu:
```bash
sudo apt install stress-ng
```

## Usage

```bash
sudo ./sbc-stress-test.sh [-d minutes] [-p io_path]
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `-d` | Test duration in minutes | 60 |
| `-p` | Path for I/O test files | `./io-test` |
| `-h` | Show help | - |

### Examples

```bash
# Quick 3-minute test
sudo ./sbc-stress-test.sh -d 3

# 30-minute test with I/O on external drive
sudo ./sbc-stress-test.sh -d 30 -p /mnt/ssd/io-test

# Default 60-minute test
sudo ./sbc-stress-test.sh
```

## Test Phases

The test runs in three phases, each taking 1/3 of the total duration:

| Phase | Stressors | Purpose |
|-------|-----------|---------|
| 1 | Memory (VM) | Tests RAM stability with multiple allocation patterns |
| 2 | CPU | Tests all CPU cores with various compute methods |
| 3 | Combined | CPU + Memory + I/O together (NAS-like workload) |

## Output

### Logs

Two log files are created in `./logs/`:

- `thermal-<hostname>-<timestamp>.csv` - Temperature and system metrics every 10 seconds
- `stress-<hostname>-<timestamp>.log` - stress-ng output and performance metrics

### Summary

After completion, a summary box shows:

- **Peak/Mean temp** - Maximum and average CPU temperature
- **Samples >80C** - Number of readings above thermal throttling threshold
- **Verify errors** - Memory verification failures (indicates bad RAM)
- **Throttle events** - Kernel throttling messages
- **Kernel errors** - Runtime errors from dmesg
- **Bogo ops/s** - stress-ng throughput metric

### Interpreting Results

| Metric | Good | Warning | Bad |
|--------|------|---------|-----|
| Peak temp | <70C | 70-80C | >80C (throttling) |
| Verify errors | 0 | - | >0 (hardware issue) |
| Throttle events | 0 | >0 | Many (cooling needed) |
| Kernel errors | 0 | >0 | Many (investigate dmesg) |

## Post-Test Commands

```bash
# View thermal data
column -t -s',' logs/thermal-*.csv | less

# Check throughput
grep 'bogo ops' logs/stress-*.log

# Check for throttling
dmesg | grep -i throttl

# Check kernel errors
dmesg --level=err,crit,alert,emerg
```
