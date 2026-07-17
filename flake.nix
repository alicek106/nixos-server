{
  description = "alicek106 nixos server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # 26.05 보다 새 버전이 필요한 패키지용 (pkgs.unstable.<name> 으로 사용)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, home-manager }:
    let
      system = "x86_64-linux";

      # 오버레이: 다른 nixpkgs 채널을 pkgs.<채널>.* 로 노출한다.
      # 덕분에 모듈에서 `pkgs.unstable.foo` 처럼 패키지 출처가 한눈에 보인다.
      # (특정 옛 버전 고정이 필요하면 여기에 pinned 입력을 추가해 같은 방식으로 노출)
      channelsOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations.nixos-alicek106 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./disk-config.nix
          ./configuration.nix
          { nixpkgs.overlays = [ channelsOverlay ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # 기존 실제 파일(~/.claude/settings.json 등)이 있으면 덮어쓰지 않고 백업
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.alicek106 = import ./home/alicek106.nix;
          }
        ];
      };
    };
}
