#!/bin/bash
# コロ助 胴体ディスプレイ 常駐起動 (RDK X5上で実行)
#   RDK内の処理済み映像(:8080/stream, YOLO/骨格入り)を USB(CH340=/dev/ttyUSB*) で CYD へ常時配信。
#   カメラは korosuke_monitor が握っているので、直接cam:0でなくローカルMJPEGを引く=競合しない。
#   SSHが切れても走り続けるよう nohup + disown。ポートは display_send.py の --port auto が
#   VID/PID(1a86:7523=ディスプレイ)で選別 → 目基板(ttyACM0/CH343)は掴まない。
#
# 使い方: bash rdk_display_start.sh        # 起動(既存センダは停止してから)
#         bash rdk_display_start.sh stop   # 停止のみ
set -u
SEND="${HOME}/display_send.py"
LOG="${HOME}/display_send.log"
SRC="mjpeg:http://127.0.0.1:8080/stream"

# 既存の python センダだけ停止 (このbashは comm=bash なので巻き込まれない = 自滅しない)
for p in $(pgrep -f display_send.py 2>/dev/null); do
  [ "$(cat /proc/$p/comm 2>/dev/null)" = python3 ] && kill "$p" 2>/dev/null
done
sleep 1

if [ "${1:-}" = "stop" ]; then
  echo "stopped."
  exit 0
fi

nohup python3 -u "$SEND" --port auto --source "$SRC" > "$LOG" 2>&1 < /dev/null &
disown
sleep 6
echo "=== log (tail) ==="
tail -n 10 "$LOG"
echo "=== running python sender ==="
for p in $(pgrep -f display_send.py 2>/dev/null); do
  [ "$(cat /proc/$p/comm 2>/dev/null)" = python3 ] && echo "pid $p RUNNING"
done
