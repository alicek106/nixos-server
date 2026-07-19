# 재사용 가능한 systemd 실패 알림.
#   다른 유닛에서  onFailure = [ "slack-alert@%n.service" ];  로 걸면,
#   그 유닛이 실패했을 때 Slack 으로 "어느 유닛이 실패했는지" 통지한다.
# 백업/복원/DDNS 가 조용히 실패해도 즉시 알 수 있게 하는 안전장치.
{ config, pkgs, ... }:
{
  systemd.services."slack-alert@" = {
    description = "Send Slack alert that %i failed";
    # onFailure 로만 트리거됨 (wantedBy 없음 → 평소엔 안 뜸)
    path = with pkgs; [ curl jq ];
    serviceConfig = {
      Type = "oneshot";
      # slack-webhook.age = env-file (SLACK_WEBHOOK_URL=...). root 서비스라 읽기 가능.
      # 선행 '-' : 시크릿이 아직 없어도(신규배포·미populate) 유닛이 실패하지 않게 optional 로.
      EnvironmentFile = "-${config.age.secrets.slack-webhook.path}";
    };
    scriptArgs = "%i"; # 실패한 유닛 이름을 $1 로 전달
    script = ''
      unit="$1"
      # 웹훅 미설정이면 조용히 종료(알림 유닛 자체가 실패로 남지 않게)
      [ -n "''${SLACK_WEBHOOK_URL:-}" ] || { echo "no SLACK_WEBHOOK_URL — skip alert"; exit 0; }
      payload=$(jq -n --arg t "🚨 [${config.networking.hostName}] systemd 유닛 실패: $unit" '{text: $t}')
      curl -s --max-time 5 -H 'Content-Type: application/json' -d "$payload" "$SLACK_WEBHOOK_URL" >/dev/null || true
    '';
  };
}
