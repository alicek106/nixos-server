#!/usr/bin/env bash
# Notification hook: Claude 완료/입력대기 시 ntfy 로 알림 전송.
# 엔드포인트(URL+토픽)는 저장소에 올리지 않고 로컬 파일에서 읽는다.
#   → public repo 에 토픽/비밀 노출 없음. 나중에 self-host URL 로 바꿀 때 이 파일만 수정.
set -uo pipefail

URL_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude/ntfy-url"
[ -r "$URL_FILE" ] || exit 0
url=$(head -n1 "$URL_FILE" | tr -d '[:space:]')
[ -n "$url" ] || exit 0

input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // "작업 완료 / 입력 대기"')

curl -s --max-time 5 -H "Title: Claude Code" -d "$msg" "$url" >/dev/null 2>&1 || true
exit 0
