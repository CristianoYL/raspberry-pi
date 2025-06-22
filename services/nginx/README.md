# Nginx

Nginx is used as a reverse proxy to direct HTTP(S) traffic to different containers.

Currently the main use case is to listen on port 80 for HTTP connections and proxy requests to **Open WebUI** and **Pi-Hole** respectively.

## Installation

```
sudo apt install nginx
```

In most nerwer OS versions, nginx service will auto start as a daemon after installation.

## Set Up

Modify the example conf files and put them under `/etc/nginx/site-available/`.

Then make a symlink to the `/etc/nginx/site-enabled/` folder:

```bash
cd /etc/nginx/site-enabled/
sudo ln -s ../site-available/pihole.conf .
sudo ln -s ../site-available/open_webui.conf .
```

Check nginx systax:

```bash
sudo nginx -t
```

If the test passed, reload nginx with the new configs:

```bash
sudo nginx -s reload
```
