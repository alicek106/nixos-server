# nixos-server

alicek106 개인 서버의 NixOS 설정. 시스템·유저 환경(셸/도구/neovim/Claude Code)을 전부 **선언적으로**
관리한다. 이 저장소만으로 새 머신에 설치하면 동일한 환경이 재현된다.

## 디렉터리 구조

```
nixos-server/
├── flake.nix               # 진입점 (nixpkgs 26.05 + disko + home-manager)
├── flake.lock              # 입력 버전 고정 (재현성 핵심 — 수동 편집 금지)
├── configuration.nix       # 시스템 설정 (부트/네트워크/유저/SSH/셸)
├── hardware-configuration.nix  # 자동 생성 (수정 금지)
├── disk-config.nix         # disko 디스크 파티션
└── home/                   # home-manager 유저 환경
    ├── alicek106.nix       # 유저 엔트리 (아래 모듈들을 imports)
    ├── claude-code.nix     # Claude Code (settings + statusline)
    ├── shell.nix           # zsh + starship + fzf + direnv
    ├── tools.nix           # 범용 CLI 도구 (ripgrep/fd/bat/eza/gh 등)
    ├── git.nix             # git 정체성/설정
    ├── neovim.nix          # neovim + 플러그인
    ├── nvim/               # neovim lua 모듈 (ui.lua, lsp.lua)
    └── statusline.sh       # Claude Code 상태줄 스크립트
```

## 적용

```bash
sudo nixos-rebuild switch --flake /home/alicek106/nixos-server#nixos-alicek106
```

---

## 처음부터 재설치 (부트스트랩)

이 저장소만으로 빈 디스크에서 서버를 재구성하는 절차. `disk-config.nix`(disko)가 파티션을,
flake가 시스템·유저 환경을 담당한다.

1. **NixOS 설치 미디어로 부팅** (live USB). 네트워크 연결 확인.
2. **저장소 확보**: `git clone <이 저장소> /tmp/nixos-server && cd /tmp/nixos-server`
   (또는 flake 참조를 직접 사용).
3. **디스크 파티션 + 설치** — disko + nixos-install을 한 번에:
   ```bash
   # 디스크 장치 확인 후(예: /dev/nvme0n1) 실행
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
     --mode disko /tmp/nixos-server/disk-config.nix
   sudo nixos-install --flake /tmp/nixos-server#nixos-alicek106
   ```
   > 디스크 장치명은 `disk-config.nix`의 `/dev/nvme0n1` 기준. 다르면 먼저 맞춘다.
4. **재부팅** 후 SSH 접속(공개키는 선언적으로 이미 등록됨. `configuration.nix` 참고).
5. **설치 후 수동 단계**는 아래 "재현 불가능한 수동 설정"을 따른다 (Claude 인증 등).

이후 설정 변경은 `sudo nixos-rebuild switch --flake .#nixos-alicek106`. (명령 모음은 `CLAUDE.md`)

---

## 재현 불가능한 수동 설정 (Non-declarative)

아래는 nix로 선언할 수 없어(비밀값이거나 클라이언트 측 요구사항) **새로 설치했을 때 수동으로**
맞춰야 하는 항목이다. 나머지는 `nixos-rebuild switch`만으로 완전히 재현된다.

### 1. Claude Code 인증 (필수)
`~/.claude/.credentials.json`의 OAuth 토큰은 비밀값이라 nix로 관리하지 않는다.
설치 후 `claude` 실행 → `/login`으로 로그인해야 Claude Code가 동작한다.
(`~/.claude/settings.json`·상태줄 등 나머지 설정은 전부 선언적으로 재현됨)

### 2. 접속하는 로컬 터미널 요구사항
서버는 헤드리스라 폰트·클립보드를 렌더하지 않는다. 아래는 **접속하는 쪽 터미널**의 조건이다.
- **Nerd Font**: starship 프롬프트·neovim(lualine) 상태줄의 아이콘 글리프가 깨지지 않으려면
  로컬 터미널 폰트가 Nerd Font여야 한다. (예: JetBrainsMono Nerd Font)
- **OSC52 지원**: neovim에서 `yank`한 내용을 로컬 시스템 클립보드로 복사하려면 로컬 터미널이
  OSC52를 지원해야 한다(대부분의 최신 터미널·tmux는 지원). 미지원 시 yank는 nvim 내부 레지스터로만 동작.
- **완료 알림(iTerm2 기준)**: Claude Code 작업 완료 알림을 로컬에서 받으려면 —
  ① macOS 시스템 설정 → 알림 → iTerm2 **알림 허용 ON**,
  ② iTerm2 → Settings → Profiles → Terminal → "Notification Center Alerts" + "Filter Alerts" →
     **"Send escape sequence-generated alerts"** 켜기.
  (서버 sshd 는 `AcceptEnv LC_TERMINAL` 로 iTerm 식별 변수를 받도록 선언돼 있어, 맥이 기본 전달하는
   `LC_TERMINAL` 로 Claude 가 iTerm 을 감지한다. OSC 알림은 iTerm 이 **백그라운드일 때만** 표시됨.)
