{ config, pkgs, ... }:
{
  # headscale 상태(tailnet SoT)를 매일 S3 로 백업.
  #   - db.sqlite: 노드/IP 원장 (일관 스냅샷으로 WAL 안전하게)
  #   - noise_private.key: 컨트롤 서버 정체성 (분실 시 전 노드 재등록)
  # 복원: s3 에서 받아 /var/lib/headscale 에 풀고 rebuild. (README 참고)
  systemd.services.headscale-s3-backup = {
    description = "Backup headscale state to S3";
    path = with pkgs; [ sqlite awscli2 coreutils gnutar gzip ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.age.secrets.nixos-credential.path; # AWS_*
      ExecStart = pkgs.writeShellScript "headscale-s3-backup" ''
        set -eu
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        sqlite3 /var/lib/headscale/db.sqlite ".backup '$tmp/db.sqlite'"
        cp /var/lib/headscale/noise_private.key "$tmp/noise_private.key"
        tar -czf "$tmp/headscale.tar.gz" -C "$tmp" db.sqlite noise_private.key
        aws s3 cp "$tmp/headscale.tar.gz" s3://alicek106-backup/headscale/headscale-backup.tar.gz
      '';
    };
  };

  systemd.timers.headscale-s3-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # 껐다 켜도 놓친 백업 따라잡기
    };
  };
}
