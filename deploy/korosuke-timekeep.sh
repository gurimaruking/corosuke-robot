#!/bin/sh
# RTC電池レス環境の時刻保存/復元(fake-hwclock方式・追加パッケージ不要)
F=/var/lib/korosuke/last_time
mkdir -p /var/lib/korosuke
case "$1" in
  restore)
    Y=$(date +%Y)
    # 現在時刻が2020年より前(=RTCリセット)なら、保存済み時刻へ復元
    if [ -f "$F" ] && [ "$Y" -lt 2020 ]; then date -s "$(cat "$F")"; fi
    ;;
  save)
    date +"%Y-%m-%d %H:%M:%S" > "$F"
    ;;
esac
