# 3MFエクスポート / 3MF Export

色付きの3MFファイルをエクスポートする方法

## ファイル一覧

| ファイル | 説明 |
|----------|------|
| `corosuke_full_assembly.scad` | フルアセンブリ（プレビュー用） |
| `parts_for_3mf.scad` | 個別パーツ（印刷用） |
| `export_all_3mf.bat` | 一括エクスポートスクリプト |

## 手動エクスポート方法

1. OpenSCADで `.scad` ファイルを開く
2. 出力したいパーツのコメントを外す
3. `File` → `Export` → `Export as 3MF`
4. ファイル名を付けて保存

## パーツリスト

### 頭部 / Head
- `head_face_shell` - 顔面シェル（ピンク）
- `head_skull_frame` - 頭蓋骨フレーム（白）
- `head_eyeball_*` - 眼球（白+黒）
- `head_eyelid_*` - まぶた（ピンク）
- `head_mouth_*` - 唇（コーラルピンク）
- `head_topknot` - 丁髷（黒）

### 胴体 / Body
- `body_torso_shell` - 胴体外装（茶色/風呂桶）
- `body_torso_frame` - 胴体フレーム（グレー）

### 腕 / Arms
- `arm_upper_*` - 上腕（白）
- `arm_lower_*` - 前腕（白）
- `arm_hand_*` - 手（ピンク）

### 脚 / Legs
- `leg_thigh_*` - 大腿部（白）
- `leg_shin_*` - 下腿部（白）
- `leg_foot_*` - 足（白）
- `leg_foot_sole_*` - 足裏（TPU用・ダークグレー）

### 刀 / Sword
- `sword_blade` - 刀身（シルバー）
- `sword_handle` - 柄（茶色+金）
- `sword_guard` - 鍔（金）
- `sword_sheath` - 鞘（黒+金）
- `sword_wheel` - 車輪（グレー+黒）
- `sword_back_mount` - 背中マウント（グレー）

## カラーパレット

| パーツ | 色 | HEX |
|--------|------|-----|
| 顔・手 | Pink | `#FFC0CB` |
| 唇 | Light Coral | `#F08080` |
| フレーム | White | `#FFFFFF` |
| 胴体 | Burlywood | `#DEB887` |
| たが | Saddle Brown | `#8B4513` |
| 丁髷・鞘 | Black | `#000000` |
| 装飾 | Gold | `#FFD700` |
| 刀身 | Silver | `#C0C0C0` |
| 関節 | Gray | `#808080` |
| 足裏(TPU) | Dim Gray | `#696969` |

## 印刷推奨設定

| パーツ | 素材 | インフィル | サポート |
|--------|------|------------|----------|
| 顔・胴体シェル | PLA | 15% | 必要 |
| フレーム | PLA | 20% | 必要 |
| 関節部品 | PLA | 30% | 必要 |
| 足裏 | TPU | 20% | 不要 |
| 刀 | PLA | 20% | 必要 |
