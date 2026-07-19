{ ... }:
{
  imports = [
    ./claude-code.nix
    ./shell.nix
    ./tools.nix
    ./git.nix
    ./neovim.nix
  ];

  home.username = "alicek106";
  home.homeDirectory = "/home/alicek106";

  # stateVersion 은 최초 도입 버전으로 고정 (변경 금지)
  home.stateVersion = "26.05";
}
