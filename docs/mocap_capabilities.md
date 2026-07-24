# コロ助 モーションキャプチャ/姿勢認識の能力調査（RDK X5 / Sunrise）

> D-Robotics公式スタックの調査(3票検証)。実機導入済みパッケージと突合。2026-07-24。
> 全機能は共通メッセージ `ai_msgs/msg/PerceptionTargets` で疎結合連携。

## 要点
- RDK X5には**人体骨格・手ランドマーク・ジェスチャ・人追従・転倒検知・再識別**が**実機導入済み**で揃っている。
- **動作模倣(mocap)の一次ソースは2つだけ**: `mono2d_body_detection`(全身骨格・BPU・X5対応) と `hand_lmk_detection`(手21点)。他は消費側の応用ノード。
- カメラ1台で今日試せる: `gesture_control`(手ジェスチャ→/cmd_vel) / `mono2d_body_detection`(骨格可視化)。結果は `http://[RDK_IP]:8000` で可視化。

## 能力マップ（★=実機導入済み）
| カテゴリ | リポジトリ | 出力トピック | X5 | 導入 |
|---|---|---|---|---|
| 人体骨格 | mono2d_body_detection | /hobot_mono2d_body_detection (body_kps) | ○(fasterRcnn経路) | ★ |
| 手21点 | hand_lmk_detection | /hobot_hand_lmk_detection | ○ | ★(要前段: body) |
| ジェスチャ分類 | hand_gesture_detection | /hobot_hand_gesture_detection(静的8+動的3) | ○ | ★ |
| ジェスチャ操縦 | gesture_control | /cmd_vel | ○ | ★ |
| 人追従 | body_tracking | /cmd_vel | ○ | ★ |
| 転倒検知 | hobot_falldown_detection | /hobot_falldown_detection | ⚠️X5明記なし | ★ |
| 再識別 | reid | /perception/detection/reid(512次元) | ○ | ★ |

## コロ助での活用（優先順）
1. **骨格→腕サーボへ動作模倣(2D mocap)** — `body_kps`から肩肘手首の角度を計算しサーボへ。難易度中。**前提: コロ助に腕サーボが未搭載**(現行は静的)。
2. **手ジェスチャに反応** — `hand_gesture_detection`のコードを動作へ(ThumbUp=頷き, Palm=停止 等)。難易度低。
3. **人追従で首/目を向ける** — `body_tracking`。難易度低〜中。

## 注意
- `mono2d_body_detection`はX5では必ず `model_type=0`(fasterRcnn)。yolo-pose経路はS100/S600専用。
- キーポイント点数はREADMEに数値明記が薄い(COCO17点前後 or 18点)。実機の`PerceptionTargets.points`長で要確認。
- `hobot_mot`はリポジトリ未取得。`hobot_falldown_detection`のX5対応は要実機確認。
- **可動機構が前提**: mocap活用は腕/首サーボの追加が要る。表情+音声の完成後の別フェーズ。

## 起動例（要ネット/apt、`export CAM_TYPE=usb`）
```
source /opt/tros/humble/setup.bash
cp -r /opt/tros/humble/lib/mono2d_body_detection/config/ .
ros2 launch mono2d_body_detection mono2d_body_detection.launch.py   # X5: model_type=0
```
