# SBC Temperature Monitoring

Display thermal sensor readings on single-board computers.

## Scripts

| Script | Description |
|--------|-------------|
| `sbc-temp` | Generic — shows all `/sys/class/thermal/` zones + hwmon + NVMe |
| `pi-temp` | Raspberry Pi — curated output with friendly labels |
| `q6a-temp` | Radxa Dragon Q6A — groups the 33 sensors into categories |
| `radxa-temp` | Radxa Rock 5T — already installed at `/usr/local/bin/radxa-temp` |

## Installation

Copy the appropriate script to `/usr/local/bin/`:

```bash
# Generic (works on any SBC)
sudo cp sbc-temp /usr/local/bin/
sudo chmod +x /usr/local/bin/sbc-temp

# Board-specific
sudo cp pi-temp /usr/local/bin/      # Raspberry Pi
sudo cp q6a-temp /usr/local/bin/     # Radxa Dragon Q6A
```

Optional: create a `temp` alias pointing to the board-specific script:

```bash
sudo ln -s /usr/local/bin/pi-temp /usr/local/bin/temp    # Pi
sudo ln -s /usr/local/bin/q6a-temp /usr/local/bin/temp   # Q6A
sudo ln -s /usr/local/bin/radxa-temp /usr/local/bin/temp # Rock 5T
```

## Usage

```bash
# One-shot reading
sbc-temp
pi-temp
q6a-temp

# Continuous monitoring (refresh every second)
sbc-temp -w
pi-temp -w
q6a-temp -w

# Q6A: show all 33 sensors instead of curated view
q6a-temp -a
q6a-temp -w -a
```

## Example Output

**Raspberry Pi 5:**
```
CPU:                 51.2°C
RP1 (southbridge):   50.8°C
```

**Radxa Rock 5T:**
```
soc-thermal:             54.5°C
bigcore0-thermal:        54.5°C
bigcore1-thermal:        54.5°C
littlecore-thermal:      54.5°C
center-thermal:          53.6°C
gpu-thermal:             53.6°C
npu-thermal:             53.6°C
nvme0 SSD:               39°C
```

**Radxa Dragon Q6A (curated):**
```
=== CPU ===
Big cores (max):     42.0°C
Little cores (max):  41.7°C
CPU subsystem:       41.7°C

=== GPU / NPU ===
GPU (max):           39.9°C
NPU (max):           39.5°C

=== Memory / Storage ===
DDR:                 40.7°C
UFS storage:         68.3°C

=== System ===
Skin:                40.1°C
Quiet zone:          40.9°C
PM7250B PMIC:        38.8°C
PM7325 PMIC:         40.0°C
```

## NVMe Support

NVMe temperature requires `nvme-cli` and passwordless sudo for the `nvme` command:

```bash
# Install nvme-cli
sudo apt install nvme-cli

# Allow passwordless nvme smart-log (optional, for non-root usage)
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/nvme smart-log *" | sudo tee /etc/sudoers.d/nvme-temp
```

## Data Sources

| Source | Location | Notes |
|--------|----------|-------|
| Thermal zones | `/sys/class/thermal/thermal_zone*/temp` | Standard Linux interface |
| hwmon sensors | `/sys/class/hwmon/hwmon*/temp*_input` | Additional sensors (RP1, PMIC) |
| NVMe | `nvme smart-log /dev/nvme0` | Requires nvme-cli |
| vcgencmd | `vcgencmd measure_temp` | Pi-specific fallback |

Temperatures in sysfs are in millidegrees Celsius (divide by 1000).
