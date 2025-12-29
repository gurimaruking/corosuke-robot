# 3MFパーツエクスポート / 3MF Parts Export

色付き3MFファイルをエクスポートするためのファイル一式です。

## パーツ一覧 / Parts List

| ファイル | パーツ | 色 |
|----------|--------|-----|
| `export_head_face.scad` | 顔シェル | クリーム (#FFDAB9) |
| `export_head_eyeball_*.scad` | 眼球 | 白+黒 |
| `export_head_nose.scad` | 鼻 | 赤 (#FF0000) |
| `export_head_topknot.scad` | 丁髷 | 黒 (#000000) |
| `export_head_mouth.scad` | 口 | 赤 (#CC0000) |
| `export_body_torso.scad` | 胴体 | オレンジ (#FF8C00) |
| `export_arm_*.scad` | 腕 | 水色縞 (#87CEEB) |
| `export_hand_*.scad` | 手 | 肌色 (#FFDAB9) |
| `export_leg_*.scad` | 脚 | 青 (#4169E1) |
| `export_foot_*.scad` | 足 | 青 (#4169E1) |
| `export_sword_full.scad` | 刀 | 赤鞘+青車輪 |
| `export_corosuke_full.scad` | フルアセンブリ | 全色 |

## 使い方 / How to Use

### 手動エクスポート / Manual Export

1. OpenSCADで `.scad` ファイルを開く
2. F6キーでレンダリング
3. `File` → `Export` → `Export as 3MF`
4. ファイル名を付けて保存

### 一括エクスポート / Batch Export

1. `export_all.bat` をダブルクリック
2. OpenSCADのパスが正しいことを確認
3. すべての3MFファイルが自動生成されます

## カラーパレット / Color Palette

```
顔・手:     #FFDAB9 (PeachPuff)
胴体:       #FF8C00 (DarkOrange)
腕:         #87CEEB (SkyBlue)
腕の縞:     #4682B4 (SteelBlue)
脚・足:     #4169E1 (RoyalBlue)
鼻・ボタン: #FF0000 (Red)
丁髷:       #000000 (Black)
刀の鞘:     #CC0000 (DarkRed)
車輪:       #1E90FF (DodgerBlue)
金装飾:     #FFD700 (Gold)
```
