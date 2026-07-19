{ ... }:
{
  # gitea: AWS all-in-one 에서 이전. 데이터(/var/lib/gitea)는 EBS tar 를 풀어둔 것.
  # 컨테이너 설정·저장소·sqlite DB 는 모두 데이터 볼륨(/data) 안에 있다.
  # backend(podman)는 aliced.nix 에서 설정됨.
  virtualisation.oci-containers.containers.gitea = {
    # 데이터 호환 위해 원본과 동일 버전, 재현성 위해 다이제스트 핀
    image = "docker.io/gitea/gitea:1.24.7@sha256:918955f16b1e91732af6c449bb2db3a34271748dbed1ccfbae48f8a2fb5480b8";

    volumes = [ "/var/lib/gitea:/data" ];

    # 이미지가 root 로 시작해 내부적으로 git(UID 1000)으로 전환 (데이터가 1000 소유)
    user = "root";
    environment = {
      USER_UID = "1000";
      USER_GID = "1000";
      # 리버스 프록시 정식 URL — gitea 가 생성하는 링크·리다이렉트가 새 호스트명을 쓰게(app.ini 오버라이드).
      GITEA__server__ROOT_URL = "http://gitea.alicek106.net/";
      GITEA__server__DOMAIN = "gitea.alicek106.net";
    };

    # 서버 tailnet IP 에만 바인딩 → tailnet 피어에서만 접근(LAN/WAN 노출 0).
    ports = [ "100.64.0.2:3000:3000" ];
  };

  # tailnet 전용 리버스 프록시: http://gitea.alicek106.net → gitea (포트 없이 접근).
  # 100.64.0.2:80 에만 바인딩 → tailnet 피어 전용. 이름은 headscale extra_records 로 배포.
  services.nginx.virtualHosts."gitea.alicek106.net" = {
    listen = [{ addr = "100.64.0.2"; port = 80; }];
    locations."/" = {
      proxyPass = "http://100.64.0.2:3000";
      proxyWebsockets = true; # gitea 일부 기능(SSE/live) 대비
    };
  };
}
