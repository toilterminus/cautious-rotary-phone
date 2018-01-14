{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./boot.nix
      ./local.nix
      #./proxy.nix
      ./system.nix
      ./yubikey.nix
      ./x.nix
    ];
}
