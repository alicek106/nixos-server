# nixos-server

alicek106 개인 서버의 NixOS 설정. 시스템·유저 환경(셸/도구/neovim/Claude Code)을 전부 **선언적으로**
관리한다. 이 저장소만으로 새 머신에 설치하면 동일한 환경이 재현된다.

## 디렉터리 구조

```
nixos-server/
├── flake.nix               # 진입점 (outputs: .#nixos-alicek106 서버 / .#installer ISO)
├── flake.lock              # 입력 버전 고정 (재현성 핵심 — 수동 편집 금지)
├── nixos/                  # 실제 서버 시스템
│   ├── configuration.nix       # 시스템 설정 (부트/네트워크/유저/SSH/셸)
│   ├── hardware-configuration.nix  # 자동 생성 (수정 금지)
│   ├── disk-config.nix         # disko 디스크 파티션
│   └── home/                   # home-manager 유저 환경
│       ├── alicek106.nix       # 유저 엔트리 (아래 모듈들을 imports)
│       ├── claude-code.nix     # Claude Code (settings + statusline + hooks)
│       ├── shell.nix           # zsh + starship + fzf + direnv
│       ├── tools.nix           # 범용 CLI 도구 (ripgrep/fd/bat/eza/gh 등)
│       ├── git.nix             # git 정체성/설정
│       ├── neovim.nix          # neovim + 플러그인
│       ├── nvim/               # neovim lua 모듈 (ui.lua, lsp.lua)
│       └── statusline.sh       # Claude Code 상태줄 스크립트
└── installer/              # 헤드리스 원격 설치용 커스텀 ISO
    └── installer.nix           # sshd + 맥북 키가 구워진 인스톨러
```

## 커스텀 설치 ISO

헤드리스(모니터 없이) 재설치용. sshd + 맥북 공개키가 구워진 ISO 를 빌드한다:
```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
# result/iso/*.iso 를 USB 로 구워 부팅 → 맥북에서 바로 SSH 접속 가능
```
이후 설치는 아래 부트스트랩(또는 nixos-anywhere) 절차를 따른다.

## 적용

```bash
sudo nixos-rebuild switch --flake /home/alicek106/nixos-server#nixos-alicek106
```

---

## 운영 가이드 (AI 없이 직접 실행)

이 서버를 손으로 운영할 때 필요한 명령 모음. 모든 경로는 저장소 루트(`/home/alicek106/nixos-server`) 기준.
설정을 바꾼 뒤에는 **항상 git commit** 한다(rollback 기준점).

### 설정 적용 / 검증 / 되돌리기
```bash
nix flake check                                          # 문법·assertion 검증 (빌드 없이 빠름)
sudo nixos-rebuild dry-activate --flake .#nixos-alicek106  # 뭐가 바뀌는지 미리 보기
sudo nixos-rebuild test   --flake .#nixos-alicek106      # 재부팅 없이 임시 적용(부트 항목 안 만듦)
sudo nixos-rebuild switch --flake .#nixos-alicek106      # 실제 적용 + 부트 세대 생성
sudo nixos-rebuild switch --rollback                     # 방금 적용이 문제면 직전 세대로 복귀
```
> `switch`/`test`/`dry-activate`·`nix build`·ISO 빌드는 **시간·리소스가 드는 빌드 작업**이다.

### 시크릿 편집 (agenix)
시크릿은 `nixos/secrets/*.age`(암호화되어 repo 에 커밋됨). 복호화 신원은 **서버 SSH 호스트키**다
(수신자 = 맥북키 + 이 서버 호스트키). 편집은 반드시 `nixos/secrets/` 에서(agenix 가 cwd 의 `secrets.nix` 를 읽음):
```bash
cd nixos/secrets
sudo EDITOR=vim agenix -e nixos-credential.age -i /etc/ssh/ssh_host_ed25519_key
#   -i : alicek106 유저엔 개인키가 없으니 수신자인 호스트키를 명시 (sudo 로 읽음)
#   에디터가 평문을 열어줌 → 저장하면 모든 수신자로 재암호화
```
- **새 시크릿 추가**: `secrets.nix` 에 `"이름.age".publicKeys = [ alice server ];` 규칙 추가 → 위 `-e 이름.age` 로 편집.
- **시크릿 제거**: `secrets.nix` 에서 해당 규칙 줄 삭제 → `git rm nixos/secrets/이름.age`.
- **수신자(키) 변경 후 전체 재암호화**: `cd nixos/secrets && sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key`
- ⚠️ **시크릿 내용만 바꾸면 컨테이너는 자동 재시작 안 됨** — 반영하려면 아래 컨테이너 재시작 필요.
  (`.nix` 파일이 바뀌면 rebuild 가 알아서 재시작하지만, `.age` 내용 변경은 유닛 정의가 그대로라 감지 못 함)

### 컨테이너 (aliced / gitea)
```bash
sudo podman ps                                # 실행 중 컨테이너
sudo systemctl restart podman-aliced          # 재시작 (시크릿 내용 바꾼 뒤 필수)
sudo systemctl restart podman-gitea
sudo journalctl -u podman-aliced -f           # 실시간 로그 (백업 진행 등 확인)
```

### Headscale (mesh VPN 컨트롤)
```bash
sudo headscale nodes list                     # 등록된 노드·IP (서버=ID 2 / 100.64.0.2)
sudo headscale users  list
sudo headscale users  create alicek106        # 최초 1회
sudo headscale preauthkeys create --user 1 --reusable --expiration 24h   # --user 는 숫자 ID
sudo headscale nodes  set-ip 2 100.64.0.2     # 서버 tailnet IP 재고정 (복원 후 어긋났을 때)
```

### 백업 / DDNS (타이머로 자동, 수동 실행도 가능)
```bash
systemctl list-timers                                    # ddns(10분)·headscale-backup(매일)·acme-renew 확인
sudo systemctl start headscale-s3-backup.service         # headscale 상태 즉시 백업
sudo systemctl start ddns-route53.service                # 공인 IP → Route53 A 즉시 갱신
sudo journalctl -u headscale-s3-backup -n 50             # 결과 로그
```

### S3 백업 내용 확인 (자격증명 소싱)
`aws` 는 systemPackages 에 있고, 자격증명은 활성화 시 `/run/agenix/nixos-credential` 로 복호화돼 있다:
```bash
sudo bash -c 'set -a; . /run/agenix/nixos-credential; set +a; \
  aws s3 ls s3://alicek106-backup/ --recursive | head'
# aliced 일기 → s3://alicek106-backup/aliced/ , headscale → s3://alicek106-backup/headscale/
```

### 정리 (디스크 회수)
```bash
sudo nix-collect-garbage --delete-older-than 30d         # 30일 이전 세대 삭제
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

### 3. Slack 완료 알림 (Webhook)
Claude 완료/입력대기 알림은 `home/claude-code.nix`의 Notification 훅이 Slack Incoming Webhook 으로 보낸다.
웹훅 URL 은 **시크릿**이라 저장소가 아니라 **서버의 로컬 파일에서 읽는다** (public repo에 노출 금지):
- Slack 에서 Incoming Webhook 생성 → 받은 URL (`https://hooks.slack.com/services/...`) 을
  서버 `~/.config/claude/slack-webhook` 파일 첫 줄에 저장:
  ```
  https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
  ```
  (파일이 없으면 훅은 조용히 아무것도 안 함)
- 받는 쪽: 맥/폰의 Slack 앱에서 해당 채널 알림을 받으면 됨.

> **TODO(시크릿 관리 승격)**: 현재 웹훅 URL 은 repo 밖 파일(수동 배치)로 둔다. agenix 가 이미 도입돼
> 있으니(`nixos/secrets/`), 이 웹훅도 `.age` 로 암호화해 repo 에 커밋하도록 승격할 수 있다.

### 4. 컨테이너 상태 데이터 (aliced / gitea)
컨테이너의 실제 데이터는 nix 로 재현되지 않는 상태(state)라 repo 밖에 있고, 재설치 시 별도 복원한다.
- **aliced** (`/var/lib/aliced/data`): 빈 상태로 뜨면 앱이 **S3 백업에서 자동 복원** → 별도 조치 불필요.
  백업 위치는 `s3://alicek106-backup/aliced/` (버킷·prefix 는 `aliced.nix` 의 `S3_BUCKET_NAME`/`S3_BACKUP_PREFIX`).
- **gitea** (`/var/lib/gitea`): 자동 복원 없음 → **수동 복원** 필요.
  - 옛 서버: `sudo podman stop gitea && sudo tar -czpf gitea-data.tar.gz -C <gitea data 경로> .`
  - 이 서버: `sudo tar -xzpf gitea-data.tar.gz -C /var/lib/gitea` (권한 보존 `-p`) → 그 뒤 rebuild.
- 시크릿(`aliced-env` 등)은 agenix 로 관리(암호화되어 repo 에 있음, 복호화 키는 repo 밖 — 위 부트스트랩 참조).

### 5. Headscale mesh VPN (컨트롤 플레인 + tailnet 상태)
`headscale.nix`/`tailscale.nix`/`ddns.nix`/`backup.nix` 는 선언적이지만, 아래는 nix 밖의 수동/런타임 항목이다.

**선행 인프라 (1회, nix 밖):**
- **공유기 포트포워딩**: TCP **443**(컨트롤/DERP-over-HTTPS), UDP **3478**(STUN)·**41641**(WireGuard 직접) → 홈서버.
- **Route53 A 레코드**: `headscale.alicek106.com` → 현재 집 공인 IP (최초 1회. 이후 `ddns-route53` 타이머가 10분마다 자동 UPSERT).
- **통합 AWS 자격증명** `nixos-credential.age`: `alicek106.com` Route53 편집 + `alicek106-backup` S3 읽기/쓰기 권한.
  ACME DNS-01, DDNS, S3 백업, aliced 가 공유한다. `agenix -e nixos-credential.age` 로 편집
  (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION` env-file 형식).

**노드 등록 (런타임):**
1. 서버에서 유저·preauth 키 생성:
   ```
   sudo headscale users create alicek106      # 최초 1회 (유저 ID 확인: headscale users list)
   sudo headscale preauthkeys create --user 1 --reusable --expiration 24h   # --user 는 숫자 ID
   ```
2. 클라이언트(맥북 등): Tailscale 앱 설치 후
   ```
   tailscale up --login-server https://headscale.alicek106.com --authkey <위 키>
   ```
3. 서버 자신도 tailnet 노드 → 같은 방식으로 `tailscale up`. 서버 IP 는 `100.64.0.2` 로 고정(아래 복원 참조).

**상태 복원 (SoT = S3, 자동):** tailnet 원장(`db.sqlite`)과 컨트롤 서버 정체성(`noise_private.key`)은 headscale DB 라
nix 로 재현되지 않는 상태다. 이를 위해:
- 매일 `headscale-s3-backup` 타이머가 `db.sqlite`+`noise_private.key` 를 `s3://alicek106-backup/headscale/headscale-backup.tar.gz` 로 백업.
- **부팅 시 자동 복원**(`headscale-s3-restore`, `backup.nix`): headscale 기동 "전에" 실행돼,
  로컬 상태가 **비어 있고 & S3 백업이 있을 때만** 복원한다(기존 상태가 있으면 건드리지 않음).
  → **서버를 새로 밀고 rebuild 만 해도** 원장·정체성이 자동 복구돼 노드 재등록·서버 IP 변동이 없다(aliced self-restore 와 대칭).
- 수동 복원(자동이 실패했거나 특정 시점으로 되돌릴 때 fallback):
  ```bash
  sudo systemctl stop headscale                       # 1. 현재 상태 사용 중단
  sudo aws s3 cp s3://alicek106-backup/headscale/headscale-backup.tar.gz - \
    | sudo tar -xz -C /var/lib/headscale               # 2. 백업으로 db.sqlite+키 덮어쓰기
  sudo chown -R headscale:headscale /var/lib/headscale # 3. 소유권 정합 (root 로 풀었으므로)
  sudo systemctl start headscale                       # 4. 원래 원장/정체성으로 기동
  ```
  (`noise_private.key` = 컨트롤 서버 정체성. 분실 시 전 노드 재등록 필요.)
- 서버 tailnet IP 고정: 컨테이너가 `100.64.0.2` 에 바인딩하므로 복원 후 이 값이 유지돼야 한다.
  혹시 새 노드로 등록됐다면 `sudo headscale nodes set-ip 2 100.64.0.2` 로 맞춘다 (노드 ID 는 `headscale nodes list`).
