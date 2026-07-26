# コロ助 接続図 / Wiring & connection diagram

主要部品（RDK X5 / ESP32-S3 / カメラ / MAX98357A / スピーカー / 目 / 腕サーボ /
電源2系統）の接続。**電源は2系統（RDK用モバイルバッテリ ＋ サーボ用LiPo）で、GNDは共通**。

```mermaid
flowchart TB
  PB(["🔋 モバイルバッテリ / Power bank<br/>5V ≥ 3A"]):::pwr
  LIPO(["🔋 LiPo（サーボ用）<br/>→ 5V BEC/レギュレータ"]):::pwr

  subgraph RDK["RDK X5 — 頭脳 (Ubuntu, on-device)"]
    P40["40-pin ヘッダ"]
    USBH["USB ポート"]
  end

  subgraph ESP["ESP32-S3 — 目/腕 コプロセッサ"]
    EG["GPIO / SPI"]
  end

  PB  -->|"USB-C 5V/3A"| RDK
  CAM(["📷 カメラ C270（マイク内蔵）"]):::io -->|"USB (映像+音声)"| USBH
  BTN(["⏻ 安全シャットダウンSW"]):::io -->|"pin18 (GPIO24) ↔ pin20 (GND)"| P40
  USBH -->|"USBケーブル = 電源 + データ<br/>(/dev/ttyACM0)"| ESP

  P40 -->|"pin2/4 = 5V · pin6 = GND"| AMP
  P40 -->|"pin12 BCLK · pin35 LRC · pin40 DIN"| AMP
  AMP["🔈 MAX98357A I2Sアンプ<br/>(GAIN 未接続 = 9dB)"]:::amp -->|"アナログ +/−"| SPK(["🔊 φ50 スピーカー"]):::io

  EG -->|"SPI: SCK12 MOSI11 DC9 RST8<br/>CS_L10 / CS_R14 · 3V3 · GND"| EYES(["👁 2× GC9A01 丸型LCD"]):::io
  EG -->|"信号: GPIO4(左) / GPIO5(右)"| SRV(["💪 2× SG90 サーボ（腕）"]):::io
  LIPO -->|"5V（サーボ電源）"| SRV
  LIPO -.->|"⚠ 共通GND (必須)"| ESP

  classDef pwr fill:#f6b73f,color:#3a2a00,stroke:#c98a12,stroke-width:2px;
  classDef io  fill:#2dd4a7,color:#06231b,stroke:#12a17f;
  classDef amp fill:#ff5a3c,color:#fff,stroke:#c93b1a;
```

## 接続表（配線一覧）

| From | ピン/ポート | → To | ピン | 内容 |
|---|---|---|---|---|
| モバイルバッテリ | USB-C 5V/3A | RDK X5 | USB-C(電源) | RDK電源 |
| RDK X5 | USB-A | ESP32-S3 | USB(ネイティブCDC) | **電源+データ**（`/dev/ttyACM0`） |
| RDK X5 40pin | **2/4**=5V, **6**=GND | MAX98357A | VIN, GND | アンプ電源 |
| RDK X5 40pin | **12**=BCLK, **35**=LRC, **40**=DIN | MAX98357A | BCLK/LRC/DIN | I2S音声出力 |
| MAX98357A | +/− | φ50スピーカー | — | アナログ出力 |
| RDK X5 40pin | **18**(GPIO24), **20**(GND) | 押しボタン | — | 安全シャットダウン |
| RDK X5 | USB-A | カメラ C270 | USB | 映像 + マイク |
| ESP32-S3 | 12/11/9/8/10/14 + 3V3/GND | 2× GC9A01 | SCK/MOSI/DC/RST/CS_L/CS_R | 目（SPI共有・CS分離） |
| ESP32-S3 | **GPIO4**(左) / **GPIO5**(右) | 2× SG90 | 信号 | 腕サーボPWM |
| LiPo → 5V BEC | +5V | SG90 サーボ | V+ | **サーボ専用電源** |
| LiPo | GND | ESP32-S3 / RDK | GND | **共通GND（必須）** |

## 注意 / ポイント
- **電源2系統**: RDK X5 はモバイルバッテリ（5V/3A以上・良質なUSB-Cケーブル。半差し/細ケーブルはブラウンアウトの原因 → [power_usb_troubleshooting.md](power_usb_troubleshooting.md)）。サーボは**別のLiPo**で駆動（突入電流でRDKを落とさないため）。
- **共通GND必須**: LiPo(サーボ) と ESP32-S3/RDK の GND を必ず繋ぐ。繋がないとサーボPWMが不安定。
- **SG90は4.8〜6V**。LiPoが7.4V(2S)等なら BEC/レギュレータで5Vへ。
- **ESP32-S3への配線は基本USB1本**（電源+`ttyACM0`データ）。UART直結にする場合は ESP32 RX=GPIO18 / TX=GPIO17（[firmware/corosuke_eyes](../firmware/corosuke_eyes)）。
- **MAX98357A GAIN**: 未接続=9dB（既定）。詳細 → [rdk_x5_40pin_i2s_max98357a.md](rdk_x5_40pin_i2s_max98357a.md)。
- 目の詳細ピンは [firmware/corosuke_eyes/src/main.cpp](../firmware/corosuke_eyes/src/main.cpp) 冒頭コメント参照。
