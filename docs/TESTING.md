# コロ助 テストコマンド集(チートシート)

> 対象: RDK X5 (SSH), ESP32-S3(目), Windows(PlatformIO)。2026-07-24時点で全て動作確認済み。
> **鉄則**: オーディオデバイスは番号でなく名前で指定(`plughw:Microphone,0`=カメラマイク / `plughw:duplexaudio,0`=スピーカー)。カード番号は再起動で入れ替わる。

## 0. 接続

```bash
ssh sunrise@192.168.128.10          # パスワード: sunrise (ホスト名 korosuke)
```

Windowsから中身を触るヘルパー(paramiko、SSH不要でワンショット実行):
```bash
# scratchpad/rdk.py  —  run <cmd> / put <local> <remote> / get <remote> <local>
python rdk.py run "uptime"
```

## 1. 👁 目(ESP32-S3) — PCからでもRDKからでも

### コマンド言語(115200bps テキスト行)
```
ping        → pong    emo <neutral|happy|sad|angry|surprised|sleepy>
blink       wink <l|r>   gaze <x> <y>  (-1.0〜1.0)   idle <on|off>
```

### RDK X5から目を直接叩く(/dev/ttyACM0)
```bash
python3 - <<'EOF'
import serial, time
p = serial.Serial('/dev/ttyACM0', 115200, timeout=0.5); time.sleep(0.5)
for cmd in ['ping','emo happy','gaze 0.5 0','blink']:
    p.write((cmd+'\n').encode()); time.sleep(0.4); print(cmd, '->', p.read(60))
p.close()
EOF
```

### ROS 2で目デモ(8表情巡回) ← M2実証
```bash
source /opt/ros/humble/setup.bash && source ~/corosuke/ros2_ws/install/setup.bash
ros2 run korosuke_nodes serial_bridge &     # 目ブリッジ常駐
ros2 run korosuke_nodes eye_demo            # Ctrl+Cで停止
# 手動で1コマンド:
ros2 topic pub --once /korosuke/eye_cmd korosuke_msgs/EyeCmd "{emotion: happy, gaze_x: 0.0, gaze_y: 0.0, blink: true}"
```

### Windowsから目のファーム更新(⚠️CH343=COM14側で)
```bash
pio run -d firmware/corosuke_eyes -t upload --upload-port COM14
# COM13(ネイティブUSB)で開くとDOWNLOADモードに落ちる罠あり。監視もCOM14で。
```

## 2. 👁 カメラ + 映像認識(YOLO11 on BPU)

```bash
# 静止画YOLO(疎通確認)
cd /app/pydev_demo/02_detection_sample/02_ultralytics_yolo11
python3 ultralytics_yolo11.py --img-save-path /tmp/yolo.jpg

# ライブカメラ→BPU(FPS計測付き。実測19.5FPS)
python3 cam_yolo.py     # ~/corosuke/scripts/cam_yolo.py と同じ

# カメラの対応解像度を見る
v4l2-ctl -d /dev/video0 --list-formats-ext
```

## 3. 🔊 スピーカー / 🎙 マイク

```bash
# スピーカーで再生(音量注意)
aplay -D plughw:duplexaudio,0 ~/corosuke/scripts/tts_ja.wav

# 音量調整
amixer -c duplexaudio sset 'DAC' 60%     # %指定
alsamixer -c duplexaudio                 # 画面で↑↓、Escで抜ける
sudo alsactl store                       # 再起動後も保持

# マイク5秒録音→自分で再生(自己テスト)
arecord -D plughw:Microphone,0 -f S16_LE -r 48000 -c 2 -d 5 /tmp/me.wav
aplay  -D plughw:duplexaudio,0 /tmp/me.wav
```

## 4. 💬 音声認識(STT)

```bash
# 【推奨/採用】sherpa-onnx + VAD で10秒しゃべって認識
python3 ~/corosuke/scripts/live_stt.py 10   # (voskベース版。sherpa版は下の比較ハーネス)

# モデル比較ハーネス(正解付き5文でCER+RTF)
python3 ~/corosuke/scripts/eval_stt.py --only sherpa_vad   # 採用構成
python3 ~/corosuke/scripts/eval_stt.py --only vosk         # 現行
python3 ~/corosuke/scripts/eval_stt.py                     # 全モデル三つ巴
# 結果の目安: RTF<0.5で対話可。sherpa_vad=0.44, vosk=1.79, kotoba=7.03(不採用)
```

## 5. 🌐 Web監視モニタ(このPCのブラウザから一望)

```
http://192.168.128.10:8080      ← カメラ映像 + マイクレベル + 音声認識字幕
```
起動/再起動(ボード上):
```bash
pkill -f korosuke_monitor
cd ~/corosuke/scripts && nohup python3 korosuke_monitor.py > /tmp/monitor.log 2>&1 &
# カメラを占有するので、cam_yolo等と同時起動不可(片方を止める)
```

## 6. 🩺 ボードの健康診断

```bash
sudo hrut_somstatus     # BPU/CPU/DDR 温度・周波数(要パスワード sunrise)
ros2 pkg executables korosuke_nodes   # 使えるノード一覧
arecord -l; aplay -l    # オーディオカード名の確認(番号は変わる)
```

---
### よくある罠
| 症状 | 原因 | 対処 |
|---|---|---|
| 目が真っ暗/無応答(Windows) | COM13ネイティブUSBで開いた | COM14(CH343)を使う。RST押下で復帰 |
| 音が出ない | デスクトップ音量スライダは無効 | `amixer -c duplexaudio` かスピーカー本体つまみ |
| 録音が無音 | スピーカー電源OFF/音源なし | 音源の実在をまず確認 |
| `plughw:1,0`でデバイス違い | カード番号が再起動で変化 | 名前指定(`plughw:Microphone,0`)にする |
| モニタとYOLOが同時に動かない | カメラは1プロセス占有 | 片方を pkill |
