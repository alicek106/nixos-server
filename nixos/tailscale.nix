{ ... }:
{
  # 이 서버를 mesh 노드로 만드는 클라이언트(tailscaled).
  # headscale(컨트롤)와 별개 계층 — 이게 있어야 서버가 tailnet IP(100.x)를 받고
  # 맥북 등에서 이 서버의 서비스(gitea/aliced)에 mesh 로 접근 가능.
  #
  # 등록은 런타임(수동, 1회):
  #   sudo tailscale up --login-server https://headscale.alicek106.com --authkey <preauthkey>
  services.tailscale.enable = true;
}
