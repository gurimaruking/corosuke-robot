# コロ助 胴体ディスプレイ — ESP32-4827S043 設計・実装・引き継ぎ資料

> **性格:** korosuke の顔/目とは別に、**胴体に4.3インチのタッチ液晶**を追加し、
> **RDK X5のカメラ映像をUSB経由で表示**＋**タッチで制御**するサブシステムの設計書。
> 記載のうち「✅実機検証済」は本PC(Windows)＋実基板＋RDK実カメラで確認済み。
> 「調査」はWeb一次情報からの裏取り（出典URLは末尾）。**別PC/エージェントが続きを実装できるように**書いてある。
>
> 作成: 2026-07-28 / 対象基板: **Sunton ESP32-4827S043R**(抵抗膜タッチ版) / ブランチ: `stage3-launch`

---

## 0. TL;DR（3行）

- **基板 = Sunton ESP32-4827S043R**(CYD系, ESP32-S3 N16R8, 480×272 RGBパラレル, **抵抗膜XPT2046タッチ**)。USB-Cは**CH340C UART**配線 → Windowsで`COM16`、RDK Linuxで`/dev/ttyUSB*`。
- **経路 = RDKカメラ → LAN(or直接) → `display_send.py` → USBシリアル(2Mbaud) → ESP32が受信・JPEGデコード・描画**。プロトコルは `A5 5A | len(u32LE) | JPEG` ＋ フレーム毎ACK。
- **現状 = M0(表示)/M1(タッチ)/M2(USB映像) まで実機で動作確認済み ✅（~5–6fps）**。残り = fps最適化(JPEGDEC+並列)・M3タッチ制御・RDK直結デプロイ（**RDKにはS3が2枚あるのでポート選別注意**）。

---

## 1. ゴールと現状

**やりたいこと:** korosuke のカメラ（RDK X5にUSB接続されたUVCカメラ、YOLO/骨格描画済み）で受け取った映像を、胴体の ESP32-4827S043 に表示する。タッチもあるので、タッチで korosuke を制御する。最終的には **RDK X5からUSB経由**で映像・制御を完結させる（ネット非依存＝korosukeの思想と一致）。

| マイルストン | 内容 | 状態 |
|---|---|---|
| **M0** | RGBパネル点灯・テストパターン | ✅ 実機OK（色順・タイミング正常） |
| **M1** | 抵抗膜タッチ(XPT2046)読み取り | ✅ 実機OK（`pin_int=-1`ポーリングで解決） |
| **M1b** | タッチ四隅キャリブレーション＋NVS保存 | ✅ 実機OK（デモボタン命中確認） |
| **M2** | USBシリアルでJPEG受信→デコード→表示 | ✅ 実機OK（RDK実カメラのライブを目視確認, ~5–6fps） |
| **M2opt** | fps最適化 | 🟡 **JPEGDEC(SIMD)化 実機OK ✅**（デコード~2倍/帯域44→95KB/s、色は`RGB565_BIG_ENDIAN`）。デュアルコア並列は未 |
| **M3** | タッチボタン→USB経由でRDK制御(`/eye` `/arm` `/say`) | ⬜ 未（設計は §10） |
| **DEPLOY** | RDK X5直結（`display_send.py`をRDKで常駐） | ✅ **実機OK** — RDK単独・完全USB・ネット非依存で常時表示（手順 §8） |
| **回転** | Web設定から入力/表示映像の回転(0/90/180/270) | ✅ **実機OK** — dashboard **⚙設定→🖥胴体ディスプレイ向き**。`/dispcfg`経由でdisplay_send.pyが約1秒で反映。中核系(YOLO/目)無干渉 |

---

## 2. 基板の確定情報（✅一部実機検証 / 調査）

### 2.1 正体・コアスペック
- **メーカー/系統:** Sunton、"Cheap Yellow Display (CYD)" ファミリの4.3インチ機。型番デコード `4827`=480×272, `S043`=4.3"、末尾 **R=抵抗膜(XPT2046)** / C=静電(GT911) / 無=タッチ無し。**本機はR（抵抗膜）**。
- **SoC:** ESP32-S3-WROOM-1 **N16R8**（デュアルLX7 @240MHz, WiFi2.4GHz+BLE）。✅実機: `PSRAM 8386279B(≈8MB, Octal)`, `Flash 16MB`, MAC `f4:12:fa:e2:06:4c`, rev v0.1。
- **USB-C:** **CH340C UART ブリッジ専用**（`VID_1A86&PID_7523`）。✅実機: Windowsで `USB-SERIAL CH340 (COM16)`。**ネイティブUSB(ttyACM)は出ない**＝USB-Cはシリアルのみ（調査でも「USB-C→Serial0(CH340C)」と一次情報一致）。
- **⚠️ 紛らわしい別物:** Guition **JC4827W543**（同じ480×272/4.3"だが QSPI/NV3041A/4MB/IPS）。**別基板・別ドライバ**。混同しないこと。
- **入手・価格（調査 2026-07）:** AliExpress の Sunton ストアが主。本機(480×272)の出品で **$14.15** の実例あり。抵抗膜(R)版は概ね **$14–18（≈¥2.2–2.8k）**、静電(C)版は数ドル高、無タッチ版が最安。BOMには**Option**として登録済（[stage2_design.md §3.1](stage2_design.md)）。出典: esp3d.io の購入リンク先 AliExpress 1005004788147691 / Surenoo / Makerfabs。

### 2.2 ピン配置（✅本リポの firmware がこの値で動作）

**RGBパネル（16bitパラレル, ST7262系, init不要）** — 出典 Arduino_GFX #587 / LovyanGFX同梱 `LGFX_ESP32S3_RGB_ESP32-8048S043.h`（兄弟機同ピン）:

| 信号 | GPIO | | 信号 | GPIO |
|---|---|---|---|---|
| DE (henable) | 40 | | Green d5–d10 | 5,6,7,15,16,4 |
| VSYNC | 41 | | 5bit群A | 8,3,46,9,1 |
| HSYNC | 39 | | 5bit群B | 45,48,47,21,14 |
| PCLK | 42 | | Backlight(PWM) | 2 |

> 群A/群Bのどちらをr/bと呼ぶかはライブラリのカラーオーダ次第。**本リポ設定（A=Blue d0-4, B=Red d11-15）で色は正常** ✅（赤青逆なら入替）。タイミング: PCLK 9MHz, HSYNC fp8/pw4/bp43, VSYNC fp8/pw4/bp12, `pclk_active_neg=1`。

**抵抗膜タッチ XPT2046（SPI, ✅実機動作）** — 出典 rzeldent `esp32-4827S043R.json`:

| 信号 | GPIO | 備考 |
|---|---|---|
| SCLK | 12 | **microSDと共有** |
| MOSI | 11 | **microSDと共有** |
| MISO | 13 | **microSDと共有** |
| CS | 38 | タッチ専用（SDのCS=10と別） |
| IRQ/PENIRQ | 18 | **⚠️基板上で未結線気味 → `pin_int=-1`必須（§12参照）** |
| SPIホスト | SPI2_HOST | clock ≤2.5MHz（本リポ1MHz） |

**microSD:** CS=10, MOSI=11, SCK=12, MISO=13（タッチとバス共有、CSのみ別）。
**ネイティブUSB(未使用):** GPIO19=D-, GPIO20=D+（IOMUX固定）。R版ではタッチが19/20を使わないので**空いている**が、USB-Cは繋がっていないため**使うには背面ヘッダP3へUSB線を半田付け必要**（§9のPath B）。

---

### 2.3 コネクタ / ケーブル（調査 2026-07）
CYD系の**1.25mm 4ピン**コネクタは **Molex PicoBlade（MX1.25）**。**JST GHではない**（GHも1.25mmだが**嵌合しない**）。俗に「JST 1.25」と誤称される。

| コネクタ | ピッチ/系列 | ピン | 配列 | 適合ケーブル |
|---|---|---|---|---|
| **P1** UART/電源 | 1.25mm PicoBlade | 4 | GND / RX(IO44) / TX(IO43) / +5V | 1.25mm 4P |
| **P2** SPI(SD) | 1.25mm | 4 | IO13 / IO12 / IO11 / IO19 | 1.25mm 4P |
| **P3** USB/UART | 1.25mm | 4 | IO20 / IO19 / IO18 / IO17（19/20=ネイティブUSB D-/D+） | 1.25mm 4P |
| **P4** IO | 1.25mm | 4 | IO18 / IO17 / +3.3V / GND | 1.25mm 4P |
| **I2C**(S3機のみ) | **1.0mm JST SH** | 4 | SDA/SCL/3V3/GND | 1.0mm 4P(Qwiic形状・ピン順要確認) |
| **SPEAK** スピーカ | 1.25mm PicoBlade | 2 | アンプ出力(8Ω) | 1.25mm 2P |
| USB-C | — | — | CH340C(給電+シリアル) | USB-Cケーブル |

- **買うもの:** 「**1.25mm 4P / MX1.25 / PicoBlade**」。**「JST GH」は非嵌合で不可**、**「JST PH(2.0mm)」も不可**。スピーカは2P版。S3機のI2Cのみ1.0mm(JST SH)。基板に4Pケーブル1本同梱が多い。
- 電池コネクタ/充電回路は**無し**（給電=USB-C か P1の+5V）。バックライト/RGB LEDは内部GPIO（コネクタ無し, BL=IO2）。
- ⚠️ 安価ケーブルは**ストレート/リバース混在**（5V/GND逆の恐れ）→通電前に導通確認。SMD端子は脆いので**線でなくプラグを持つ**。
- ⚠️ S3機(4827/8048)の1.25mmがPicoBlade正規かGH互換クローンかは実測未確認（2432S028で確認、同一OEMとしてfamilyに敷衍）。
- 出典: witnessmenow CYD PINS.md / rzeldent board defs / esp3d.io / espboards.dev。

---

## 3. リポジトリ構成（今回追加したもの）

```
firmware/corosuke_display/           ← 新規PlatformIOプロジェクト
  platformio.ini                     ← ESP32-S3 N16R8 / LovyanGFX 1.1.16 / upload_port=COM16
  src/
    LGFX_ESP32_4827S043.h            ← LovyanGFXパネル+タッチ定義(この基板の“唯一の正”)
    main.cpp                         ← 現在 M2(USB JPEGビューア)。M0/M1は履歴で差し替え済
tools/
  display_send.py                    ← 送信側(PC/RDK共用)。test/cam/file/mjpeg。
                                       --port auto(VID/PID選別) / drop-to-latest(低遅延) / USB自動再接続 / --list
  rdk_display_start.sh               ← RDK常駐起動ヘルパ(nohup)。start / stop
  rdk_display_flash.sh               ← CYDファーム遠隔フラッシュ(0x10000のみ)。焼く前にポート=1a86:7523を検証(目基板保護)
docs/
  esp32_4827s043_display.md          ← 本書
```

既存の目ファーム（`firmware/corosuke_eyes/`, LovyanGFX 1.1.16, ESP32-S3 N16R8）と**同じ流儀**で作ってある。目ファームは無改造・別基板のまま。

---

## 4. ビルド & 書き込み（Windows / PlatformIO）

```powershell
# PlatformIO Core は既にインストール済 (C:\Users\User\.platformio\penv\Scripts\pio.exe)
$pio = "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe"

# ビルド＆書き込み（COM16固定。ポートが変わったら §下の自動検出で調べて platformio.ini を修正）
& $pio run -d "firmware\corosuke_display" -t upload

# CH340ポート自動検出（挿し直しでCOM番号が変わった時）
Get-PnpDevice -Class Ports -PresentOnly | Where-Object InstanceId -match 'VID_1A86&PID_7523'
```

- `platformio.ini`: `board=esp32-s3-devkitc-1`, `memory_type=qio_opi`(Octal PSRAM), `flash_size=16MB`, `-DBOARD_HAS_PSRAM -DLGFX_USE_V1`, `lib_deps=lovyan03/LovyanGFX@1.1.16`。
- **USB CDCは使わない**（`ARDUINO_USB_CDC_ON_BOOT`未設定）→ `Serial`はUART0=CH340に出る。これで映像・制御・ログが**CH340の1本**で完結。
- 書き込み後のシリアル確認（起動バナー捕捉のためEN=RTSパルス）:
  ```powershell
  $p=New-Object System.IO.Ports.SerialPort 'COM16',115200,'None',8,'One'; $p.Open()
  $p.RtsEnable=$true; Start-Sleep -ms 120; $p.RtsEnable=$false
  1..40 | %{ try{$p.ReadLine()}catch{} }; $p.Close()
  ```
  ※M2実行時のアプリ`Serial`は**2000000 baud**（`BAUD`定数）。監視も2Mに合わせること。

---

## 5. USB映像プロトコル（✅実機動作）

送信(`display_send.py`) → ESP32 の1フレーム:
```
0xA5 0x5A            同期マジック(2B)
len  (uint32 LE)     続くJPEGのバイト数
<len bytes>          JPEG本体(480x272想定、そのまま全画面drawJpg)
```
- ESP32は**1枚デコード完了ごとに `0x06`(ACK) を返す**。送信側はACKを待ってから次を送る＝**フロー制御**（CH340はHWフロー制御線が無いので、これが無いとRXバッファ溢れで破損する）。
- ESP32のテキストログ(`fps=...`)は同じTXに混ざるが、ACKは制御コード`0x06`なのでテキスト(ASCII)と区別可能。
- **ボーレート=2,000,000**（CH340C実力上限。✅2Mでバナー・映像とも安定）。

**送信スクリプト使用例:**
```bash
# 合成アニメ（カメラ不要・パイプライン検証）
python tools/display_send.py --port COM16 --source test --duration 15
# RDKの実カメラMJPEGをLAN越しに引いてUSBへ中継（Windows検証で使用）✅
python tools/display_send.py --port COM16 --source "mjpeg:http://192.168.0.200:8080/stream"
# webカメラ / 動画ファイル
python tools/display_send.py --port COM16 --source cam:0
python tools/display_send.py --port COM16 --source movie.mp4
```
オプション: `--baud`(既定2000000) `--quality`(既定60) `--fps`(送信上限) `--width/--height`(既定480/272) `--duration`(0=無限)。

---

## 6. コロ助サーバとの統合面（重要 — サーバ改造ほぼ不要）

RDK X5のダッシュボード `scripts/korosuke_monitor.py`（HTTP :8080）が**既に必要なものを全部REST/HTTPで公開**している:

| 用途 | エンドポイント | 実体 |
|---|---|---|
| 映像を引く | `GET /stream` | MJPEG(`multipart/x-mixed-replace; boundary=FRAME`)。YOLO枠+骨格入り**640×480 JPEG q80 ≈20fps** ([korosuke_monitor.py:1641](../scripts/korosuke_monitor.py#L1641)) |
| 表情 | `GET /eye?emo=happy&blink` | 目ESP32へ転送 ([:1589](../scripts/korosuke_monitor.py#L1589)) |
| 腕 | `GET /arm?do=wave` / `l=<deg>&r=<deg>&off=both` | 腕サーボ ([:1597](../scripts/korosuke_monitor.py#L1597)) |
| 発話 | `GET /say?text=...` / `GET /llm?text=...` | Open JTalk / ローカルLLM ([:1572](../scripts/korosuke_monitor.py#L1572)) |
| 状態 | `GET /events` (SSE) | cam/yolo/present/speech 等JSON |

→ **M3タッチ制御は、これらを叩くだけ**（§10）。USB直結時はESP32→RDKへ制御要求を送り、RDK側の小デーモンがこのRESTを叩く（or 直接pyserialで目ESP32へ）。

**任意のサーバ改修（fpsを稼ぐなら推奨）:** `camera_loop`の`imencode`直前で`cv2.resize(frame,(480,272))`する縮小版ストリーム（例 `/stream?w=480`）を足すと、S3のデコード負荷が~3倍軽くなりfpsが上がる（[korosuke_monitor.py:494](../scripts/korosuke_monitor.py#L494)付近）。現状は`display_send.py`側でresizeしているので必須ではない。

---

## 7. コロ助側の接続前提（実装確認済みの事実）

- カメラ = RDK X5にUSB接続のUVCカメラ（640×480 MJPG）。映像処理・配信はRDK上のPython。
- RDK ⇄ 目ESP32 は既に **USB-CDCシリアル 115200 のテキスト行**で通信（`serial_bridge_node.py`, `korosuke_monitor.py`のEyesクラス）。**本ディスプレイはその隣に増設**する2台目のUSB子機。
- RDK実機IP（本作業時点）: **`192.168.0.200`**（ダッシュボード `http://192.168.0.200:8080/` 到達確認済 ✅）。

---

## 8. RDK X5 直結デプロイ手順（最終形）— ⚠️**S3が2枚ある罠** ✅実施済

> **✅ 2026-07-29 実機で成立:** RDK(`192.168.0.200`)上で `tools/rdk_display_start.sh` を実行 → `display_send.py --port auto` が
> **`/dev/ttyUSB0`(1a86:7523=ディスプレイ)** を自動選別（目基板`/dev/ttyACM0`=1a86:55d3 は非対象）→ ローカル`:8080/stream`(処理済み映像)を
> USBでCYDへ**常駐配信**(nohup, SSH切断後も継続)。~3.7–4.6fps(デコード律速, 画面の細かさで変動)。**ネット非依存・RDK単独。**
>
> 起動: `bash ~/rdk_display_start.sh` / 停止: `bash ~/rdk_display_start.sh stop` / ログ: `~/display_send.log`。
> 恒久化(ブート時自動起動)は systemd unit 化（`deploy/`に`korosuke-monitor.service`の前例）。

**最重要注意（ユーザ指摘）:** RDK X5には **ESP32-S3が2枚**繋がる — ①既存の**目**コプロセッサ、②本**ディスプレイ**。RDK上では両方が `ttyUSB*`/`ttyACM*` に出るため、**`display_send.py` のポートを間違えると目のファームを壊す/映像を目基板へ流してしまう**。必ず見分けること:

| 基板 | ブリッジ | Linuxでの見え方 | VID:PID |
|---|---|---|---|
| **ディスプレイ(本機)** | CH340C | `/dev/ttyUSB*`（ch341ドライバ） | **1a86:7523** |
| **目(eyes)** | CH343 or ネイティブUSB | `/dev/ttyACM*`（cdc_acm） or `/dev/ttyUSB*`(CH343=**1a86:55d3**) | 303a:1001 or 1a86:55d3 |

**ポート特定（RDK上, PID厳密指定）:**
```bash
# ディスプレイ(CH340=1a86:7523)のttyを厳密に特定
for d in /sys/bus/usb-serial/devices/*; do
  dev=/dev/$(basename $d)
  info=$(udevadm info -q property -n $dev)
  echo "$info" | grep -q 'ID_VENDOR_ID=1a86' && echo "$info" | grep -q 'ID_MODEL_ID=7523' && echo "DISPLAY = $dev"
done
```
`display_send.py`にVID/PID自動選別を実装するのが安全（**TODO:** `--auto-vidpid 1a86:7523`）。現状は`--port`明示なので、上記で特定した`/dev/ttyUSB*`を渡すこと。**目基板のポートを絶対に渡さない。**

**RDKでの起動（自分のカメラを自分に流す＝USB完結）:**
```bash
# 依存: pyserial + opencv（korosuke_monitorが既にcv2使用 → 入っている）
python3 tools/display_send.py --port /dev/ttyUSB_DISPLAY --source cam:0
# もしくは既存の処理済みMJPEGをローカルで引く（YOLO/骨格入りを出したい場合）
python3 tools/display_send.py --port /dev/ttyUSB_DISPLAY --source "mjpeg:http://127.0.0.1:8080/stream"
```
- ファーム書き込みをRDKから行う場合も**同じポート罠**に注意（`pio`不在なら、Windowsでビルドした`firmware.bin`を`scp`して`esptool.py --port /dev/ttyUSB_DISPLAY write_flash ...`）。**目基板ポートへ焼かない。**
- 常駐化はsystemd unit（`deploy/`に`korosuke-monitor.service`の前例あり）を用意すると良い。

---

## 9. 既知の課題 & 最適化ロードマップ

### 9.1 fps の内訳と改善
- **✅ JPEGDEC(SIMD)化 実施済** — `lcd.drawJpg`(内蔵tjpgd) → **bitbank2/JPEGDEC** に置換。MCUブロックcallbackで`lcd.pushImage`。**帯域 44→95 KB/s(約2倍)**。実測 ~6fps（ただし配信画面が細かく16KB/フレームのため。~10KBの絵なら~9-10fps）。
  - **重要:** JPEGDECの出力は **`RGB565_BIG_ENDIAN`** にすること（LovyanGFX pushImageの期待に一致）。LITTLEだと色化け(バイト逆)で「汚い」映像になる（§12）。実装は [main.cpp](../firmware/corosuke_display/src/main.cpp) の `jpegDraw` callback + `jpeg.setPixelType`。
- **残りの改善策:**
  1. **デュアルコア並列化**（未） — core0=シリアルRX（PSRAMリングへ）, core1=デコード+描画。ACK維持＋ダブルバッファで転送とデコードを重ねる → +50%程度。
  2. **JPEG品質を下げる**（`display_send.py --quality 45`）→ フレーム小→転送&デコード速→fps↑（画質とトレード）。ファーム不要。
  3. **RDK側で480×272縮小配信**（§6）→ デコード対象画素が減りさらに軽い。
- 遠隔での焼き直し: Windowsで`pio run`→`firmware.bin`をscp→`bash rdk_display_flash.sh`（アプリ0x10000のみ・ポート検証付き）→`bash rdk_display_start.sh`。
- **native USB(Path B)** に載せ替えると帯域は12Mbps（実効~0.5–1MB/s）に上がるが、**背面ヘッダP3へUSB線半田付けが必要**（USB-CはCH340専用）。それでも**デコード律速で~20–30fpsが上限**。CH340のままJPEGDEC化で~15fps出れば胴体表示には十分、というのが妥当な判断。

### 9.2 描画（RGBパネル）メモ
- LovyanGFX `Panel_RGB` はPSRAMフレームバッファを連続スキャン。`fillRect`/`drawString`/`drawJpg`いずれも`_frame_buffer`へ書いて`cacheWriteBack`する実装で、**本機では`drawJpg`も正常描画** ✅（当初「映らない」はストリーム終了後に見ていた誤認だった）。
- 参考: LovyanGFX #374 に800×480機で`writePixels`の再描画不完全（PSRAM帯域症状）報告あり。480×272では未発現。もし将来tearing/欠けが出たら、esp_lcdのbounce-bufferや部分更新を検討。

### 9.3 タッチ
- **キャリブレーションは個体ごと必須**（抵抗膜）。本リポは`calibrateTouch()`結果を**NVSに保存**（`koro-disp/touchcal`）→ 再フラッシュしても保持（NVSはアプリ領域と別パーティション）。Serialに`c`送出で再キャリブ。
- SDカードを使う場合は`bus_shared=true`にする（タッチとSDがSPI2共有）。**本FWはSD未使用なので`bus_shared=false`でOK** ✅。

---

## 10. M3: タッチ制御 設計（別PC実装用）

**狙い:** 画面下部にボタンを重ね、タッチ→USB経由でRDKへ制御要求→RDKが既存REST(`/eye` `/arm` `/say`)を叩く。M1bで**ボタン命中判定は実証済み**（`main.cpp`のBtn配列＋矩形ヒットテスト）。

**プロトコル（ESP32→RDK, 逆方向）:** 映像フレームと衝突しないよう、行テキストで送る:
```
CTL eye happy        → RDK: GET /eye?emo=happy&blink
CTL arm wave         → RDK: GET /arm?do=wave
CTL say <text>       → RDK: GET /say?text=<text>
```
- ESP32側: タッチでボタン確定 → `Serial.printf("CTL %s\n", cmd)`。ACK(0x06)とは別チャネル（テキスト行）。
- RDK側: `display_send.py`（or 相棒デーモン）が同じシリアルを**読み**、`CTL ...`行を見たら`requests.get("http://127.0.0.1:8080/eye?...")`を叩く。※`display_send.py`は既にESP32のテキスト行を読んでログ表示しているので、そこに`CTL`ハンドラを足すだけ。
- **UIレイアウト案:** 上=映像(480×~220)、下=ボタン帯(3–4個: 😊表情 / 👋手を振る / 🗣定型セリフ / 設定)。映像とUIの重畳は、映像を上部矩形にクリップ描画し、下帯は固定UIにする。

---

## 11. カメラ＋ディスプレイ一体型MCU 調査（ユーザ依頼）

**結論:** 一体型は**自分のカメラ**を映すのが本分。korosukeの狙いは**RDKの処理済み映像を映す**ことなので、一体型のカメラは基本デッドウェイト。**受信して映すだけなら display-only（＝今の Sunton 4827S043）で十分**。唯一「映像受信」が快適なのは **ESP32-P4**（ハードJPEG＋USB-HS）。

| ボード | カメラ | ディスプレイ | HW JPEG | USB | 概算 | 位置づけ |
|---|---|---|---|---|---|---|
| **ESP32-P4-Function-EV** ⭐ | 2MP MIPI | 7" 1024×600 タッチ | **有(640×480@307fps)** | **HS 480Mbps** | ~$55 | 映像受信が唯一余裕。WiFiは相棒C6経由。7"は顔には大きい |
| ESP32-P4-Nano(Waveshare) | MIPI端子 | DSI端子(別売) | 有 | HS | ~$40–50 | 小型パネルと組むならP4の最良形 |
| **M5Stack CoreS3** | 0.3MP GC0308 | 2.0" 320×240 タッチ | 無 | FS | ~$60 | M5で唯一カメラ+画面両載せ。筐体◎。native-USBは目S3と同じDLリセット罠 |
| **ESP32-S3-EYE** | 2MP OV2640 | 1.3" 240×240 | 無 | FS | ~$45–50 | UVC送出＋MJPEG受信表示の公式サンプルあり＝流用しやすい |
| LilyGo T-Camera-Plus-S3 | 2MP/5MP(暗視) | 1.3" 240×240 タッチ | 無 | FS | ~$35–45 | 一体型として手頃 |
| Sipeed MaixCAM-Pro ⭐ | 5MP | 2.4" 640×480 タッチ | (Linux/NPU) | — | ~$55–88 | **自前でAIする“考える目”**。ESP32ではなくLinux AIカメラ |
| (参考)Seeed XIAO S3 Sense | 2MP | **無** | 無 | FS | ~$14–20 | カメラのみ・画面無し |
| (参考)M5 CoreS3 **SE** | **無(削除)** | 2.0"タッチ | 無 | FS | ~$39 | ※SEはカメラ非搭載。混同注意 |

- **RDK映像をUSBで受けるなら:** ①ESP32-P4系（余裕）②ESP32-S3-EYE（サンプル流用）③**今の4827S043で十分**。
- **自己完結の“目”にするなら:** ①MaixCAM-Pro ②M5 CoreS3 ③S3-EYE。
- **要点:** 「映像をデコードして受ける」なら **ESP32-P4だけがハードJPEG＋USB-HSで別格**。S3系は全てソフトJPEG＋USB-FS(12Mbps)。

---

## 12. トラブルシュート集（今回ハマった実例）

| 症状 | 原因 | 対策 |
|---|---|---|
| ビルドエラー `'Bus_RGB' does not name a type` | RGBプラットフォームヘッダ未include＋メンバ名`_panel/_bus`が基底と衝突 | `#include <lgfx/v1/platforms/esp32s3/{Panel,Bus}_RGB.hpp>`＋メンバを`_*_instance`に。同梱`LGFX_ESP32S3_RGB_ESP32-8048S043.h`を土台にする |
| **タッチ全く反応しない** | `pin_int=18`だが基板でPENIRQ未結線気味 → LovyanGFXがINT=HIGHを「未タッチ」と誤判定し全read破棄 | **`cfg.pin_int=-1`（ポーリング）** ← 最重要。SPI圧力読みで判定 |
| USB映像が来ない/ACK来ない(無反応) | `Serial.setRxBufferSize()`を`begin()`**後**に呼び失敗→RX 256Bのまま→8KBフレームで即溢れ→同期マジック落ち | `setRxBufferSize(16384)`を**`begin()`より前**に。読み出しは`readBytes`でまとめ読み |
| 「映像が映らない」 | 実は映っていた。**ストリーム終了後に見ていた**（旧FWは無信号で全消し） | 改良FWは**最後のフレームを残し**"NO SIGNAL"バッジのみ。連続配信して**動きで**確認 |
| RGBで赤青が逆 | ライブラリのカラーオーダ | `pin_d0..4`(B)と`pin_d11..15`(R)を入替（本機はデフォルトで正常） |
| RDKでポート取り違え | S3が2枚（目＋表示） | §8のVID/PID(`1a86:7523`=表示)で厳密選別。**目基板に焼かない/流さない**。`rdk_display_flash.sh`は焼く前にポートを検証 |
| JPEGDEC化後、色化け・映像が「汚い」 | JPEGDEC出力のバイトオーダーがLovyanGFX pushImageと逆 | `jpeg.setPixelType(RGB565_BIG_ENDIAN)`（LITTLEだと化ける）。または LITTLE+`lcd.setSwapBytes(true)` |
| 映像の遅延が時間とともに増える | ソース(~20fps)>消費(~6fps)でcv2/ソケットにフレーム滞留 | `display_send.py`は**drop-to-latest**(別スレッドで最新のみ保持)で対処済 |
| 稼働中にUSB断で停止 | `ser.write`が例外で落ちる | `display_send.py`は切断検知→ポート再解決(auto)→再オープンで**自動再接続**する |

---

## 13. 出典（一次情報）

**基板/表示/タッチ:** rzeldent `platformio-espressif32-sunton`(`esp32-4827S043R.json`) · Arduino_GFX Discussion #587 · LovyanGFX同梱`LGFX_ESP32S3_RGB_ESP32-8048S043.h` / issues #304 #374 #384 · esp3d.io Sunton-43-4827 · openHASP sunton/esp32-4827s043 · espboards.dev cyd-esp32-4827s043。
**USB伝送:** CH340データシート(max 2Mbps) · atomic14(ESP32-S3 USB/JPEG) · esp-cpp/camera-display · bitbank2/JPEGDEC。
**一体型MCU:** M5Stack CoreS3 docs · ESP32-S3-EYE(esp-who) · ESP32-P4-Function-EV(ESP-IDF JPEG API: 640×480@307fps) · Sipeed MaixCAM-Pro · LilyGo T-Camera-Plus-S3。
(詳細URLは調査ジャーナル参照)

---

*この資料は実機検証＋Web一次調査から起こした。矛盾を見つけたら firmware/実機 を正とし本書を直すこと。*

---

## 派生: ESP32-1732S019 (1.9" 170x320, タッチ無し) にも対応

同じファーム/プロトコルで **Sunton ESP32-1732S019** でも動く(実機確認済み、~13fps)。
SPIパネルなので **GPIOが約20本ヘッダに出ている**のが利点(目のGC9A01やサーボの増設向き)。
タッチ非搭載のため言語ボタン/くすぐったい反応はこの基板では無し。

```bash
# ビルド&書き込み (USBは同じCH340。このWindows機ではCOM7)
pio run -e esp32-1732S019 -t upload --upload-port COM7

# 送信 (PC/RDKどちらからでも。ボタン無し・小画面向け帯サイズに自動調整)
python tools/display_send.py --port COM7 --width 320 --height 170 --no-button \
  --source mjpeg:http://192.168.128.10:8080/stream
```

- パネル定義: `firmware/corosuke_display/src/LGFX_ESP32_1732S019.h`
  (ST7789 / SCLK=12 MOSI=13 DC=11 CS=10 RST=1 BL=14 / offset_x=35 / invert / setRotation(1)で横長)
- `main.cpp` は `-DBOARD_1732S019` でボード切替(4827S043と共通ソース)

---

## コンボ構成: 1732S019に目(GC9A01×2)+腕サーボを統合する

devkitの目基板(corosuke_eyes)を**ESP32-1732S019一枚に置き換えられる**構成。
ファーム = `esp32-1732S019-combo` env(お腹映像+目+サーボ+撫でを1チップで実行)。
コマンド体系はdevkit目基板と同一(emo/gaze/blink/wink/idle/arm)なので、**どちらを挿しても
RDK側は無設定で動く**(モニタが全コマンドを/eyecmdにミラーし、display_send.pyが
「A5 5B|len|テキスト」フレームでUSB転送。devkit側はttyACM直結のまま)。

### ヘッダピン配置(純正回路図V1.0で確認済み)

背面に12ピンパッド列×2(P1=左/P2=右、ピンヘッダは要はんだ付け)。

| P1(上から) | GPIO | 割当 | | P2(上から) | GPIO | 割当 |
|---|---|---|---|---|---|---|
| P1-1 | IO20 | (予備・native USB D+) | | P2-1 | 5V | ⚠1N5819経由≒4.6V/1A |
| P1-2 | IO19 | (予備・native USB D-) | | P2-2 | GND | サーボGND共通化に |
| P1-3 | IO18 | 空き | | P2-3 | IO21 | 空き |
| P1-4 | IO17 | 空き(目BL調光用に予約) | | P2-4 | IO47 | 空き |
| P1-5 | IO16 | **目CS右** | | P2-5 | IO48 | 空き |
| P1-6 | IO15 | **目CS左** | | P2-6 | IO45 | ⚠使用禁止(strapping) |
| P1-7 | IO7 | **目RST(共有)** | | P2-7 | IO38 | 空き |
| P1-8 | IO6 | **目DC(共有)** | | P2-8 | IO39 | 空き |
| P1-9 | IO5 | **目MOSI(SDA)** | | P2-9 | IO40 | 空き |
| P1-10 | IO4 | **目SCLK(SCL)** | | P2-10 | IO41 | **サーボ左** |
| P1-11 | 3V3 | 目VCC(2枚とも) | | P2-11 | IO42 | **サーボ右** |
| P1-12 | GND | 目GND | | P2-12 | IO2 | 撫でタッチ(T2, 任意) |

- 目2枚はSPI共有(SCLK/MOSI/DC/RST共通、CSのみ個別)。**P1列だけで電源込みで完結**する配置。
- サーボのIO41/42はJTAGデフォルト=ブート時に信号が出ず起動ピクつきなし。
- ⚠ **サーボの電源(赤/茶)は必ず外部5Vから**。基板の5VピンはSG90のストール電流に耐えない。
  外部5VのGNDは P2-2(GND) と必ず共通化。信号線(橙)は3.3Vロジック直結でOK。
- 撫でタッチを使う時: 導電パッド/銅箔をIO2へ→ platformio.iniの `-DPET_TOUCH_PIN=-1` を `=2` に。

### 切り替え運用
- **devkit目基板に戻す**: 1732S019を抜いてdevkitをUSBへ(モニタがttyACM/CH343を自動検出)。
- **コンボに切り替え**: `pio run -e esp32-1732S019-combo -t upload` して1732S019をRDKへ。
  表示専用に戻すなら `esp32-1732S019` envを焼き直すだけ。
- 疎通確認: `curl 'http://<board>:8080/eye?raw=ping'` → display_send.log に `pong`。
