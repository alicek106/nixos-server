{ modulesPath, ... }:
{
  # NixOS 최소 설치 ISO 를 기반으로, 헤드리스 원격 설치가 되도록 커스터마이즈.
  #   빌드:  nix build .#nixosConfigurations.installer.config.system.build.isoImage
  #   결과:  result/iso/*.iso  → USB 로 구워 부팅
  # 부팅 후 맥북에서 바로 SSH 접속 가능(아래 키) → nixos-anywhere 또는 수동 설치.
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # SSH 로 원격 접속 (모니터/키보드 불필요)
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password"; # 키 전용
  };

  # 맥북 공개키 (이 서버 configuration.nix 의 authorizedKeys 와 동일 — 같은 클라이언트)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106"
  ];

  # 설치 작업에 유용한 도구
  environment.systemPackages = [ ];

  networking.hostName = "nixos-installer";
}
