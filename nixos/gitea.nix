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
    };

    # 웹 UI. WG 도입 전 localhost 전용(SSH 터널). SSH(git) 노출은 추후.
    ports = [ "127.0.0.1:3000:3000" ];
  };
}
