# 모든 agenix 시크릿의 중앙 선언부.
#   - 암호화 규칙·수신자(공개키)는 secrets/secrets.nix 가 담당(agenix CLI 용).
#   - 여기서는 각 시크릿의 소스 .age 파일을 한 곳에서 선언한다. 복호화 결과는
#     config.age.secrets.<name>.path (기본 /run/agenix/<name>) 로 각 모듈이 참조.
# 이렇게 중앙화하면 특정 서비스 모듈을 끄거나 옮겨도 시크릿 선언이 사라지지 않는다.
{ ... }:
{
  age.secrets = {
    # 통합 AWS 자격증명 (env-file: AWS_ACCESS_KEY_ID/SECRET/REGION).
    # ACME DNS-01 + DDNS + S3 백업/복원 + aliced 컨테이너가 공용.
    nixos-credential.file = ./secrets/nixos-credential.age;

    # aliced 앱 전용 (env-file: PASSWORD, SECRET_KEY).
    aliced-env.file = ./secrets/aliced-env.age;

    # Slack Incoming Webhook (env-file: SLACK_WEBHOOK_URL=...).
    # Claude 알림 훅(alicek106 유저로 실행) + systemd 실패 알림(root)이 공유하므로
    # 유저가 읽을 수 있게 owner 를 지정한다(root 는 어차피 읽을 수 있음).
    slack-webhook = {
      file = ./secrets/slack-webhook.age;
      owner = "alicek106";
    };
  };
}
