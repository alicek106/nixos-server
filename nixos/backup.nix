{ config, pkgs, ... }:
{
  # headscale 상태(tailnet SoT)를 매일 S3 로 백업하고, 상태가 없으면 부팅 시 자동 복원.
  #   - db.sqlite: 노드/IP 원장 (일관 스냅샷으로 WAL 안전하게)
  #   - noise_private.key: 컨트롤 서버 정체성 (분실 시 전 노드 재등록)

  # --- 자동 복원: headscale 기동 전에, 상태가 비어 있고 S3 백업이 있을 때만 복원 ---
  # 재설치 후 첫 부팅에서 headscale 이 throwaway 상태를 만들기 "전에" 원장/정체성을 되돌린다.
  # aliced 가 앱 코드로 self-restore 하는 것과 대칭. 기존 상태가 있으면 절대 건드리지 않음(클로버 방지).
  systemd.services.headscale-s3-restore = {
    description = "Restore headscale state from S3 if local state is empty";
    before = [ "headscale.service" ];
    wantedBy = [ "headscale.service" ]; # headscale 이 켜질 때 함께 당겨짐
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ]; # S3 접근에 네트워크 필요
    path = with pkgs; [ awscli2 coreutils gnutar gzip ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "headscale"; # StateDirectory 소유자와 동일 → 복원 파일 소유권 자동 정합
      Group = "headscale";
      StateDirectory = "headscale"; # /var/lib/headscale 를 headscale:headscale 로 보장 생성
      EnvironmentFile = config.age.secrets.nixos-credential.path; # AWS_*
      ExecStart = pkgs.writeShellScript "headscale-s3-restore" ''
        set -eu
        if [ -f /var/lib/headscale/db.sqlite ]; then
          echo "headscale state present — skip restore"; exit 0
        fi
        if ! aws s3 ls s3://alicek106-backup/headscale/headscale-backup.tar.gz >/dev/null 2>&1; then
          echo "no S3 backup found — fresh start (nothing to restore)"; exit 0
        fi
        echo "empty state + S3 backup exists → restoring…"
        aws s3 cp s3://alicek106-backup/headscale/headscale-backup.tar.gz - \
          | tar -xz -C /var/lib/headscale
        echo "headscale state restored from S3"
      '';
    };
  };

  # --- 백업: 매일 S3 로 업로드 ---
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

  # ============================================================================
  # gitea 상태(repos + sqlite DB + conf)를 매일 S3 로 백업하고, 비어 있으면 자동 복원.
  # aliced(앱 self-restore)·headscale 와 동일한 "empty 일 때만 복원" 패턴.
  # 소유권이 혼합(git/gitea=uid 1000, ssh=root)이라 root + --numeric-owner 로 보존한다.
  # ============================================================================

  # --- 자동 복원: podman-gitea 기동 전에, 상태가 비어 있고 S3 백업이 있을 때만 복원 ---
  systemd.services.gitea-s3-restore = {
    description = "Restore gitea state from S3 if local state is empty";
    before = [ "podman-gitea.service" ];
    wantedBy = [ "podman-gitea.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ awscli2 coreutils gnutar gzip ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # root 로 실행(User= 없음): 혼합 소유권(0/1000)을 --numeric-owner 로 그대로 복원해야 함.
      EnvironmentFile = config.age.secrets.nixos-credential.path; # AWS_*
      ExecStart = pkgs.writeShellScript "gitea-s3-restore" ''
        set -eu
        if [ -f /var/lib/gitea/gitea/gitea.db ]; then
          echo "gitea state present — skip restore"; exit 0
        fi
        if ! aws s3 ls s3://alicek106-backup/gitea/gitea-backup.tar.gz >/dev/null 2>&1; then
          echo "no S3 backup found — fresh start (nothing to restore)"; exit 0
        fi
        echo "empty state + S3 backup exists → restoring…"
        mkdir -p /var/lib/gitea
        aws s3 cp s3://alicek106-backup/gitea/gitea-backup.tar.gz - \
          | tar -xzp --numeric-owner -C /var/lib/gitea
        echo "gitea state restored from S3"
      '';
    };
  };

  # --- 백업: 매일 무중단 스냅샷 → S3 ---
  systemd.services.gitea-s3-backup = {
    description = "Backup gitea state to S3";
    path = with pkgs; [ sqlite awscli2 coreutils gnutar gzip ];
    serviceConfig = {
      Type = "oneshot";
      # root 로 실행: cp -a 로 0/1000 소유권 보존 + tar --numeric-owner.
      EnvironmentFile = config.age.secrets.nixos-credential.path; # AWS_*
      ExecStart = pkgs.writeShellScript "gitea-s3-backup" ''
        set -eu
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        # 트리 전체를 스테이징(5MB, 즉시). ⚠️ gitea/conf/app.ini 는 절대 제외 금지 —
        # 그 안의 SECRET_KEY/INTERNAL_TOKEN 이 DB 암호화·인증과 짝이라, DB 와 함께 보관해야
        # 복원 후 복호화/세션이 깨지지 않는다. (db-only 로 "최적화"하면 조용히 망가짐)
        cp -a /var/lib/gitea "$tmp/tree"
        # 라이브 DB 대신 일관 스냅샷으로 교체(WAL 안전). wal/shm 은 스냅샷에 불필요.
        sqlite3 /var/lib/gitea/gitea/gitea.db ".backup '$tmp/tree/gitea/gitea.db'"
        rm -f "$tmp/tree/gitea/gitea.db-wal" "$tmp/tree/gitea/gitea.db-shm"
        tar -czpf "$tmp/gitea.tar.gz" --numeric-owner -C "$tmp/tree" .
        aws s3 cp "$tmp/gitea.tar.gz" s3://alicek106-backup/gitea/gitea-backup.tar.gz
      '';
    };
  };

  systemd.timers.gitea-s3-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
