# コロ助 ネットワーク構成（メンテ用）

RDK X5 への接続方法と、eth0 固定IPの設定・トラブル対処をまとめる（保守用）。

## 到達方法（どちらでもSSH可）
| I/F | アドレス | 用途 | 備考 |
|---|---|---|---|
| **eth0** | **192.168.0.200/24（固定）** ＋ DHCP動的 | **LAN経由の保守アクセス** | 電源ONで自動付与（再起動で実証済み） |
| usb0 | 192.168.128.10/24（固定） | **USBガジェット直結の生命線** | PCとUSBで直結。LANが不通でも必ず入れる |

- LAN側: `ssh sunrise@192.168.0.200`（パスワード sunrise）
- USB直結: `ssh sunrise@192.168.128.10`
- Web モニタ: `http://192.168.0.200:8080/` または `http://192.168.128.10:8080/`

## 元のネットワーク
- LAN ネットワークアドレス: **192.168.0.0/24** / ゲートウェイ **192.168.0.1**
- 元々 eth0 は DHCP のみ（例: 192.168.0.127 が動的付与されていた）。
- 保守で毎回IPが変わると不便なので、**DHCPを残したまま固定IP 192.168.0.200 を併設**した。

## netplan 設定（/etc/netplan/01-hobot-net.yaml, renderer=NetworkManager）
```yaml
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: true
      addresses: [192.168.0.200/24]   # ← 追加した固定IP(DHCPと併用)
    usb0:
      dhcp4: no
      addresses: [192.168.128.10/24]
      gateway4: 192.168.128.1
    usb1:
      dhcp4: no
      addresses: [192.168.128.10/24]
```
適用: `sudo netplan apply`（backup: `01-hobot-net.yaml.bak`）。

## ハマりどころ（重要）
`netplan apply` 後も固定IPが付かないことがある。原因は **NetworkManager に古い接続プロファイルが残存**し、
netplan生成の新プロファイル（固定IPを持つ）を **シャドウ** するため。

- 症状: `ip addr show eth0` に 192.168.0.200 が出ない。
- 確認: `nmcli -t -f NAME,UUID,FILENAME connection show | grep eth0`
  - `/etc/NetworkManager/system-connections/netplan-eth0.nmconnection` … 古い残骸（固定IP無し・アクティブ）
  - `/run/NetworkManager/system-connections/netplan-eth0.nmconnection` … netplan生成（`address1=192.168.0.200/24` あり）
- 対処:
  1. 固定IPを持つ方を有効化: `sudo nmcli connection up <その UUID>`
  2. 古い残骸を削除: `sudo nmcli connection delete <古い UUID>`（/etc の残骸が消える）
  3. 残る接続が `ACTIVE=yes / AUTOCONNECT=yes` なら再起動でも自動付与される。
- 検証コマンド: `ip -4 addr show eth0 | grep inet`（.200 と DHCP動的の両方が出ればOK）

## 変更時の安全策
- 作業は **usb0(192.168.128.10) 経由**で行えば、eth0 をいじってもロックアウトしない。
- 固定IPを変える場合は、まず `ping -c1 <候補>` で空きを確認（DHCPプールと衝突しない高位アドレス推奨）。
