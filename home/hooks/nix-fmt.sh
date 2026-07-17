#!/usr/bin/env bash
# PostToolUse hook: 편집된 .nix 파일을 nixpkgs-fmt 로 자동 포맷.
# Claude Code 가 tool 입력 JSON 을 stdin 으로 전달 → file_path 추출.
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

[ -n "$file" ] || exit 0
case "$file" in
  *.nix) [ -f "$file" ] && nixpkgs-fmt "$file" >/dev/null 2>&1 || true ;;
esac
exit 0
