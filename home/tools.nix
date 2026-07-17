{ pkgs, ... }:
{
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.bat.enable = true;

  # 범용 CLI 도구 (uv/jq/nixd/mcp-nixos/vim 은 이미 configuration.nix systemPackages)
  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    wget
    curl
    unzip
    gnupg
    findutils
    gawk
    gnused
    watch
    htop
    gh
    nixpkgs-fmt
    nodejs_24
    python312
    python312Packages.pip
  ];
}
