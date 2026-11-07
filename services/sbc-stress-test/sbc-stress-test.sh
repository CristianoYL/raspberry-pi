#!/bin/bash
# sbc-stress-test.sh — adaptive stress test for any SBC
# Usage: sudo ./sbc-stress-test.sh [duration_minutes]

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
DURATION="${1:-60}"  # default 60 minutes, override with first argument

# ──────────────────────────────────────────────
# Resolve real user (even when run with sudo)
# ──────────────────────────────────────────────
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~"$REAL_USER")

# Log to the same directory as the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/stress-test-$(hostname)-$(date +%Y%m%d-%H%M%S).log"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
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
box_line() {
  printf "║  %-${BOX_WIDTH}s║\n" "$1"
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
box_line "  RAM:  ${VM_WORKERS} workers, ${USABLE_RAM_MB} MB"
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
  local max_temp=0
  echo "timestamp,temp_mC,load_1m,load_5m,load_15m,mem_used_mb,mem_total_mb" > "$THERMAL_LOG"

  while true; do
    local temp="N/A"
    if [ -n "$THERMAL_ZONE" ]; then
      temp=$(cat "$THERMAL_ZONE" 2>/dev/null || echo "N/A")
    fi

    local load
    load=$(cat /proc/loadavg | awk '{print $1","$2","$3}')

    local mem
    mem=$(free -m | awk '/Mem:/ {print $3","$2}')

    echo "$(date '+%Y-%m-%d %H:%M:%S'),$temp,$load,$mem" >> "$THERMAL_LOG"

    # Track max temp
    if [ "$temp" != "N/A" ] && [ "$temp" -gt "$max_temp" ] 2>/dev/null; then
      max_temp=$temp
    fi

    # Warn if too hot (85°C = 85000 millidegrees)
    if [ "$temp" != "N/A" ] && [ "$temp" -gt 85000 ] 2>/dev/null; then
      echo "⚠️  WARNING: Temperature ${temp} mC ($(( temp / 1000 ))°C) — throttling likely!"
    fi

    sleep 10
  done
}

monitor_thermals &
MONITOR_PID=$!
trap "kill $MONITOR_PID 2>/dev/null; wait $MONITOR_PID 2>/dev/null" EXIT

# ──────────────────────────────────────────────
# Phase 1: Memory test (most critical)
# ──────────────────────────────────────────────
PHASE_DURATION=$(( DURATION / 3 ))
echo ""
echo "━━━ Phase 1/3: Memory test (${PHASE_DURATION} min) ━━━"
echo "    Testing ${USABLE_RAM_MB} MB with memtester"

# memtester doesn't have a timeout flag, so we background it and kill after duration
sudo memtester "${USABLE_RAM_MB}M" 0 > >(tee -a "$STRESS_LOG") 2>&1 &
MEMTEST_PID=$!

sleep $(( PHASE_DURATION * 60 ))

kill "$MEMTEST_PID" 2>/dev/null
wait "$MEMTEST_PID" 2>/dev/null || true

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
echo "    CPU(${CPU_CORES}) + RAM(${USABLE_RAM_MB}MB) + I/O(${HDD_WORKERS})"

# RAM — memtester in background
sudo memtester "${USABLE_RAM_MB}M" 0 > >(tee -a "$STRESS_LOG") 2>&1 &
MEMTEST_PID=$!

stress-ng \
  --cpu "$CPU_CORES" \
  --hdd "$HDD_WORKERS" \
  --verify \
  --timeout "${PHASE_DURATION}m" \
  --metrics-brief \
  2>&1 | tee -a "$STRESS_LOG" &
STRESS_PID=$!

# Wait for stress-ng to finish (it has its own timeout)
wait "$STRESS_PID" 2>/dev/null || true

# Then kill memtester (no built-in timeout)
kill "$MEMTEST_PID" 2>/dev/null
wait "$MEMTEST_PID" 2>/dev/null || true

echo ""
echo "✅ Phase 3 complete"

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
kill $MONITOR_PID 2>/dev/null
wait $MONITOR_PID 2>/dev/null || true
trap - EXIT

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

chown -R "$REAL_USER":"$REAL_USER" "$LOG_DIR"
