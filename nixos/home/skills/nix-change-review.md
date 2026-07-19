---
name: nix-change-review
description: Use when creating or modifying any Nix code in this repo (*.nix files, flake.nix, home-manager modules under home/, package derivations, configuration.nix). Reviews the change for reproducibility, project conventions/best-practices, and README documentation duties before finishing.
---

# Nix 변경 검토 (nix-change-review)

이 저장소(`nixos-server`)에서 nix 코드를 만들거나 고칠 때 **작업을 마치기 전에** 아래를 스스로 점검한다.
저장소의 대원칙은 `CLAUDE.md`의 "설계 원칙"에 있다: 재현성 보장 / 재현 불가 항목은 README에 / best-practice + 단순성.

## 1. 재현성 (가장 중요)
새 머신에 이 저장소만으로 설치해도 동일한 결과가 나와야 한다. 아래 "재현 불가 냄새"가 없는지 확인:
- 해시 없는 `fetchurl`/`fetchFromGitHub`/`fetchgit` (반드시 `hash`/`sha256` 고정)
- 런타임 다운로드: `uvx`, `npx ... @latest`, `pip install`, `curl | sh` 등 (→ nix 패키지로 고정)
- `builtins.currentTime`, `builtins.getEnv` 등 비결정적 입력
- `/home/...`·`/Users/...` 절대경로 하드코딩 (→ `config.home.homeDirectory` 등 사용)
- 바이너리를 PATH에 의존해 호출 (→ 가능하면 `${pkgs.foo}/bin/foo` store 경로 참조)
- `flake.lock`이 커밋되었는지 (입력 버전 고정의 핵심)

## 2. 컨벤션 / 구조
- 패키지 위치: 시스템 전역·서비스·root용 → `configuration.nix`, 개인 유저 환경 → `home/*.nix`
- 버전 채널: 기본은 26.05(`pkgs.foo`), 더 새 버전은 `pkgs.unstable.foo` (flake.nix `channelsOverlay`).
  특정 옛 버전은 이름 있는 입력 + `channelsOverlay`로 노출 (커밋 해시 인라인 import 금지)
- 모듈은 작고 단일 목적으로 (`home/shell.nix`, `home/git.nix`처럼). `home/alicek106.nix`의 `imports`에 연결
- **단순성**: nix 초보자가 읽어도 이해할 수준으로. 불필요한 추상화·복잡성 회피
- 셸/lua 등은 별도 파일(`home/statusline.sh`, `home/nvim/*.lua`)로 두고 nix로 래핑

## 3. 문서화 의무 (README.md)
- **재현 불가 / nix스럽지 않은 설정이 반드시 필요하면** → 반드시 `README.md`의 "재현 불가능한 수동 설정"에 명시.
  nix 파일 안에 임시방편으로 숨기지 않는다.
- **처음부터 재빌드/재설치할 때 필요한 행동 지침**(부트스트랩: 파티션→설치→설치 후 수동 단계)이
  바뀌면 → `README.md`의 설치/부트스트랩 섹션을 최신으로 유지한다.

## 4. 마무리
- `nix flake check`로 평가 통과 확인. 가능하면 `nixos-rebuild test`로 활성화까지 검증.
- 빌드성 명령(`nix build`/`nixos-rebuild`) 실행 시 "지금 nix를 빌드한다"는 사실을 사용자에게 강하게 알린다.
- 적용·검증 후 git commit (rollback 기준점).

## 5. 워크플로 개선 제안
반복되는 수작업이나 비효율이 보이면, 새 skill·hook·모듈로 만들 가치가 있는지 판단해 사용자에게 자율적으로 제안한다.
