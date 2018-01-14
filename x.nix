{ config, pkgs, ... }:

{
  i18n.consoleUseXkbConfig = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    libinput.enable = true;
    libinput.buttonMapping = "1 2 3";
    libinput.naturalScrolling = true;
    libinput.tapping = false;

    displayManager.lightdm.enable = true;

    windowManager.i3.enable = true;

    xkbOptions = "ctrl:nocaps";
  };

  services.compton.enable = true;

  services.redshift.enable = true;
  services.redshift.latitude = "40.665535";
  services.redshift.longitude = "-73.969749";
}
