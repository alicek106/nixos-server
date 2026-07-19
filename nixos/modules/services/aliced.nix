{ config, ... }:
{
  # aliced: 커스텀 앱 컨테이너 (AWS all-in-one 에서 이전).
  # 이미지 레지스트리 경로만 원본 그대로(불가피) — 그 외 모든 명명은 aliced.

  # 시크릿(aliced-env, nixos-credential)은 ../../secrets.nix 에서 중앙 선언.

  virtualisation.oci-containers = {
    backend = "podman";
    containers.aliced = {
      # 재현성 위해 태그(:latest) 대신 다이제스트로 핀
      image = "public.ecr.aws/o5v4y7w2/diary@sha256:f69e29b2dab4d47ea80512def64f3c49481b45cd34e24496ff0aba1cd7332bed";

      # aliced-env: PASSWORD, SECRET_KEY. nixos-credential: AWS_ACCESS_KEY_ID/SECRET/REGION.
      environmentFiles = [
        config.age.secrets.aliced-env.path
        config.age.secrets.nixos-credential.path
      ];

      # 비-시크릿 env (S3 버킷명은 이미지 URL 처럼 불가피 예외로 인라인 허용)
      environment = {
        USERNAME = "alicek106";
        PORT = "80";
        DATA_FILESYSTEM_PATH = "/data";
        ATTACHMENT_FILESYSTEM_PATH = "/data/attachments";
        NOTES_PER_PAGE = "10";
        BACKUP_ENABLED = "true";
        S3_BUCKET_NAME = "alicek106-backup";
        S3_BACKUP_PREFIX = "aliced/"; # 끝의 / 필수 (앱이 prefix+filename 이어붙임)
      };

      volumes = [ "/var/lib/aliced/data:/data" ];

      # AWS 원본과 동일하게 root 로 실행 (앱이 /data 를 root 로 읽고 씀)
      user = "root";

      # 서버 tailnet IP 에만 바인딩 → 맥북 등 tailnet 피어에서만 접근(LAN/WAN 노출 0).
      # (tailnetIP 는 headscale 가 이 노드에 고정 할당한 IP — homelab.tailnetIP 단일 출처)
      ports = [ "${config.homelab.tailnetIP}:8080:80" ];
    };
  };

  # 데이터 디렉터리 (컨테이너가 root 로 사용)
  systemd.tmpfiles.rules = [
    "d /var/lib/aliced 0700 root root -"
    "d /var/lib/aliced/data 0700 root root -"
    "d /var/lib/aliced/data/attachments 0700 root root -"
  ];

  # tailnet 전용 리버스 프록시: http://diary.alicek106.net → aliced (포트 없이 접근).
  # tailnetIP:80 에만 바인딩 → tailnet 피어 전용(WAN 노출 0). 이름은 headscale extra_records 로 배포.
  services.nginx.virtualHosts."diary.alicek106.net" = {
    listen = [{ addr = config.homelab.tailnetIP; port = 80; }];
    locations."/".proxyPass = "http://${config.homelab.tailnetIP}:8080";
  };
}
