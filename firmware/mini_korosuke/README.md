# firmware/mini_korosuke — ミニコロ助 (ESP32-S3 単体 / 完全オフライン)

[docs/mini_korosuke_design.md](../../docs/mini_korosuke_design.md) の実装。
ベースボード = **Elecrow ESP Terminal 3.5"**（ESP32-S3, 320×480 ILI9488 SPI, 静電容量タッチ FT6236, OV2640 同梱, 16MB/8MB）。

目の描画は本体の [firmware/corosuke_eyes](../corosuke_eyes/src/main.cpp) から移植（丸型GC9A01×2 → 単画面ILI9488に左右2目）。

## フェーズ
| Ph | 内容 | 本ファイルの状態 |
|----|------|------------------|
| **Ph1** | 単画面に左右2目＋表情8種＋まばたき＋視線（デモ巡回） | ✅ `src/main.cpp` |
| Ph2 | 静電タッチ(なで)→笑顔＋MAX98357A(I2S)でWAV再生 | ⏳ 未 |
| Ph3 | OV2640＋ESP-WHO顔検出→視線追従＋発見で笑顔 | ⏳ 未 |

## ピン割り当て
**確定（Elecrow wiki）**
| 機能 | ピン |
|------|------|
| SD (SPI) | SCK=12 MOSI=13 MISO=14 CS=10 |
| Touch FT6236 (I2C) | SDA=2 SCL=1 |
| Buzzer | 45 |
| Mic (I2S) | CLK=39 WS=38 |
| Camera OV2640 | MCLK=7 PCLK=17 / D2..D9=8,47,48,21,18,16,15,6 |
| Crowtail | D=11,40 / A=19,20 / UART RX=44 TX=43 |

**★未確定（実機スキーマで要確認）— `src/main.cpp` 冒頭の `PIN_LCD_*`**
- LCD ILI9488 の **CS / DC / RST / BL**。本S3+カメラ版の確定値が未取得。
- LCDはSDと同一SPIバス（SCK12/MOSI13/MISO14）を共有する前提で設定済み。
- ネット上に出回る `CS15/DC2/BL27` は**旧ESP32(非S3)版**の値。**DC=2 は本機の Touch SDA=2 と衝突**するので流用不可。
- 現状の `PIN_LCD_CS=3 / DC=42 / RST=-1 / BL=46` は「確定ピンと衝突しない仮値」。**ボード到着後に必ず実測して修正**すること。

**Ph2の音声増設（予定）**: 在庫の MAX98357A を I2S で Crowtail の空きGPIO（D=11,40 ＋ A=19 等）へ。BCLK/LRCLK/DIN の3本。

## ビルド & 書き込み
```bash
pio run -e elecrow-esp-terminal-35 -t upload
pio device monitor -b 115200
```
※ ★未確定ピンを埋める前は正しく表示されない。まず `PIN_LCD_*` を実機で確定させること。

## シリアルコマンド（USB-CDC / 115200・センサ無しで動作確認可）
```
emo <neutral|happy|happy2|sad|angry|surprised|sleepy|thinking|x>
gaze <x> <y>     # -1.0..1.0
blink
wink <l|r>
idle <on|off>
demo <on|off>    # 表情8種を自動巡回(初期ON)
ping             # -> pong
```

## 音声クリップの用意（別途・PC/RDK側）
声質はコロ助と同一（`-fm 9 -a 0.40 -r 1.12`）。Open JTalk のある環境で:
```bash
python3 ../../tools/mini_voice_gen.py            # WAV + manifest.json + include/voice_clips.h を生成
python  ../../tools/mini_voice_gen.py --dry-run  # Windows等: 先にヘッダ/マニフェストだけ
```
生成物: `assets/mini_voice/*.wav`（microSDの `/voice/` に配置）と `include/voice_clips.h`（Ph2でincludeして使用）。
