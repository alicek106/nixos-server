{ config, pkgs, ... }:
{
  # 집 공인 IP 변동 시 headscale.alicek106.com A 레코드를 Route53 에 자동 갱신.
  # (호스티드존 ID 는 하드코딩 대신 이름으로 조회)
  systemd.services.ddns-route53 = {
    description = "Update Route53 A record for headscale.alicek106.com to current public IP";
    path = with pkgs; [ awscli2 curl coreutils ];
    onFailure = [ "slack-alert@%n.service" ]; # 실패 시 Slack 통지
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.age.secrets.nixos-credential.path; # AWS_*
      ExecStart = pkgs.writeShellScript "ddns-route53" ''
        set -euo pipefail
        ip=$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')
        zone=$(aws route53 list-hosted-zones-by-name --dns-name alicek106.com \
                 --query 'HostedZones[0].Id' --output text | sed 's#/hostedzone/##')
        if [ -z "$zone" ] || [ "$zone" = "None" ]; then
          echo "hosted zone for alicek106.com not found"; exit 1
        fi
        aws route53 change-resource-record-sets --hosted-zone-id "$zone" --change-batch \
          "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"headscale.alicek106.com\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"$ip\"}]}}]}"
      '';
    };
  };

  systemd.timers.ddns-route53 = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "10min"; # 10분마다 확인
      Persistent = true;
    };
  };
}
