# nixos-server

## 커스텀 설치 ISO

아래 명령어를 통해 iso 이미지를 빌드한다.

```bash
nix build .#nixosConfigurations.installer.config.system.build.isoImage
```

result/iso/*.iso를 USB에 dd로 넣으면 된다.

```bash
# USB Disk 번호 확인 후 진행한다.
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=result/iso/*.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```

## 서버 재설치

1. `git clone https://github.com/alicek106/nixos-server.git /tmp/nixos-server && cd /tmp/nixos-server`
2. 디스크 파티션 및 nixos 설치
   ```bash
   sudo nix --experimental-features "nix-command flakes" run .#disko -- \
     --mode disko ./nixos/disk-config.nix
   sudo nixos-install --flake .#nixos-alicek106
   ```
3. agenix의 수신자를 새 host의 ssh public key로 rekey
   ```bash
   # (server) 
   git clone https://github.com/alicek106/nixos-server.git /home/alicek106/nixos-server
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub

   # (mac) 자동 생성된 값을 맥북으로 가져와서 secrets.nix의 수신자로 변경한다.
   cd nixos/secrets
   agenix -r -i ~/.ssh/<nixos-server key>
   git commit -am "rekey secrets to new host key" && git push origin master

   # (server)
   cd /home/alicek106/nixos-server && git pull
   sudo nixos-rebuild switch --flake .#nixos-alicek106
   ```

---

## 수동 설정이 필요한 항목

- claude code login
- 수동으로 headscale node를 추가할 때:
  ```bash
  # user는 최초 nixos 설정할 때 해놨으므로 생성은 안해도 됨. 기록용으로만 남겨두었다. 
  sudo headscale users create alicek106
  sudo headscale preauthkeys create --user 1 --reusable --expiration 24h
  tailscale up --login-server https://headscale.alicek106.com --authkey <preauth key>
  ```
