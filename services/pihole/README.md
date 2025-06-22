# Pi-Hole

Follow the [pi-hole docker repo](https://github.com/pi-hole/docker-pi-hole) to set up.

One **major cavaet** is that the current tutorial is **NOT** fully functional out of box! We have to provide the following env vars:

```.env
# required for pi.hole to resolve if using docker bridge mode
FTLCONF_dns_reply_host_IPv4=10.0.0.2 # replace with your pi-hole host ip
FTLCONF_dns_reply_host_force4=true
```

Otherwise:

- The default `pi.hole` domain will not work, as it would resolve to the internal docker bridge ip, which is unreachable from any other clients.
- It would also result in weird behaviors from routers and possibly other clients to constantly looking up some domains (thousand times per second).
- OOM warning for shared memory (caused by the flooding lookup requests).

## Configuration

In addition to the docker compose file, some additional configurations are required as instructed by the official tutorial. We provide them via environment variables through a `.env` file. See [example.pihole.env](./example.pihole.env) for example.
