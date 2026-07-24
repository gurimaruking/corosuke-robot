#!/usr/bin/env python3
"""物理ボタンで安全シャットダウン(RDK X5 40pin)。
配線: モーメンタリ押しSWを BOARD pin18(GPIO24) ↔ pin20(GND) に接続。
既定でHIGH(ボード内蔵プルアップ), 押すとLOW。誤操作防止に約1秒の長押しで shutdown。
systemd(root)で常駐。ボタン未接続でもHIGHのまま待つだけで無害。
"""
import time
import subprocess
import Hobot.GPIO as GPIO

PIN = 18          # BOARD番号(GPIO24)。GNDは隣のpin20
HOLD = 1.0        # 長押し確定に必要な秒(誤操作防止)
POLL = 0.05

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
GPIO.setup(PIN, GPIO.IN)   # 既定HIGH。押下でGNDに落ちてLOW

try:
    while True:
        if GPIO.input(PIN) == 0:            # 押された(LOW)
            held = 0.0
            while GPIO.input(PIN) == 0 and held < HOLD:
                time.sleep(POLL)
                held += POLL
            if held >= HOLD - 1e-6:         # 長押し確定 → 安全終了
                subprocess.run(["shutdown", "-h", "now"])
                break
            # 短押しは無視(チャタリング/誤タッチ対策)
        time.sleep(POLL)
finally:
    GPIO.cleanup()
