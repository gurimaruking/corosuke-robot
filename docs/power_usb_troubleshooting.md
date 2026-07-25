# RDK X5 電源 / USB トラブルシュート（保守用）

本プロジェクトで**繰り返し発生**した「緑LEDが点かない／起動してもUSBデバイス不良・
ネットワーク不良・周辺機器(カメラ/目/マイク)が脱落」の原因と診断・対処。
結論から言うと **原因の大半は USB-C 電源ケーブル／アダプタの能力不足による電圧降下
(under-voltage / brown-out)**。粗悪・細い・長い・充電専用ケーブルや、PCのUSBポート給電で起きる。

## 公式ドキュメントの記載
- **電源要件**: USB-C給電。**最小 5V/2A、推奨 5V/3A以上(QC/PD)**、フル負荷は 5V/5A 推奨。
- **PCのUSBポートから給電しない**（電流不足で異常シャットダウン/繰り返し再起動）。
- **認定・高品質のUSB-Cケーブルを使う**（粗悪ケーブルは電源問題→異常シャットダウン）。
- 電源不足の症状(FAQ Q7/Q8): U-Boot/カーネル初期で再起動・明確なerror log無し・
  **緑LEDが異常(点滅しない/点きっぱなし)**・HDMI黒画面。
- 出典:
  - [RDK X5 ハードウェア紹介](https://developer.d-robotics.cc/rdk_doc/en/Quick_start/hardware_introduction/rdk_x5/)
  - [FAQ 8.1 Hardware, System, and Environment Configuration](https://developer.d-robotics.cc/rdk_doc/en/FAQ/hardware_and_system/)

## 症状 → 切り分け
| 症状 | 意味 | 疑う所 |
|---|---|---|
| **緑LEDが点かない** | 給電が来ていない/不足 | まず**電源ケーブル(USB-C入力)＋アダプタ** |
| 起動するがUSB/ネット不良 | 起動電圧はあるが**負荷時にブラウンアウト** | ケーブル/アダプタの電流能力不足 |
| 周辺機器が接続↔切断を反復 | USBバスの電圧/信号不安定 | ケーブル不良・電源不足・ハブ給電 |

## 診断コマンド（電圧降下の痕跡）
```sh
# USBのブラウンアウト/ケーブル不良の signature(今回まさに出た)
sudo dmesg | grep -iE "cannot enable|not accepting address|error -71|error -62|over-current|disconnect"
#   → "Cannot enable. Maybe the USB cable is bad?" が出たら電源/ケーブル不良ほぼ確定

# 周辺機器が見えているか
lsusb                          # カメラ(046d)/CH343(1a86)/ハブ(05e3)等が安定して出るか
ls /dev/video* /dev/ttyACM*    # 映像ノード・ESP32ポート
arecord -l | grep -i usb       # USBマイク

# 温度/BPU(電源とは別だが健康確認)
hrut_somstatus | grep -A3 temperature
```
- **緑＋橙LEDが点灯すれば給電正常**。緑が点かない/点滅しない＝電源・ケーブルを最優先で疑う。
- **確実なのはデバッグUART(シリアルコンソール)でフルブートログ**を取ること（公式が「診断の鍵」と明記）。
- **USB負荷を減らして起動**（周辺機器を全部外す）→ 直れば電力不足で確定。

## 対処（効果順）
1. **電源アダプタを認定 5V/5A（最低3A・QC/PD）に**。PCのUSBポートからは給電しない。
2. **電源入力のUSB-Cケーブルを、短く(≤1m)・太い・認定品に交換**（充電専用/細い長尺は不可）。
   ※今回、**USBケーブルを交換したら周辺機器が全部復活**した＝電圧降下が主因だった。
3. 周辺機器(カメラ/目/マイク)を**電源付きハブ**に載せる場合は、そのハブにも**独立給電**を確実に。
4. 筐体組込時に**ケーブルの折れ曲がり・挟み込み・半差し**が無いか（信号劣化=error -71 の原因）。

## 関連
- ネットワーク/到達方法: [network_setup.md](network_setup.md)
- 起動自動化・サービス: `deploy/*.service`
