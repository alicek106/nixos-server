# NixOS Server Configuration — alicek106

## 서버 사양
- CPU: Intel (KVM 지원)
- 디스크: NVMe (`/dev/nvme0n1`)
- 파티션: GPT + btrfs (zstd 압축, subvolumes: root/nix/home/var)
- 부트: systemd-boot + EFI

## Nix 구성 구조

```
nixos-server/
├── flake.nix              # 진입점, nixpkgs 26.05 + disko
├── flake.lock
├── configuration.nix      # 최상위 시스템 설정
├── hardware-configuration.nix  # 자동 생성 (수정 금지)
├── disk-config.nix        # disko 디스크 파티션 설정
└── modules/               # 서비스·기능별 분리 모듈 (필요시 추가)
```

## 핵심 명령어

### 설정 적용
```bash
# 현재 디렉터리의 flake로 rebuild
sudo nixos-rebuild switch --flake /home/alicek106/nixos-server#nixos-alicek106

# 적용 전 테스트 (재부팅 없이 일시 적용)
sudo nixos-rebuild test --flake /home/alicek106/nixos-server#nixos-alicek106

# dry-run (변경 사항 미리 보기)
sudo nixos-rebuild dry-activate --flake /home/alicek106/nixos-server#nixos-alicek106
```

### 패키지 및 옵션 검색
```bash
# 패키지 검색
nix search nixpkgs <패키지명>

# 설치된 패키지 목록
nix-env -q

# 옵션 검색 (로컬)
nixos-option <option.path>
```

### 가비지 컬렉션
```bash
# 30일 이전 세대 삭제
sudo nix-collect-garbage --delete-older-than 30d
```

### 플레이크 업데이트
```bash
# nixpkgs 등 inputs 업데이트
nix flake update
```

## NixOS 작업 규칙

### 패키지 추가
`configuration.nix`의 `environment.systemPackages`에 추가:
```nix
environment.systemPackages = with pkgs; [ vim claude-code 새패키지 ];
```

### 서비스 추가
서비스가 커지면 `modules/services/` 아래 별도 파일로 분리하고 `configuration.nix`에 `imports`로 포함:
```nix
imports = [ ./hardware-configuration.nix ./modules/services/nginx.nix ];
```

### 방화벽 포트 개방
```nix
networking.firewall.allowedTCPPorts = [ 22 80 443 ];
```

## 주요 URL
- NixOS 옵션 검색: https://search.nixos.org/options
- nixpkgs 패키지 검색: https://search.nixos.org/packages
- NixOS 위키: https://wiki.nixos.org

## 중요 주의사항
- `hardware-configuration.nix`는 수동 수정 금지 (nixos-generate-config 자동 생성)
- `system.stateVersion`은 절대 변경 금지 (최초 설치 시의 버전 고정)
- 설정 적용 후 git commit 필수 (rollback 기준점 유지)
- 비밀값(API 키, 비밀번호)은 절대 nix 파일에 평문으로 작성 금지 → sops-nix 또는 agenix 사용

## 현재 열려 있는 포트
- 22: SSH (ed25519 키 인증 전용, root 로그인 불가)
