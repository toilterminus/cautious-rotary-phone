{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnupg
  ];

  #
  # Use Yubikeys for GPG/SSH agent
  #
  programs.ssh.startAgent = false;
  programs.gnupg.agent = { enable = true; enableSSHSupport = true; };
  
  services.pcscd.enable = true;
  
  services.udev.extraRules = ''
    ACTION!="add|change", GOTO="u2f_end"

    # Yubico YubiKey
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0113|0114|0115|0116|0120|0402|0403|0406|0407|0410", GROUP="users", MODE="0660"

    LABEL="u2f_end"
  '';
}
