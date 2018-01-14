#!/bin/sh

set -xe

EFI_SIZE=100M
SWAP_SIZE=16G

# Check for needed binaries
sgdisk=$(which sgdisk)
zfs=$(which zfs)
cryptsetup=$(which cryptsetup)

# XXX: Generate by hashing serial number
hostId=$(cat /etc/hostid | od -A none -t x4 -w64 | xargs echo)

disk=$1

if [ -z "$disk" ]; then
	echo "usage: $0 /dev/disk/by-id/DISK_ID"
	exit 1
fi

#
# Partition disk
#
sgdisk -Z -n1:0:+${EFI_SIZE} -t1:EF00 -c1:EFI -n2:0:0 -t2:E800 -c2:LUKS -p ${disk}

#
# Initialize LUKS partition
#
cryptsetup luksFormat --key-size 512 --hash sha512 --verify-passphrase ${disk}-part2
cryptsetup open ${disk}-part2 crypt

#
# Initialize ZFS on LUKS partition
#
zpool create -o ashift=12 -o altroot=/mnt -m none -O atime=on -O relatime=on -O compression=lz4 zroot /dev/mapper/crypt

# XXX: Create swap zvol based on RAM size
zfs create -o compression=off -V ${SWAP_SIZE} zroot/SWAP
mkswap -L SWAP /dev/zvol/zroot/SWAP
swapon /dev/zvol/zroot/SWAP

# Create ROOT container dataset
zfs create -o mountpoint=none zroot/ROOT

zfs create -o mountpoint=legacy zroot/ROOT/default
mkdir -p /mnt
mount -t zfs zroot/ROOT/default /mnt

# Initialize EFI system partition
mkfs.vfat -F 32 -n EFI ${disk}-part1
mkdir -p /mnt/boot/EFI
mount ${disk}-part1 /mnt/boot/EFI

# Create DATA container dataset
zfs create -o mountpoint=none zroot/DATA

zfs create -o mountpoint=legacy zroot/DATA/home
mkdir -p /mnt/home
mount -t zfs zroot/DATA/home /mnt/home

zfs create -o mountpoint=legacy zroot/DATA/etc/nixos
mkdir -p /mnt/etc/nixos
mount -t zfs zroot/DATA/nixos /mnt/etc/nixos

#
# Set default boot filesystem
#
zpool set bootfs=zroot/ROOT/default zroot

#
# Generate NixOS config
#
nixos-generate-config --root /mnt

mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.orig

cat <<EOF > /mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./boot.nix
      ./networking.nix
    ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "17.09"; # Did you read the comment?
}
EOF

cat <<EOF > /mnt/etc/nixos/boot.nix
{ config, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot/EFI";

      grub = {
        enable = true;
        device = "nodev";
        version = 2;
        efiSupport = true;
        enableCryptodisk = true;
      };
    };

    supportedFilesystems = [ "zfs" ];
    initrd.luks.devices = [
      { name = "crypt"; device = "${disk}-part2"; }
    ];
  };
}
EOF

cat <<EOF > /mnt/etc/nixos/networking.nix
{ config, pkgs, ... }:

{
  networking = {
    hostId = "${hostId}";
    wireless.enable = true;
  };
}
EOF

#
# Install NixOS
#
nixos-install 2>&1 | tee install.log
