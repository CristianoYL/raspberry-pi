#!/bin/bash
# sbc-stress-test.sh — adaptive stress test for any SBC
# Usage: sudo ./sbc-stress-test.sh [-d minutes] [-p io_path]

set -euo pipefail

# ──────────────────────────────────────────────
# Prerequisites
# ──────────────────────────────────────────────
if (( EUID != 0 )); then
  echo "Run this script with sudo." >&2
  exit 1
fi

for cmd in stress-ng free awk tee; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
DURATION=3
IO_TEST_DIR=""

usage() {
  echo "Usage: sudo $0 [-d minutes] [-p io_path]"
  echo "  -d  Duration in minutes (default: $DURATION)"
  echo "  -p  Path for I/O test files (default: script directory)"
  exit 1
}

while getopts "d:p:h" opt; do
  case $opt in
    d) DURATION="$OPTARG" ;;
    p) IO_TEST_DIR="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ ! "$DURATION" =~ ^[1-9][0-9]*$ ]]; then
  echo "Duration must be a positive whole number of minutes." >&2
  exit 1
fi

# ──────────────────────────────────────────────
# Resolve real user (even when run with sudo)
# ──────────────────────────────────────────────
REAL_USER="${SUDO_USER:-$USER}"
REAL_GROUP=$(id -gn "$REAL_USER")

# Log to the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Default IO test path if not specified
if [[ -z "$IO_TEST_DIR" ]]; then
  IO_TEST_DIR="$SCRIPT_DIR/io-test"
fi
mkdir -p "$IO_TEST_DIR"
THERMAL_LOG="$LOG_DIR/thermal-$(hostname)-$TIMESTAMP.csv"
STRESS_LOG="$LOG_DIR/stress-$(hostname)-$TIMESTAMP.log"

# ──────────────────────────────────────────────
# Detect hardware
# ──────────────────────────────────────────────
CPU_CORES=$(nproc)
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
AVAILABLE_RAM_MB=$(free -m | awk '/Mem:/ {print $7}')
HOSTNAME=$(hostname)

# Reserve ~20% of total RAM for OS + kernel, use the rest
USABLE_RAM_MB=$(( AVAILABLE_RAM_MB * 80 / 100 ))

# Number of VM workers — 1 per 2 cores, minimum 1
VM_WORKERS=$(( CPU_CORES / 2 ))
[ "$VM_WORKERS" -lt 1 ] && VM_WORKERS=1

# HDD workers — half the CPU cores, minimum 1
HDD_WORKERS=$(( CPU_CORES / 2 ))
[ "$HDD_WORKERS" -lt 1 ] && HDD_WORKERS=1

# Find thermal zone (varies by board)
THERMAL_ZONE=""
for zone in /sys/class/thermal/thermal_zone*/temp; do
  if [ -f "$zone" ]; then
    THERMAL_ZONE="$zone"
    break  # use the first one (usually CPU)
  fi
done

# Define the box width (inner content between the ║ borders)
BOX_WIDTH=44
# Helper function — prints a line with right-aligned border
# Adjusts for multi-byte UTF-8 characters (e.g., °) that display as single column
box_line() {
  local content="$1"
  local byte_len=${#content}
  local char_len
  char_len=$(printf '%s' "$content" | wc -m | tr -d ' ')
  local width=$(( BOX_WIDTH + byte_len - char_len ))
  printf "║  %-${width}s║\n" "$content"
}

# ──────────────────────────────────────────────
# Display plan
# ──────────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║         SBC Stress Test                      ║"
echo "╠══════════════════════════════════════════════╣"
box_line "Host:        $HOSTNAME"
box_line "CPU cores:   $CPU_CORES"
box_line "Total RAM:   ${TOTAL_RAM_MB} MB"
box_line "Available:   ${AVAILABLE_RAM_MB} MB"
box_line "Usable:      ${USABLE_RAM_MB} MB"
box_line "Duration:    ${DURATION} minutes"
echo "╠══════════════════════════════════════════════╣"
box_line "Plan:"
box_line "  CPU:  ${CPU_CORES} workers (all cores)"
box_line "  RAM:  ${VM_WORKERS} workers, ${USABLE_RAM_MB} MB total"
box_line "  I/O:  ${HDD_WORKERS} workers"
box_line "Logs:"
echo "║     Thermal:  ${THERMAL_LOG}"
echo "║     Stress:   ${STRESS_LOG}"
echo "╚══════════════════════════════════════════════╝"
echo ""
read -p "Start test? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ──────────────────────────────────────────────
# Thermal monitor (background)
# ──────────────────────────────────────────────
monitor_thermals() {
  echo "timestamp,temp_mC,load_1m,load_5m,load_15m,mem_used_mb,mem_total_mb" > "$THERMAL_LOG"

  while true; do
    local temp="N/A"
    if [ -n "$THERMAL_ZONE" ]; then
      temp=$(cat "$THERMAL_ZONE" 2>/dev/null || echo "N/A")
    fi

    local load
    load=$(awk '{print $1","$2","$3}' /proc/loadavg)

    local mem
    mem=$(free -m | awk '/Mem:/ {print $3","$2}')

    echo "$(date '+%Y-%m-%d %H:%M:%S'),$temp,$load,$mem" >> "$THERMAL_LOG"

    # Warn if too hot (85°C = 85000 millidegrees)
    if [ "$temp" != "N/A" ] && [ "$temp" -gt 85000 ] 2>/dev/null; then
      echo "⚠️  WARNING: Temperature ${temp} mC ($(( temp / 1000 ))°C) — throttling likely!"
    fi

    sleep 10
  done
}

monitor_thermals &
MONITOR_PID=$!

cleanup() {
  local rc=$?
  trap - EXIT
  if [[ -n "${MONITOR_PID:-}" ]]; then
    kill "$MONITOR_PID" 2>/dev/null || true
    wait "$MONITOR_PID" 2>/dev/null || true
  fi
  chown "$REAL_USER:$REAL_GROUP" "$THERMAL_LOG" "$STRESS_LOG" 2>/dev/null || true
  return "$rc"
}
trap cleanup EXIT

# ──────────────────────────────────────────────
# Phase 1: Memory stress
# ──────────────────────────────────────────────
PHASE_DURATION=$(( DURATION / 3 ))
echo ""
echo "━━━ Phase 1/3: Memory stress (${PHASE_DURATION} min) ━━━"
echo "    ${VM_WORKERS} workers, ${USABLE_RAM_MB} MB total"

stress-ng \
  --vm "$VM_WORKERS" \
  --vm-bytes "${USABLE_RAM_MB}M" \
  --vm-method all \
  --vm-keep \
  --vm-populate \
  --verify \
  --timeout "${PHASE_DURATION}m" \
  --metrics-brief \
  2>&1 | tee -a "$STRESS_LOG"

echo ""
echo "✅ Phase 1 complete"

# ──────────────────────────────────────────────
# Phase 2: CPU stress
# ──────────────────────────────────────────────
echo ""
echo "━━━ Phase 2/3: CPU stress (${PHASE_DURATION} min) ━━━"
echo "    ${CPU_CORES} workers, all methods"
stress-ng \
  --cpu "$CPU_CORES" \
  --cpu-method all \
  --timeout "${PHASE_DURATION}m" \
  --metrics-brief \
  2>&1 | tee -a "$STRESS_LOG"

echo ""
echo "✅ Phase 2 complete"

# ──────────────────────────────────────────────
# Phase 3: Combined (realistic NAS-like load)
# ──────────────────────────────────────────────
echo ""
echo "━━━ Phase 3/3: Combined stress (${PHASE_DURATION} min) ━━━"
echo "    CPU(${CPU_CORES}) + RAM(${USABLE_RAM_MB} MB) + I/O(${HDD_WORKERS})"

stress-ng \
  --cpu "$CPU_CORES" \
  --cpu-method all \
  --vm "$VM_WORKERS" \
  --vm-bytes "${USABLE_RAM_MB}M" \
  --vm-method all \
  --vm-keep \
  --vm-populate \
  --hdd "$HDD_WORKERS" \
  --temp-path "$IO_TEST_DIR" \
  --verify \
  --timeout "${PHASE_DURATION}m" \
  --metrics-brief \
  2>&1 | tee -a "$STRESS_LOG"

echo ""
echo "✅ Phase 3 complete"

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
kill "$MONITOR_PID" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true
MONITOR_PID=""

# Extract peak temp from log
PEAK_TEMP="N/A"
if [ -f "$THERMAL_LOG" ]; then
  PEAK_TEMP=$(awk -F',' 'NR>1 && $2 != "N/A" {if($2+0 > max) max=$2+0} END {if(max) printf "%.1f°C", max/1000; else print "N/A"}' "$THERMAL_LOG")
fi

BOOT_ERRORS=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | awk '$1 ~ /^\[/ {gsub(/[\[\]]/, "", $1); if ($1+0 <= 30) count++} END {print count+0}')
RUNTIME_ERRORS=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | awk '$1 ~ /^\[/ {gsub(/[\[\]]/, "", $1); if ($1+0 > 30) count++} END {print count+0}')


echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Test Complete                        ║"
echo "╠══════════════════════════════════════════════╣"
box_line "Host:        $HOSTNAME"
box_line "Duration:    ${DURATION} minutes"
box_line "Peak temp:   ${PEAK_TEMP} "
echo "║  Log:         ${THERMAL_LOG}"
echo "║               ${STRESS_LOG}"
box_line "Kern errs: ${RUNTIME_ERRORS} runtime, ${BOOT_ERRORS} boot (ignored)"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Review kernel errors:"
echo "  dmesg --level=err,crit,alert,emerg"
echo ""
echo "Optionally, exclude erors during boot (beyond the first 30 seconds):"
echo "  dmesg --level=err,crit,alert,emerg | awk '$1 ~ /^\[/ {gsub(/[\[\]]/, "", $1); if ($1+0 > 30) print}'"
echo ""
echo "Review thermal log:"
echo "  column -t -s',' $THERMAL_LOG | less"
