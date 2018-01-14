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
      { name = "lvmcrypt"; device = "/dev/nvme0n1p2"; }
    ];
  };
}
