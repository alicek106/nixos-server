#!/usr/bin/env bash
# Notification hook: Claude 완료/입력대기 시 Slack Incoming Webhook 으로 알림 전송.
# 웹훅 URL(시크릿)은 저장소에 올리지 않고 로컬 파일에서 읽는다.
#   → public repo 에 시크릿 노출 없음. (재현적 관리로 올리려면 agenix/sops-nix, README TODO 참고)
set -uo pipefail

URL_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude/slack-webhook"
[ -r "$URL_FILE" ] || exit 0
url=$(head -n1 "$URL_FILE" | tr -d '[:space:]')
[ -n "$url" ] || exit 0

input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // "작업 완료 / 입력 대기"')
payload=$(jq -n --arg t "Claude Code: $msg" '{text: $t}')

curl -s --max-time 5 -H 'Content-Type: application/json' -d "$payload" "$url" >/dev/null 2>&1 || true
exit 0
