# SBC Homelab

Configs, services, and utilities for single-board computers (Raspberry Pi, Orange Pi, etc.). Everything here is designed to be portable across Linux-based SBCs.

## Folder Structure

- `configs/` — System configuration files (MOTD, etc.)
- `services/` — Docker-managed services
- `scripts/` — Standalone utilities and tools
- `docs/` — Additional documentation

## Table of Contents

| Name            | Category | Purpose                              | Detail |
|-----------------|----------|--------------------------------------|--------|
| MOTD            | Config   | Custom login message with system stats | [configs/motd](configs/motd/README.md) |
| Jellyfin        | Service  | Media streaming server               | [services/jellyfin](services/jellyfin/README.md) |
| Open WebUI      | Service  | LLM web interface                    | [services/open_webui](services/open_webui/README.md) |
| Pi-Hole         | Service  | Ad-blocking DNS server               | [services/pihole](services/pihole/README.md) |
| iperf3          | Service  | Network speed test server            | [services/iperf3](services/iperf3/README.md) |
| Nginx           | Service  | Reverse proxy                        | [services/nginx](services/nginx/README.md) |
| SBC Stress Test | Script   | Hardware stress test with thermal monitoring | [scripts/sbc-stress-test](scripts/sbc-stress-test/README.md) |

## Platform Compatibility

Most components work on any Linux-based SBC. Platform-specific code (like temperature reading) includes fallbacks for portability:

- **Raspberry Pi**: Uses `vcgencmd` when available
- **Other SBCs**: Falls back to `/sys/class/thermal/` (standard Linux)
