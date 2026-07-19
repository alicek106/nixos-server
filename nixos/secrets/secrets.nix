# agenix CLI 규칙 파일 — "어떤 .age 를 어떤 공개키로 암호화할지".
#   이 디렉터리에서 실행:  cd nixos/secrets && agenix -e <파일>.age
#   수신자(둘 중 아무 개인키로나 복호화 가능):
#     - alice : 맥북(나) — 시크릿 생성/편집용 (마스터, 오프라인 보관)
#     - server: 이 서버 호스트키 — 런타임에 자동 복호화
let
  alice = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFES59QEY6v4T+su220nAuzmXB7L3KOjLWvBghpoPeKo root@nixos-alicek106";
  all = [ alice server ];
in
{
  # aliced 컨테이너 시크릿 (env-file 형식: KEY=VALUE 줄들)
  #   PASSWORD, SECRET_KEY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
  "aliced-env.age".publicKeys = all;

  "nixos-credential.age".publicKeys = all;

  "slack-webhook.age".publicKeys = all;
}
