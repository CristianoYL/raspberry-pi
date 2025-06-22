# JellyFin

Cross-platform media server/client. Can be used to manage photos, videos and movies and stream on any client devices.

## Hosting Content

Raspberry PI is used as the server. There are a few options to host media files:

- directly from a local folder
- an attached usb device
- a shared network folder (e.g.: smb)

The first two are basically the same. Just make sure the appropriate user permission is set.

### smb (optional)

Optionally we can use **smb** to access media files over the network, mount onto a local directory and then bind mount into the Jellyfin container.

Assuming the following setup:

- Pi username: `yl`
- **smb** server ip: `10.0.0.5`
- **smb** folder to mount (source): `/smb`
- folder to mount to (dest): `/mnt/smb`
- username and password stored into a file `/root/.smb`

Here's the example command to mount an `smb` drive to local folder.

```bash
sudo mount -t cifs //10.0.0.5/smb /mnt/smb/ -o credentials=/root/.smb,vers=3.0,uid=yl,gid=yl
```
