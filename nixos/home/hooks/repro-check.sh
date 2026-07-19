#!/usr/bin/env bash
# Stop hook: 작업 종료 시 git diff 에서 "재현 불가 냄새"를 기계적으로 탐지해 경고(비차단).
# 확신 가능한 패턴만 검사하며, 새로 들어온 nix 변경에 한해 본다. 오탐이어도 무해한 알림.
# (set -e 는 쓰지 않는다 — grep 무매칭 exit 1 로 조기 종료되면 안 되므로)
set -uo pipefail

# nix 파일 변경이 없으면 조용히 통과
changed=$( { git diff --name-only HEAD; git diff --name-only --cached; } 2>/dev/null )
printf '%s\n' "$changed" | grep -q '\.nix$' || exit 0

# 추가된(+) 라인만 대상으로 냄새 검사
added=$( { git diff HEAD -- '*.nix'; git diff --cached -- '*.nix'; } 2>/dev/null \
         | grep -E '^\+' | grep -vE '^\+\+\+' )

smells=""
printf '%s\n' "$added" | grep -qE 'uvx|npx .*@latest|pip install|curl .*\| *sh' \
  && smells="${smells}\n  - 런타임 다운로드(uvx/npx@latest/pip/curl|sh) — nix 패키지로 고정 필요"
if printf '%s\n' "$added" | grep -qE 'fetch(url|git|FromGitHub)' \
   && ! printf '%s\n' "$added" | grep -qE 'hash|sha256'; then
  smells="${smells}\n  - 해시 없는 fetch* — hash/sha256 고정 필요"
fi
printf '%s\n' "$added" | grep -qE '/(home|Users)/[a-zA-Z]' \
  && smells="${smells}\n  - 절대 홈 경로 하드코딩 — config.home.homeDirectory 등 사용 권장"

[ -z "$smells" ] && exit 0

# README 가 함께 수정되지 않았으면 문서화 리마인드
note=""
printf '%s\n' "$changed" | grep -q 'README.md' \
  || note="\n  → 재현 불가 요소라면 README.md 에 반드시 명시할 것."

printf '⚠️  재현성 점검(자동): nix 변경에서 다음 패턴이 감지됨:%b%b\n' "$smells" "$note" >&2
exit 0
