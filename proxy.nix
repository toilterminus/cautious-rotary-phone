{ config, pkgs, ... }:

{
  #
  # Route DNS over dnscrypt
  #
  networking.nameservers = [ "127.0.0.1" ];
  services.dnscrypt-proxy.enable = true;
  services.dnscrypt-proxy.extraArgs = [ "-E" ];
  services.dnscrypt-proxy.resolverName = "cs-usnorth";

  #
  # Send everything over an SSH proxy
  #
  networking.firewall.extraCommands = ''
    ip46tables -N nixos-fw-out
    ip46tables -A OUTPUT -j nixos-fw-out
    ip46tables -A nixos-fw-out -o lo -j nixos-fw-accept
    ip46tables -A nixos-fw-out -p tcp --dport 22 -j nixos-fw-accept
    ip46tables -A nixos-fw-out -p udp --sport 68 -j nixos-fw-accept
    ip46tables -A nixos-fw-out -p udp --dport 53 -j nixos-fw-accept
    ip46tables -A nixos-fw-out -p udp --dport 443 -j nixos-fw-accept
    ip46tables -A nixos-fw-out -j nixos-fw-log-refuse
  '';

  networking.firewall.extraStopCommands = ''
    ip46tables -D OUTPUT -j nixos-fw-out
    ip46tables -F nixos-fw-out
    ip46tables -X nixos-fw-out
  '';

  # Enable Polipo to adapt SOCKS to HTTP proxy
  services.polipo.enable = true;
  services.polipo.socksParentProxy = "localhost:1080";

  networking.proxy.default = "http://127.0.0.1:8123";
  #networking.proxy.allProxy = "socks5://127.0.0.1:1080";
  #networking.proxy.httpProxy = "http://127.0.0.1:8123";
  #networking.proxy.httpsProxy = "http://127.0.0.1:8123";
  networking.proxy.noProxy = "127.0.0.1,localhost,.localdomain";
}
