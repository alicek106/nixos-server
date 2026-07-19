{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix # agenix 시크릿 중앙 선언
    ./modules/services/aliced.nix
    ./modules/services/gitea.nix
    ./modules/services/headscale.nix
    ./modules/services/tailscale.nix
    ./modules/services/backup.nix
    ./modules/services/ddns.nix
    ./modules/services/slack-alert.nix # systemd 실패 → Slack 알림 (재사용 템플릿)
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-alicek106";
  time.timeZone = "Asia/Seoul";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 오래된 세대 자동 GC + store 중복 제거 → /nix/store 무한 증가 방지 (수동 nix-collect-garbage 불필요)
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;
  zramSwap.enable = true;

  users.users.alicek106 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh; # 기본 로그인 셸 (home-manager 에서 programs.zsh 구성)
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106"
    ];
  };

  # zsh 를 로그인 셸로 쓰려면 시스템 레벨 활성화 필요
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "no";
    settings.KexAlgorithms = [
      "mlkem768x25519-sha256"
      "sntrup761x25519-sha512@openssh.com"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    jq # 유틸리티
    awscli2 # S3 백업 확인·복원 등 운영 명령 (backup/ddns 클로저에 이미 포함되어 추가 비용 ~0)
  ];
  # nixd(Nix LSP)는 home/neovim.nix 가 neovim 래퍼에 번들(neovim 전용).
  # statusline 의존성(bc/gawk/git 등)은 home/claude-code.nix 의 래퍼가 번들한다.
  # MCP 서버(mcp-nixos, mcp-server-fetch)는 home/claude-code.nix 가 store 경로로 참조하므로
  # systemPackages 에 둘 필요 없다. (uv 는 fetch MCP 용이었으나 이제 불필요)
  # claude-code 는 home-manager programs.claude-code 모듈이 소유(설치)한다.

  system.stateVersion = "26.05";
  security.sudo.wheelNeedsPassword = false;

  programs.git = {
    enable = true;
    config = {
      safe.directory = [ "/home/alicek106/nixos-server" ];
    };
  };
}
