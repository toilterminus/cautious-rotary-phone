#!/bin/sh

set -xe

EFI_SIZE=100M
SWAP_SIZE=32G

# Check for needed binaries
sgdisk=$(which sgdisk)
zfs=$(which zfs)
cryptsetup=$(which cryptsetup)

# Generate a random hostId
hostId=$(head -c4 /dev/urandom | od -A none -t x4 | xargs echo)

function upgrade_installer() {
	# Insert installer nix file into /etc/nixos/configuration.nix imports list
	tmp=$(mktemp)
	cat /etc/nixos/configuration.nix | sed -E -e 's/imports = \[ (.*) \]/imports = \[ \1 .\/installer.nix \]/g' > $tmp
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
}

function initialize_disk() {
	local disk=$1

	if [ -z "$disk" ]; then
		echo "usage: $0 /dev/disk/by-id/DISK_ID"
		exit 1
	fi

	# Partition disk with two partitions: EFI and LUKS
	sgdisk -Z -n1:0:+${EFI_SIZE} -t1:EF00 -c1:EFI -n2:0:0 -t2:E800 -c2:LUKS -p ${disk}

	sleep 1

	# Initialize LUKS partition to hold the rest
	cryptsetup luksFormat --key-size 512 --hash sha512 --verify-passphrase ${disk}-part2
	cryptsetup open ${disk}-part2 lvmcrypt

	# Create PV
	pvcreate /dev/mapper/lvmcrypt
	vgcreate vg0 /dev/mapper/lvmcrypt

	# Initialize swap LV
	lvcreate -L ${SWAP_SIZE} -n swap vg0
	mkswap -L SWAP /dev/vg0/swap
	swapon /dev/vg0/swap

	# Initialize ZFS on LUKS partition
	lvcreate -l 100%FREE -n zroot vg0
	zpool create -o ashift=12 -o altroot=/mnt -m none -O atime=on -O relatime=on -O compression=lz4 zroot /dev/vg0/zroot

	# Create ROOT container dataset
	zfs create -o mountpoint=none zroot/ROOT

	# Create default root filesystem
	zfs create -o mountpoint=legacy zroot/ROOT/default
	mkdir -p /mnt
	mount -t zfs zroot/ROOT/default /mnt

	# Initialize EFI system partition
	mkfs.vfat -F 32 -n EFI ${disk}-part1
	mkdir -p /mnt/boot/efi
	mount ${disk}-part1 /mnt/boot/efi

	# Create DATA container dataset
	zfs create -o mountpoint=none zroot/DATA

	# create /home dataset
	zfs create -o mountpoint=legacy zroot/DATA/home
	mkdir -p /mnt/home
	mount -t zfs zroot/DATA/home /mnt/home

	# Create /etc/nixos dataset
	zfs create -o mountpoint=legacy zroot/DATA/nixos
	mkdir -p /mnt/etc/nixos
	mount -t zfs zroot/DATA/nixos /mnt/etc/nixos
}

function initialize_rootfs() {
	local disk=$1

	if [ -z "$disk" ]; then
		echo "usage: $0 /dev/disk/by-id/DISK_ID"
		exit 1
	fi
	
	mv /mnt/etc/nixos/configuration.nix /mnt/etc/nixos/configuration.nix.orig

	cat <<EOF > /mnt/etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./boot.nix
      ./local.nix
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
      efi.efiSysMountPoint = "/boot/efi";

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
      { name = "lvmcrypt"; device = "${disk}-part2"; }
    ];
  };
}
EOF

	cat <<EOF > /mnt/etc/nixos/local.nix
{ config, pkgs, ... }:

{
  networking = {
    hostId = "${hostId}";
    hostName = "nixos";
  };
}
EOF
}

function main() {
	local disk=$1

	if [ -z "$disk" ]; then
		echo "usage: $0 /dev/disk/by-id/DISK_ID"
		exit 1
	fi

	upgrade_installer

	initialize_disk $disk
	
	initialize_rootfs $disk

	# Generate NixOS configs
	nixos-generate-config --root /mnt

	# Install NixOS
	nixos-install 2>&1 | tee install.log

	# Set default boot filesystem
	zpool set bootfs=zroot/ROOT/default zroot
}

main $*
