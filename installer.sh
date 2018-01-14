#!/bin/sh

# Insert installer nix file into /etc/nixos/configuration.nix imports list
tmp=$(mktemp)
cat /etc/nixos/configuration.nix | sed -E -e 's/imports = \[ (.*) \]/imports = \[ \1 ./installer.nix \]/g' > $tmp
mv $tmp /etc/nixos/configuration.nix

# Create /etc/nixos/installer.nix
cat <<EOF > /etc/nixos/installer.nix 
{ config, pkgs, ... }:

{
  boot.supportedFilesystems = [ "zfs" ];

  environment.systemPackages = with pkgs; [ git ];

  #services.dnscrypt-proxy.enable = true;
  #networking.nameservers = [ "127.0.0.1" ];
  #networking.proxy.allProxy = "socks5://127.0.0.1:1080";
  #networking.proxy.default = "socks5://127.0.0.1:1080";
}
EOF

# Activate
nixos-rebuild switch
