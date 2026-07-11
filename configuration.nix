{ config, lib, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-alicek106";
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  zramSwap.enable = true;

  users.users.alicek106 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106"
    ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
    settings.KexAlgorithms = [
      "mlkem768x25519-sha256"
      "sntrup761x25519-sha512@openssh.com"
    ];
  };

  environment.systemPackages = with pkgs; [ vim git ];

  system.stateVersion = "26.05";
}
