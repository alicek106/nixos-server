# S3 상태 백업/복원 — headscale 와 gitea 를 하나의 공통 팩토리(mkS3BackupPair)로 생성.
# aliced 는 앱 코드가 자체 복원하므로 여기 없음.
#
# 공통 안전장치 (전 서비스 동일하게 강제):
#   - fail-closed 존재확인: head-object 가 404(없음)일 때만 "신규배포"로 통과,
#     그 외 에러(403/네트워크/자격증명)는 유닛을 실패시킨다 → 빈 상태로 기동 안 함.
#   - 다운로드 → gzip -t 검증 → 추출: 부분 다운로드/손상 tarball 을 추출 전에 차단.
#   - 복원 실패 시 본체 기동 차단: restore 를 requiredBy(=Requires)+before 로 걸어,
#     복원이 실패하면 headscale/gitea 가 아예 안 뜬다(빈 상태 생성→백업 덮어쓰기 방지).
#   - 빈 상태 업로드 거부: 로컬 상태(sentinel)가 없으면 백업을 거부(심층 방어).
#   - set -euo pipefail, PrivateTmp, 실패 시 Slack 알림(onFailure), 타이머 지터.
#
# ⚠️ 이 fail-closed 는 자격증명이 없는 키에 '404'를 돌려준다는 전제(현재 IAM 은 ListBucket 보유).
#    IAM 을 최소권한으로 좁혀 ListBucket 을 빼면 403 이 되어 신규배포가 막히니 주의.
#    최종 안전망은 S3 버킷 버저닝(README 참고).
#
# 알려진 보류(현재 규모에선 무해, 데이터 커지면 재검토):
#   - gitea 백업의 cp -a 트리 복사 + 압축본은 PrivateTmp(tmpfs=RAM)에 놓인다. repo 가 수백MB+ 로
#     커지면 tar in-place(+--exclude db, 스냅샷 주입)로 바꿔 RAM 사용을 줄일 것. (지금 ~5MB)
#   - 복원은 우리가 만든 tarball 을 root+--numeric-owner 로 전개한다. GNU tar 기본이 절대경로/`..`
#     이탈을 막아 stateDir 밖으로는 못 나가지만, S3 오염 시의 잔여 위험은 남는다 → S3 접근제어+버저닝으로 완화.
{ config, pkgs, lib, ... }:
let
  bucket = "alicek106-backup";
  cred = config.age.secrets.nixos-credential.path;

  mkS3BackupPair =
    { name # "headscale" | "gitea"
    , mainUnit # 이 상태에 의존하는 본체 유닛
    , stateDir # /var/lib/<x>
    , sentinel # 존재 시 "상태 있음" (복원 skip / 백업 허용 조건)
    , s3key # 버킷 내 키
    , extractFlags # 추출 tar 플래그 (headscale: -xz / gitea: -xzp --numeric-owner)
    , backupBuild # $tmp/backup.tar.gz 를 만드는 셸 (서비스별)
    , backupPath ? [ ] # 백업에 필요한 추가 pkgs (예: sqlite)
    , user ? null # null = root
    }:
    let
      onFailure = [ "slack-alert@%n.service" ];
      s3tools = with pkgs; [ awscli2 coreutils gnutar gzip ];
    in
    {
      # --- 복원: 본체 기동 전에, 상태가 비어 있고 S3 백업이 있을 때만 ---
      systemd.services."${name}-s3-restore" = {
        description = "Restore ${name} state from S3 if local state is empty";
        before = [ mainUnit ];
        requiredBy = [ mainUnit ]; # 복원 실패 → 본체 기동 차단
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        inherit onFailure;
        path = s3tools;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PrivateTmp = true;
          EnvironmentFile = cred;
        } // lib.optionalAttrs (user != null) {
          User = user;
          Group = user;
          StateDirectory = name; # /var/lib/<name> 를 <user> 소유로 보장 생성
        };
        script = ''
          set -euo pipefail
          if [ -e "${sentinel}" ]; then
            echo "${name} state present — skip restore"; exit 0
          fi
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          # fail-closed 존재확인: 404 만 신규배포로 통과, 그 외 에러는 실패.
          if aws s3api head-object --bucket ${bucket} --key ${s3key} >/dev/null 2>"$tmp/err"; then
            :
          elif grep -qE '\(404\)|Not Found' "$tmp/err"; then
            echo "no S3 backup (404) — fresh start (nothing to restore)"; exit 0
          else
            echo "S3 check failed (not 404) — refusing to start with empty state:"; cat "$tmp/err"; exit 1
          fi
          echo "empty state + S3 backup exists → restoring…"
          mkdir -p ${stateDir}
          aws s3 cp s3://${bucket}/${s3key} "$tmp/state.tar.gz"
          gzip -t "$tmp/state.tar.gz" # 완전·정상 gzip 인지 검증(부분 다운로드/손상 차단)
          tar ${extractFlags} -f "$tmp/state.tar.gz" -C ${stateDir}
          echo "${name} state restored from S3"
        '';
      };

      # --- 백업: 매일 무중단 스냅샷 → S3 ---
      systemd.services."${name}-s3-backup" = {
        description = "Backup ${name} state to S3";
        inherit onFailure;
        path = s3tools ++ backupPath;
        serviceConfig = {
          Type = "oneshot";
          PrivateTmp = true;
          EnvironmentFile = cred;
        };
        script = ''
          set -euo pipefail
          if [ ! -e "${sentinel}" ]; then
            echo "no local ${name} state (${sentinel} absent) — refuse to back up (avoid clobbering S3)"; exit 1
          fi
          tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
          ${backupBuild}
          gzip -t "$tmp/backup.tar.gz" # 업로드 전 자기검증
          aws s3 cp "$tmp/backup.tar.gz" s3://${bucket}/${s3key}
          echo "${name} backed up to s3://${bucket}/${s3key}"
        '';
      };

      systemd.timers."${name}-s3-backup" = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true; # 껐다 켜도 놓친 백업 따라잡기
          RandomizedDelaySec = "1h"; # 두 백업이 자정에 동시 실행되지 않게 분산
        };
      };
    };
in
lib.mkMerge [
  # headscale: db.sqlite(노드/IP 원장) + noise_private.key(컨트롤 정체성). uniform 소유권.
  (mkS3BackupPair {
    name = "headscale";
    mainUnit = "headscale.service";
    stateDir = "/var/lib/headscale";
    sentinel = "/var/lib/headscale/db.sqlite";
    s3key = "headscale/headscale-backup.tar.gz";
    extractFlags = "-xz";
    user = "headscale";
    backupPath = with pkgs; [ sqlite ];
    backupBuild = ''
      sqlite3 /var/lib/headscale/db.sqlite ".backup '$tmp/db.sqlite'"
      cp /var/lib/headscale/noise_private.key "$tmp/noise_private.key"
      tar -czf "$tmp/backup.tar.gz" -C "$tmp" db.sqlite noise_private.key
    '';
  })

  # gitea: repos + sqlite DB + conf(app.ini 의 SECRET_KEY 는 DB 와 짝 → 트리 전체 보관). 혼합 소유권.
  (mkS3BackupPair {
    name = "gitea";
    mainUnit = "podman-gitea.service";
    stateDir = "/var/lib/gitea";
    sentinel = "/var/lib/gitea/gitea/gitea.db";
    s3key = "gitea/gitea-backup.tar.gz";
    extractFlags = "-xzp --numeric-owner"; # 혼합 소유권(0/1000) 보존
    user = null; # root
    backupPath = with pkgs; [ sqlite ];
    backupBuild = ''
      cp -a /var/lib/gitea "$tmp/tree"
      sqlite3 /var/lib/gitea/gitea/gitea.db ".backup '$tmp/tree/gitea/gitea.db'"
      rm -f "$tmp/tree/gitea/gitea.db-wal" "$tmp/tree/gitea/gitea.db-shm"
      tar -czpf "$tmp/backup.tar.gz" --numeric-owner -C "$tmp/tree" .
    '';
  })
]
