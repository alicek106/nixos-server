# NixOS Server Configuration — alicek106

## Server specs
- CPU: Intel (KVM supported)
- Disk: NVMe (`/dev/nvme0n1`)
- Partitions: GPT + btrfs (zstd compression, subvolumes: root/nix/home/var)
- Boot: systemd-boot + EFI

## Nix layout

```
nixos-server/
├── flake.nix              # entry point (nixpkgs 26.05 + disko + home-manager)
│                          #   outputs: nixosConfigurations.nixos-alicek106 (server) / .installer (ISO)
├── flake.lock
├── nixos/                 # the actual server system config (flake output: .#nixos-alicek106)
│   ├── configuration.nix        # top-level system config
│   ├── hardware-configuration.nix  # auto-generated (do not edit)
│   ├── disk-config.nix          # disko disk partitioning
│   └── home/                    # home-manager user env (shell/tools/git/neovim/claude-code)
└── installer/             # custom ISO for headless remote install (flake output: .#installer)
    └── installer.nix            # installer with sshd + macbook key baked in
```

## Key commands

### Apply configuration
```bash
# rebuild from the flake in the current directory
sudo nixos-rebuild switch --flake /home/alicek106/nixos-server#nixos-alicek106

# test before applying (apply temporarily, no reboot needed)
sudo nixos-rebuild test --flake /home/alicek106/nixos-server#nixos-alicek106

# dry-run (preview the changes)
sudo nixos-rebuild dry-activate --flake /home/alicek106/nixos-server#nixos-alicek106
```

### Search packages and options
```bash
# search packages
nix search nixpkgs <package-name>

# list installed packages
nix-env -q

# search options (local)
nixos-option <option.path>
```

### Garbage collection
```bash
# delete generations older than 30 days
sudo nix-collect-garbage --delete-older-than 30d
```

### Update the flake
```bash
# update inputs (nixpkgs, etc.)
nix flake update
```

## NixOS working rules

### Adding a package
Add to `environment.systemPackages` in `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [ vim claude-code new-package ];
```

### Choosing a package version (channel separation)
The default is `nixpkgs` 26.05. **If you need a newer version**, use `pkgs.unstable.<name>`
(exposed by `channelsOverlay` in flake.nix). Make the source obvious wherever it is used:
```nix
home.packages = with pkgs; [
  ripgrep            # 26.05 (default)
  unstable.someTool  # from nixos-unstable
];
```
**If you need to pin a specific old version** (e.g. Go 1.24.2), add the commit that ships that
version to flake.nix as a named input (look up the exact commit with the nixos MCP `nix_versions`)
and expose it via `channelsOverlay` as `pkgs.<name>`. Do not inline-`import` a commit hash inside a
module. (A pinned commit is also recorded in flake.lock, so reproducibility is preserved.)

### Adding a service
When a service grows, split it into its own file under `modules/services/` and include it via
`imports` in `configuration.nix`:
```nix
imports = [ ./hardware-configuration.nix ./modules/services/nginx.nix ];
```

### Opening firewall ports
```nix
networking.firewall.allowedTCPPorts = [ 22 80 443 ];
```

## Useful URLs
- NixOS option search: https://search.nixos.org/options
- nixpkgs package search: https://search.nixos.org/packages
- NixOS wiki: https://wiki.nixos.org

## Design principles (mandatory)
- **Guarantee reproducibility**: installing NixOS on a new machine using only the files in this
  repo **must produce an identical environment**. Manage all configuration declaratively (in nix).
- **Non-reproducible items go in the README**: if something genuinely cannot be reproduced or is
  not nix-like (manual auth, client-side requirements, etc.), document it in `README.md`. Do not
  hide it as a stopgap inside a nix file.
- **Reinstall procedure also in the README**: keep the instructions for building/installing the
  server from scratch based on this repo (partition → install → post-install manual steps) in
  `README.md`, and update them whenever the related config changes.
- **Best practice + simplicity**: follow NixOS/nix best practices for directory layout and nix
  config as much as possible, but avoid unnecessary complexity. Write it so that someone new to nix
  can read it and follow along without much trouble.
- **Proactively propose workflow improvements**: when you spot repetitive manual work or an
  inefficient workflow, judge whether it is worth turning into a new skill/hook/module/command and
  proactively propose it to the user.

While working, the `nix-change-review` skill (reproducibility/convention/documentation checklist) is
auto-referenced, and there are hooks for auto-formatting after `.nix` edits (nixpkgs-fmt) and for
reproducibility-smell detection on stop (declared in `nixos/home/claude-code.nix`).

## Working & communication principles (mandatory)
- **Assume the user can also be wrong**: do not uncritically accept the user's opinions, claims, or
  instructions. Always verify against evidence, and if something is factually off or there is a
  better approach, **clearly push back / offer an alternative instead of agreeing just to agree**.
  (Always leave open the possibility that the user is wrong.)
- **Summarize before and after work**: **before starting and after finishing** a task, always
  briefly summarize **what / how / why** you did.

## Important cautions
- Never edit `hardware-configuration.nix` by hand (auto-generated by nixos-generate-config).
- Never change `system.stateVersion` (pinned to the version at first install).
- Always git commit after applying config (keep a rollback reference point).
- Never write secrets (API keys, passwords) in plaintext in nix files → use sops-nix or agenix.
- **When running build-type commands like `nix build` / `nixos-rebuild`, you MUST clearly and
  strongly tell the user "I'm building nix now" before running it.** (Make it clear this is a
  time/resource-consuming operation.)

## Currently open ports
- 22: SSH (ed25519 key auth only, root login disabled)
- 80/443 (TCP): nginx — headscale control plane (443 TLS) + HTTP→HTTPS redirect (80). (`modules/services/headscale.nix`)
- 3478/41641 (UDP): Tailscale STUN (3478) · WireGuard direct connection (41641). The router must also
  forward this UDP for direct P2P (falls back to DERP relay if not forwarded).
- gitea (3000) · aliced (8080) bind only to the tailnet IP (100.64.0.2) → not opened in the firewall (zero external exposure).
