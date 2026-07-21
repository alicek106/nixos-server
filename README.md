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
   # (server) git config가 ssh로 강제되므로 git config를 강제로 비운다. 이후에는 git 접근이 가능한 키를 적절히 서버로 옮겨서 사용하자.
   GIT_CONFIG_GLOBAL=/dev/null git clone https://github.com/alicek106/nixos-server.git /home/alicek106/nixos-server
   sudo cat /etc/ssh/ssh_host_ed25519_key.pub

   # (mac) 자동 생성된 값을 맥북으로 가져와서 secrets.nix의 수신자로 변경한다.
   cd nixos/secrets # 하고 나서 secrets.nix에서 server의 pub 키로 변경한다.
   agenix -r -i ~/.ssh/<nixos-server key> # 혹은 ragenix를 사용한다.
   git commit -am "rekey secrets to new host key" && git push origin main

   # (server)
   cd /home/alicek106/nixos-server && git pull
   sudo nixos-rebuild switch --flake .#nixos-alicek106
   ```
4. 상태 데이터는 rebuild 후 S3에서 자동 복원된다.
   - gitea repo, aliced 노트, headscale 원장이 각 서비스 기동 전에 복원된다.
   - `tailscaled.state`(노드 정체성)도 복원된다. 덕분에 서버가 **같은 tailnet 노드로 자동 재접속**해 같은 IP를 유지한다.
     (이 백업이 없으면 재설치마다 새 노드로 등록되어 IP가 바뀐다. headscale은 `set-ip`가 없어 옛 IP를 되찾기 어렵다.)
5. TLS 인증서(Let's Encrypt)는 첫 부팅 후 acme 타이머(daily)가 알아서 발급한다.
   - 임시(self-signed) 인증서만 떠서 기다리기 싫으면, 아래로 즉시 발급을 트리거한다.
   ```bash
   sudo systemctl start acme-order-renew-headscale.alicek106.com.service
   ```

---

## 수동 설정이 필요한 항목

- claude code login
