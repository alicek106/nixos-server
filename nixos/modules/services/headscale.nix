{ config, ... }:
{
  # Headscale: 자체 호스팅 Tailscale 컨트롤 플레인.
  #   - 클라이언트는 https://headscale.alicek106.com (443) 로 접속해 네트워크맵 수신
  #   - nginx 가 443 에서 TLS 종료 → headscale(127.0.0.1:8080) 로 프록시(WebSocket 필수)
  #   - TLS 인증서는 Let's Encrypt DNS-01(Route53) 로 자동 발급/갱신 (포트 80 불필요)
  #
  # 선행조건(수동): 통합 자격증명 시크릿(nixos-credential.age), A레코드, 공유기 443 포워딩. (README 참고)

  # 통합 AWS 자격증명(nixos-credential)은 ../../secrets.nix 에서 중앙 선언.

  # --- TLS: Let's Encrypt DNS-01 via Route53 ---
  security.acme = {
    acceptTerms = true;
    defaults.email = "alice_k106@naver.com";
    certs."headscale.alicek106.com" = {
      dnsProvider = "route53";
      # lego 가 이 파일의 AWS_* 를 읽어 _acme-challenge TXT 를 Route53 에 생성 → 검증 → 발급
      environmentFile = config.age.secrets.nixos-credential.path;
      group = "nginx"; # nginx 가 인증서를 읽을 수 있게
    };
  };

  # --- nginx: 443 TLS 종료 후 headscale 로 리버스 프록시 ---
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."headscale.alicek106.com" = {
      useACMEHost = "headscale.alicek106.com";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8085";
        proxyWebsockets = true; # headscale long-poll (Upgrade/Connection 헤더)
        extraConfig = ''
          proxy_buffering off;
        '';
      };
    };
  };

  # --- Headscale 컨트롤 서버 (nginx 뒤, 평문 localhost) ---
  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8085; # 8080 은 aliced 컨테이너가 사용 중 → 8085
    settings = {
      server_url = "https://headscale.alicek106.com";
      dns = {
        magic_dns = true;
        base_domain = "alicek106.net"; # tailnet 내부 도메인(공개 도메인과 달라야 함)
        # magic_dns 가 로컬 DNS 를 덮으므로 일반 도메인 해석용 업스트림 필요
        nameservers.global = [ "1.1.1.1" "8.8.8.8" ];
      };
      # 초기엔 Tailscale 공개 DERP 릴레이 사용(간단). 자체 DERP 는 추후 승격.
      derp = {
        urls = [ "https://controlplane.tailscale.com/derpmap/default" ];
        auto_update_enabled = true;
        update_frequency = "24h";
      };
      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };
    };
  };

  # 컨트롤(443)/HTTP리다이렉트(80) + STUN(3478)/WG 직접(41641)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 3478 41641 ];
}
