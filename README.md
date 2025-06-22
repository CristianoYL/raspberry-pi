# Raspberry Pi Backups

This repo is a backup of Raspberry Pi 5 configs and services.

# Folder Structure

- `pi`: contains actual config file for Raspberry Pi, should be placed at the corresponding location unless otherwise specified.
- `docs`: documentations for each backup

# Table of Content

| Name       | Category       | Purpose                                     | Detail                                                         |
| ---------- | -------------- | ------------------------------------------- | -------------------------------------------------------------- |
| MOTD       | Server Configs | Display a nicer Message Of The Day on login | [docs/motd](docs/motd/README.md)                               |
| Jellyfin   | Service        | Media Streaming Server                      | [services/jellyfin/README.md](services/jellyfin/README.md)     |
| Open WebUI | Service        | GPT Web Service                             | [services/open_webui/README.md](services/open_webui/README.md) |
| Pi-Hole    | Service        | Ad-blocking DNS server                      | [services/pihole/README.md](services/pihole/README.md)         |
| iperf3     | Service        | Internet speed test server                  | [services/iperf3/README.md](services/iperf3/README.md)         |
