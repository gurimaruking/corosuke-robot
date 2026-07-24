#!/usr/bin/env python3
"""物理ボタンで安全シャットダウン(RDK X5 40pin)。
配線: モーメンタリ押しSWを BOARD pin18(GPIO24) ↔ pin20(GND) に接続。
既定でHIGH(ボード内蔵プルアップ), 押すとLOW。誤操作防止に約1秒の長押しで shutdown。
systemd(root)で常駐。ボタン未接続でもHIGHのまま待つだけで無害。
"""
import time
import subprocess
import urllib.request
import urllib.parse
import Hobot.GPIO as GPIO

PIN = 18          # BOARD番号(GPIO24)。GNDは隣のpin20
HOLD = 1.0        # 長押し確定に必要な秒(誤操作防止)
POLL = 0.05
BYE = "おやすみナリ…また会おうナリ！"   # 終了時の音声+Web表示
MON = "http://127.0.0.1:8080"


def notify_shutdown():
    """モニタ経由で 眠い目 + 『おやすみ』音声(再生完了まで同期) + Web吹き出し。
    sync=1 でモニタ側が再生完了までブロックして返すので、shutdownで途中切れしない。"""
    try:
        urllib.request.urlopen(MON + "/eye?emo=sleepy", timeout=3).read()
    except Exception:  # noqa
        pass
    try:
        urllib.request.urlopen(
            MON + "/say?text=" + urllib.parse.quote(BYE) + "&sync=1", timeout=20).read()
    except Exception:  # noqa: モニタ停止中でも終了は続行
        pass


def mark_off():
    """終了直前に目を✕✕にする。RDK停止後もESP32が最後の表示を保持するので
    『✕の目が出た=RDKは止まった=ポータブル電源を切ってOK』の視覚合図になる。"""
    try:
        urllib.request.urlopen(MON + "/eye?emo=x", timeout=3).read()
    except Exception:  # noqa
        pass

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
                notify_shutdown()           # 眠い目+「おやすみナリ」音声(再生完了まで同期)+Web
                mark_off()                  # ✕✕の目(電源OFF可の合図)
                time.sleep(1)               # ✕コマンドが目に届くのを待つ
                subprocess.run(["shutdown", "-h", "now"])
                break
            # 短押しは無視(チャタリング/誤タッチ対策)
        time.sleep(POLL)
finally:
    GPIO.cleanup()
