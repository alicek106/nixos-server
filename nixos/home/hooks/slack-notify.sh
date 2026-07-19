#!/usr/bin/env bash
# Notification hook: Claude 완료/입력대기 시 Slack Incoming Webhook 으로 알림 전송.
# 웹훅 URL(시크릿)은 agenix 로 관리한다: /run/agenix/slack-webhook (env-file: SLACK_WEBHOOK_URL=...).
#   → secrets/slack-webhook.age 로 암호화되어 repo 에 있고, 복호화 키는 repo 밖.
#   → 유저(alicek106)가 읽을 수 있게 secrets.nix 에서 owner 지정. (파일 없으면 조용히 종료)
set -uo pipefail

SECRET="/run/agenix/slack-webhook"
[ -r "$SECRET" ] || exit 0
# env-file 을 소싱하지 않고 값만 파싱한다(시크릿 변조 시 임의 코드 실행 방지).
url=$(grep -m1 '^SLACK_WEBHOOK_URL=' "$SECRET" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]')
[ -n "$url" ] || exit 0

input=$(cat)
msg=$(printf '%s' "$input" | jq -r '.message // "작업 완료 / 입력 대기"')
payload=$(jq -n --arg t "Claude Code: $msg" '{text: $t}')

curl -s --max-time 5 -H 'Content-Type: application/json' -d "$payload" "$url" >/dev/null 2>&1 || true
exit 0
