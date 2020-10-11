# Relay

A script to provision an Archlinux with a VPN and Torrent.

## Installation

```sh
apt-get update \
  && apt-get install -y git \
  && git clone https://github.com/nclsprsn/relay.git \
  && cd relay \
  && cp relay.conf.default relay.conf \
  && ./INSTALL.sh
```

## Roadmap

 - [ ] Secure SSH with keys
 - [ ] Install OpenVPN
 - [ ] Install ruTorrent
 - [ ] Retrieve dynamically the Arch Linux repository mirror list
 - [ ] Encrypt hard drive with dropbear and initramfs
