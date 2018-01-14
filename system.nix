{ config, pkgs, ... }:

{
  networking = {
    networkmanager = {
      enable = true;
      dhcp = "internal";
    };
  };

  hardware.bluetooth.enable = false;
  hardware.bluetooth.powerOnBoot = false;

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # Just enough packages to bootstrap configuration from git repos in GCP
    git google-cloud-sdk nvi
  ];

  security.sudo.enable = false;

  system.autoUpgrade.enable = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "17.09"; # Did you read the comment?
  
  time.timeZone = "US/Eastern";
  
  virtualisation.docker.enable = true;
}
