# Korosuke ROS 2 workspace (RDK X5 cognitive core)

Stage 3 の実装。RDK X5 (ROS 2 Humble) を頭脳に、コロ助が
**見る → 追う → 挨拶する → 表情/声で反応する** をオンデバイスで動かす。

## パッケージ
| pkg | 中身 |
|---|---|
| `korosuke_msgs` | `EyeCmd`(emotion/gaze/blink), `FacePose`(detected/x/y/size) |
| `korosuke_nodes` | `vision`(BPU YOLO11n→/face_pose), `brain`(追従+挨拶), `serial_bridge`(→ESP32目UART), `dialogue`(Claude+「ナリ」), `voice`(VOICEVOX), `eye_demo`(M2実証) |

## データフロー
```
camera ─► vision_node ─/face_pose─► brain_node ─/eye_cmd──► serial_bridge ─UART─► ESP32-S3(目)
                                        └────────/greet──► dialogue_node ─/say_text─► voice_node ─► spk
                                                             └─────────/eye_cmd──────► serial_bridge
```

## ビルド
```bash
source /opt/ros/humble/setup.bash
cd ~/corosuke/ros2_ws
colcon build --symlink-install
source install/setup.bash
```

## 実行
```bash
# 全部まとめて
ros2 launch korosuke_nodes korosuke.launch.py

# 目だけ動作実証(M2, カメラ/LLM不要)。ESP32-S3をUSB接続してから:
ros2 run korosuke_nodes serial_bridge &
ros2 run korosuke_nodes eye_demo

# 手入力でコロ助と会話(STT代わり)
ros2 topic pub --once /korosuke/user_text std_msgs/String "{data: 'コロッケ好き？'}"
```

## 前提
- `ANTHROPIC_API_KEY` を export すると LLM 応答。無ければ定型「ナリ」応答。
- VOICEVOX を `localhost:50021`(または `VOICEVOX_HOST`)で起動すると発声。無ければセリフ表示のみ。
- 目: `firmware/corosuke_eyes` を焼いた ESP32-S3 を USB 接続(テキスト行 115200bps)。
