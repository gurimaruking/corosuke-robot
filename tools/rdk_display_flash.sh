#!/bin/bash
# CYD(ディスプレイ)ファームを遠隔フラッシュ (RDK X5上で実行)。
#   ⚠️ RDKにはS3が2枚(目/表示)。焼く前に PORT が本当にディスプレイ(CH340 1a86:7523)かを
#      検証し、違えば中止 = 目基板(1a86:55d3)を絶対に焼かない安全策。
#   アプリ領域(0x10000)のみ更新(bootloader/partitionは不変なのでfirmware.binだけでOK)。
#
# 使い方: bash rdk_display_flash.sh [firmware.bin] [/dev/ttyUSB0]
set -u
BIN="${1:-$HOME/firmware_display.bin}"
PORT="${2:-/dev/ttyUSB0}"

VP=$(python3 - "$PORT" <<'PY'
import sys
from serial.tools import list_ports
p = sys.argv[1]
hit = "none"
for x in list_ports.comports():
    if x.device == p:
        hit = f"{x.vid:04x}:{x.pid:04x}" if x.vid else "----:----"
        break
print(hit)
PY
)
echo "port $PORT vid:pid = $VP"
if [ "$VP" != "1a86:7523" ]; then
  echo "ABORT: $PORT はディスプレイ(1a86:7523)ではない($VP)。目基板保護のため焼かない。"
  exit 1
fi
if [ ! -f "$BIN" ]; then echo "ABORT: $BIN が無い"; exit 1; fi

# センダ停止(ポート解放)。このbashは comm=bash なので巻き込まれない。
for pp in $(pgrep -f display_send.py 2>/dev/null); do
  [ "$(cat /proc/$pp/comm 2>/dev/null)" = python3 ] && kill "$pp" 2>/dev/null
done
sleep 2

echo "=== flashing $BIN -> $PORT @0x10000 ==="
python3 -m esptool --chip esp32s3 --port "$PORT" --baud 460800 \
  --before default_reset --after hard_reset write_flash 0x10000 "$BIN"
echo "flash rc=$?"
