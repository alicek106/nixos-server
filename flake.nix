{
  description = "alicek106 nixos server configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, home-manager }: {
    nixosConfigurations.nixos-alicek106 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./disk-config.nix
        ./configuration.nix
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
