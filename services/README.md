# Overview

Most of the services on the Pi are using Docker containers managed by **docker-compose**. With some HTTP services reverse proxied by **Nginx**.

## Docker

The **docker compose** file manages the following services:

- [Jellyfin](./jellyfin/README.md)
- [Open WebUI](./open_webui/README.md)
- [Pi-Hole](./pihole/README.md)
- [iperf3](./iperf3/README.md)

Here is an [example docker compose](./docker-compose.yml) file. Beware of the relative links and user-specific settings (hostname, username, IP etc.)

## Nginx

Nginx is used as a reverse proxy to direct HTTP(S) traffic to different containers. This is especially useful when there are multiple services expecting traffic on the same port. Example configs are provided under the [./nginx/](./nginx/README.md) subfolder.
