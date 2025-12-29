# 🤖 Corosuke Robot / コロ助ロボット

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: ESP32](https://img.shields.io/badge/Platform-ESP32-blue.svg)](https://www.espressif.com/)
[![3D Print: OpenSCAD](https://img.shields.io/badge/3D%20Print-OpenSCAD-orange.svg)](https://openscad.org/)

An open-source animatronic robot inspired by Korosuke from "Kiteretsu Daihyakka" (キテレツ大百科), featuring expressive eyes, lip-sync speech, and bipedal walking.

[English](#english) | [日本語](#japanese)

---

<a name="english"></a>
## 🇬🇧 English

### Overview

This project creates a full-size (50cm) Korosuke robot inspired by:
- **Disney's Olaf Robot** - Expressive animatronic eyes and face
- **BDX Droid** - Bipedal walking mechanism

### Features

| Feature | Description |
|---------|-------------|
| **Expressions** | 8-axis eyes (up/down/left/right + blink) + 2-axis mouth + LED rings |
| **Walking** | 8-axis bipedal walking (penguin-style gait) |
| **AI Chat** | LLM integration + VOICEVOX TTS (speaks with "~nari" suffix) |
| **Vision** | Camera-based person detection |
| **Control** | Smartphone app + autonomous mode |
| **Accessory** | 3D-printed sword on back |

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Corosuke System Architecture                  │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐     WiFi      ┌─────────────────────────────┐ │
│  │ Mobile App  │◀────────────▶│      Home Server            │ │
│  │  (Flutter)  │              │   (Raspberry Pi / PC)       │ │
│  └─────────────┘              │  ┌─────────┐ ┌───────────┐  │ │
│                               │  │ LLM API │ │ VOICEVOX  │  │ │
│                               │  └─────────┘ └───────────┘  │ │
│                               └──────────────────────────────┘ │
│                                       ▼                        │
│  ┌───────────────────────────────────────────────────────────┐│
│  │                    Robot Body                              ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐││
│  │  │ ESP32-S3-CAM │  │ ESP32        │  │ ESP32            │││
│  │  │ (Camera+AI)  │  │ (Upper Body) │  │ (Lower Body)     │││
│  │  └──────────────┘  └──────────────┘  └──────────────────┘││
│  └───────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Bill of Materials (BOM)

| Category | Items | Est. Cost |
|----------|-------|-----------|
| Electronics | ESP32 x3, Servos x24, IMU, Audio | ~$180 |
| 3D Printing | PLA, TPU filaments | ~$50 |
| Mechanical | Bearings, screws, rods | ~$30 |
| **Total** | | **~$260** |

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/corosuke-robot.git
   cd corosuke-robot
   ```

2. **Set up the home server**
   ```bash
   cd server
   pip install -r requirements.txt
   cp .env.example .env
   # Edit .env with your API keys
   python main.py
   ```

3. **Flash firmware** (using PlatformIO)
   ```bash
   cd firmware/corosuke_upper
   pio run --target upload
   ```

4. **3D print parts** (using OpenSCAD)
   ```bash
   openscad hardware/3d_models/head/eye_mechanism.scad -o eye_mechanism.stl
   ```

### Directory Structure

```
corosuke/
├── firmware/           # ESP32 firmware (PlatformIO)
│   ├── corosuke_main/  # Main board (camera, WiFi, audio)
│   ├── corosuke_upper/ # Upper body (face, arms)
│   ├── corosuke_lower/ # Lower body (walking)
│   └── common/         # Shared headers
├── server/             # Python home server
├── hardware/
│   ├── pcb/            # KiCad PCB designs
│   └── 3d_models/      # OpenSCAD 3D models
└── docs/               # Documentation
```

---

<a name="japanese"></a>
## 🇯🇵 日本語

### 概要

ディズニーのオラフロボットとBDXドロイドを参考に、フルサイズ（約50cm）のコロ助ロボットを製作するオープンソースプロジェクトです。

### 主な機能

| 機能 | 詳細 |
|------|------|
| **表情表現** | 目8軸（上下左右+まばたき）+ 口2軸 + LEDリング |
| **二足歩行** | 8軸（コロ助らしいペンギン歩き） |
| **AI会話** | LLM + VOICEVOX合成音声（「〜ナリ」語尾） |
| **人物検知** | カメラで自律反応 |
| **操作** | スマホアプリ + 自律モード |
| **装備** | 背中に刀（3Dプリント製） |

### 部品表（BOM）

| カテゴリ | 内容 | 概算価格 |
|----------|------|----------|
| 電子部品 | ESP32 x3, サーボ x24, IMU, オーディオ | 約¥27,000 |
| 3Dプリント材料 | PLA, TPU フィラメント | 約¥7,500 |
| 機構部品 | ベアリング、ネジ、ロッド | 約¥4,500 |
| **合計** | | **約¥39,000** |

### クイックスタート

1. **リポジトリをクローン**
   ```bash
   git clone https://github.com/YOUR_USERNAME/corosuke-robot.git
   cd corosuke-robot
   ```

2. **ホームサーバーをセットアップ**
   ```bash
   cd server
   pip install -r requirements.txt
   cp .env.example .env
   # .envにAPIキーを設定
   python main.py
   ```

3. **ファームウェアを書き込み**（PlatformIO使用）
   ```bash
   cd firmware/corosuke_upper
   pio run --target upload
   ```

4. **3Dパーツを印刷**（OpenSCAD使用）
   ```bash
   openscad hardware/3d_models/head/eye_mechanism.scad -o eye_mechanism.stl
   ```

---

## Development Phases / 開発フェーズ

1. **Phase 1**: Head & Expression System / 頭部・表情システム
2. **Phase 2**: AI & Voice System / AI・音声システム
3. **Phase 3**: Body & Arms / 胴体・腕
4. **Phase 4**: Bipedal Walking / 二足歩行
5. **Phase 5**: Integration & Mobile App / 統合・スマホアプリ

## References / 参考資料

- [Disney Olaf Robot](https://thewaltdisneycompany.com/olaf-robotic-character/)
- [Open Duck Mini (BDX)](https://github.com/apirrone/Open_Duck_Mini)
- [Animatronic Eye Tutorial](https://www.instructables.com/Simplified-3D-Printed-Animatronic-Dual-Eye-Mechani/)

## Contributing / 貢献

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License / ライセンス

MIT License - See [LICENSE](LICENSE) for details.

---

## Disclaimer / 免責事項

This is a fan-made project for educational and personal use. "Korosuke" (コロ助) is a character from "Kiteretsu Daihyakka" created by Fujiko F. Fujio. All character rights belong to their respective owners.

---

**「ワガハイはコロ助ナリ！」** 🤖
