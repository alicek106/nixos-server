let
  alice = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH31VMIW5aeAgjJXlGPD69Zs00NPrQ8pOwkLTJDJXC2x nixos-alicek106";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFES59QEY6v4T+su220nAuzmXB7L3KOjLWvBghpoPeKo root@nixos-alicek106"; # 서버 밀때마다 갈아줘야 함
  all = [ alice server ];
in
{
  "aliced-env.age".publicKeys = all;
  "nixos-credential.age".publicKeys = all;
  "slack-webhook.age".publicKeys = all;
}
