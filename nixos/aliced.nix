{ config, ... }:
{
  # aliced: 커스텀 앱 컨테이너 (AWS all-in-one 에서 이전).
  # 이미지 레지스트리 경로만 원본 그대로(불가피) — 그 외 모든 명명은 aliced.

  # 시크릿 + 노출 원치 않는 값(S3 버킷명 등)은 암호화 env-file 에서 읽는다.
  # 활성화 시 /run/agenix/aliced-env 로 복호화됨.
  age.secrets.aliced-env.file = ./secrets/aliced-env.age;

  virtualisation.oci-containers = {
    backend = "podman";
    containers.aliced = {
      # 재현성 위해 태그(:latest) 대신 다이제스트로 핀
      image = "public.ecr.aws/o5v4y7w2/diary@sha256:f69e29b2dab4d47ea80512def64f3c49481b45cd34e24496ff0aba1cd7332bed";

      # 순수 시크릿(PASSWORD, SECRET_KEY, AWS_ACCESS_KEY_ID/SECRET, AWS 리전)은
      # 이 암호화 파일에 담긴다 → 저장소엔 안 보임.
      environmentFiles = [ config.age.secrets.aliced-env.path ];

      # 비-시크릿 env (S3 버킷명은 이미지 URL 처럼 불가피 예외로 인라인 허용)
      environment = {
        USERNAME = "alicek106";
        PORT = "80";
        DATA_FILESYSTEM_PATH = "/data";
        ATTACHMENT_FILESYSTEM_PATH = "/data/attachments";
        NOTES_PER_PAGE = "10";
        BACKUP_ENABLED = "true";
        S3_BUCKET_NAME = "alicek106-diary-backup";
        S3_BACKUP_PREFIX = "backup/";
      };

      volumes = [ "/var/lib/aliced/data:/data" ];

      # AWS 원본과 동일하게 root 로 실행 (앱이 /data 를 root 로 읽고 씀)
      user = "root";

      # WG 도입 전 임시 접근: localhost 전용(SSH 터널). LAN/WG 노출은 추후 결정.
      ports = [ "127.0.0.1:8080:80" ];
    };
  };

  # 데이터 디렉터리 (컨테이너가 root 로 사용)
  systemd.tmpfiles.rules = [
    "d /var/lib/aliced 0700 root root -"
    "d /var/lib/aliced/data 0700 root root -"
    "d /var/lib/aliced/data/attachments 0700 root root -"
  ];
}
