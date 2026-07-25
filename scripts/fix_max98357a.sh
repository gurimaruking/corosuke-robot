#!/bin/bash
# MAX98357A(I2S 40pin)サウンドカードが開けるか検証し、開けなければ
# snd_soc_simple_card を再ロードして再バインドする。
# 目的: コールドブート時のモジュール・ロード順レースで card が半端になり
#       aplay が "Invalid argument" で開けなくなる問題の自動対策。
# 実行: root（起動時 systemd oneshot / monitor からは sudo 経由）。
DEV="plughw:max98357a,0"

test_open() {
  # 0.05秒の無音(9600B=S16_LE/48k/2ch)を再生して PCM open を検証（無音なので聞こえない）
  head -c 9600 /dev/zero 2>/dev/null | \
    aplay -q -D "$DEV" -f S16_LE -r 48000 -c 2 -t raw >/dev/null 2>&1
}

if test_open; then
  echo "OK: max98357a already openable"
  exit 0
fi

echo "NG: max98357a not openable -> reloading snd_soc_simple_card"
modprobe -r snd_soc_simple_card 2>/dev/null
sleep 1
modprobe snd_soc_simple_card 2>/dev/null
sleep 2

if test_open; then
  echo "OK: max98357a re-bound"
  exit 0
else
  echo "NG: max98357a still not openable"
  exit 1
fi
