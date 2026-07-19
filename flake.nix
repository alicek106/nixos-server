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

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, home-manager, agenix }:
    let
      system = "x86_64-linux";

      # 오버레이: 다른 nixpkgs 채널을 pkgs.<채널>.* 로 노출한다.
      # 덕분에 모듈에서 `pkgs.unstable.foo` 처럼 패키지 출처가 한눈에 보인다.
      channelsOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };
      };
    in
    {
      # 실제 서버 시스템
      nixosConfigurations.nixos-alicek106 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          agenix.nixosModules.default
          ./nixos/disk-config.nix
          ./nixos/configuration.nix
          { nixpkgs.overlays = [ channelsOverlay ]; }
          # agenix CLI (시크릿 생성/편집: agenix -e)
          { environment.systemPackages = [ agenix.packages.${system}.default ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # 기존 실제 파일(~/.claude/settings.json 등)이 있으면 덮어쓰지 않고 백업
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.alicek106 = import ./nixos/home/alicek106.nix;
          }
        ];
      };

      # 헤드리스 원격 설치용 커스텀 인스톨러 ISO
      #   nix build .#nixosConfigurations.installer.config.system.build.isoImage
      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./installer/installer.nix ];
      };

      # 부트스트랩용 disko CLI — flake.lock 에 핀된 버전을 그대로 사용(재현성).
      #   sudo nix run .#disko -- --mode disko ./nixos/disk-config.nix
      packages.${system}.disko = disko.packages.${system}.disko;
    };
}
