{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106"
  ];

  # usb 부팅 후 필요하다면 도구 추가하면 됨
  environment.systemPackages = [ ];

  networking.hostName = "nixos-installer";
}
