#!/usr/bin/env python3
"""コロ助 Web監視モニタ v4 — 見て/聞いて/動きに反応して/喋る
  カメラ+YOLO人物検知+モーション検知 / sherpa音声認識+キーワード反応 / 目+OpenJTalk発声
使い方: python3 korosuke_monitor.py  →  http://<RDKのIP>:8080
依存: cv2, sherpa-onnx, open_jtalk, D-Robotics YOLO demo。各機能は失敗しても縮退。
"""
import warnings
warnings.filterwarnings("ignore")   # numpy等の非推奨警告でログが埋まるのを抑止

import audioop
import glob
import json
import math
import os
import re
import shutil
import struct
import subprocess
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import cv2

try:
    import serial   # pyserial (目ESP32-S3制御用)
except ImportError:
    serial = None

PORT = 8080
YOLO_DIR = "/app/pydev_demo/02_detection_sample/02_ultralytics_yolo11"
POSE_DIR = "/app/pydev_demo/04_pose_sample/01_ultralytics_yolo11_pose"
POSE_MODEL = POSE_DIR + "/yolo11n_pose_bayese_640x640_nv12.bin"
# COCO17: 0鼻 5左肩 6右肩 7左肘 8右肘 9左手首 10右手首 11左腰 12右腰
EYE_DEV = "/dev/ttyACM0"           # 目コプロセッサ(ESP32-S3)
# 出力先はsettings["spk_dev"]でWeb切替。カード名指定=再起動でカード番号が入替っても不変。
#   duplexaudio = オンボードES8326(既定) / max98357a = I2Sアンプ MAX98357A(40pin i2s1)

# ---- Open JTalk(動的日本語TTS) ----
OJ_BIN = "open_jtalk"
OJ_DIC = "/var/lib/mecab/dic/open-jtalk/naist-jdic"
OJ_VOICE = "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice"
os.chdir(YOLO_DIR)   # デモの相対import解決のため(以降は全て絶対パス使用)

# ==== Webから変更できる実行時設定 ====
settings = {
    "volume": 75,          # 音量 %(ES8326=amixer DAC / max98357a=ソフト音量)
    "spk_dev": "max98357a",  # 出力先: max98357a(I2Sアンプ40pin,φ50) / duplexaudio(ES8326)
    "dsp": True,           # max98357a時の小型SP最適化(HPF+圧縮+リミッタ)
    "hpf": 250,            # ハイパス周波数Hz(小型SPが出せない低域を除去しコーン保護)
    "peak_ceil_db": -6.0,  # クリーン天井dBFS。φ50=WYGD50D(0.2W)で-6採用(GAIN9dBのsine≈0.2W=定格,
                           # 声はピークのみ瞬間で平均は数mW→安全)。高耐入力SPに替えたら更に上げ可
    "mic_gain": 3.0,       # マイク感度(ソフト増幅倍率)。ハードゲインは起動時に最大化
    "oj_fm": 9,            # 声の高さ(Open JTalk -fm)。voice B=9
    "oj_a": 0.40,         # 声道長(小=子供っぽい)
    "oj_r": 1.12,         # 話速
    "react_greet": True,   # 入退室で挨拶する
    "react_speech": True,  # 話しかけに反応する
    "use_llm": True,       # キーワードに無い発話をローカルLLMで返答
    "stt_lang": "ja",      # 音声認識の言語: ja=日本語(ReazonSpeech) / en=英語(要英語モデル)
    "llm_lang": "ja",      # LLM応答の言語: ja=「ナリ」口調 / en=English
    "tts_lang": "ja",      # 音声合成の言語: ja=Open JTalk / en=espeak-ng(要インストール)
    "use_arm": True,       # 挨拶/ジェスチャで腕サーボを自動で動かす(調整中はOFF)
    "event_llm": False,    # 入退室/ジェスチャの台詞: True=LLM生成(多彩,数秒遅延)/False=定型(即時)
    # --- 認識の閾値(Webで調整可) ---
    "pose_score": 0.40,    # 人物検出の信頼度しきい値
    "kpt_thres": 0.40,     # 骨格キーポイントの信頼度しきい値(ジェスチャ判定)
    "gesture_cd": 5.0,     # ジェスチャ反応のクールダウン秒
}


def find_mic_card():
    """USBマイク(USB Audioキャプチャ)のカード名を返す。I2S(ES8326/max98357a)は除外。
    カメラ交換でカード名が変わっても追従(例: Microphone→WEBCAM)。"""
    try:
        out = subprocess.run(["arecord", "-l"], capture_output=True, text=True,
                             timeout=5).stdout
    except Exception:  # noqa
        return "Microphone"
    import re
    for line in out.splitlines():          # USBオーディオ(カメラ内蔵マイク)を優先
        if "USB Audio" in line:
            m = re.search(r"card \d+: (\S+) \[", line)
            if m:
                return m.group(1)
    for line in out.splitlines():          # フォールバック: I2S以外の最初のカード
        m = re.search(r"card \d+: (\S+) \[", line)
        if m and m.group(1) not in ("duplexaudio", "max98357a"):
            return m.group(1)
    return "Microphone"


_mic_card = [None]
def mic_card():
    if _mic_card[0] is None:
        _mic_card[0] = find_mic_card()
    return _mic_card[0]


def apply_mic_hw_gain():
    """USBマイクのハードキャプチャゲインを最大化(起動時)。制御名は機種で異なるため総当り。"""
    c = mic_card()
    for ctl in ("Mic Capture Volume", "Capture", "Mic"):
        try:
            subprocess.run(["amixer", "-c", c, "sset", ctl, "100%"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        except Exception:  # noqa
            pass
    for sw in ("Mic Capture Switch", "Capture"):
        try:
            subprocess.run(["amixer", "-c", c, "sset", sw, "on"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        except Exception:  # noqa
            pass


def apply_volume(pct):
    try:
        pct = max(0, min(100, int(pct)))
        settings["volume"] = pct
        subprocess.run(["amixer", "-c", "duplexaudio", "sset", "DAC", f"{pct}%"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:  # noqa
        pass

# ==== 反応辞書(キーワード→表情+セリフ)。誤認識パターンも含める。M-C=LLM導入で置換予定 ====
GREETINGS = [
    "だれか来たナリ！こんにちはナリ！",
    "やあ、ワガハイはコロ助ナリ！",
    "会えて嬉しいナリ〜！",
    "おっ、人が来たナリ！ようこそナリ！",
    "いらっしゃいナリ！待ってたナリ！",
    "こんにちはナリ！今日も元気ナリか？",
    "わーい、お客さんナリ！うれしいナリ！",
    "よく来てくれたナリ！歓迎するナリ！",
    "やっほー！ワガハイに会いに来たナリか？",
    "おはようナリ！いい一日にするナリ！",
]
SPEECH_REACTIONS = [
    (["こんにち", "やあ", "おはよう", "こんばん", "はろー"], "happy", "こんにちはナリ！"),
    (["ころすけ", "殺す", "コロスケ", "ころ助"], "happy", "ワガハイを呼んだナリ？"),
    (["コロッケ", "ころっけ"], "happy", "コロッケ！？大好物ナリ！"),
    (["かわい", "かっこ", "すご", "えらい"], "happy", "えへへ、照れるナリ〜"),
    (["ありがと", "さんきゅ"], "happy", "どういたしましてナリ！"),
    (["ばいばい", "さようなら", "またね", "バイバイ"], "sad", "またね、ナリ〜"),
    (["名前", "だれ", "誰", "なまえ"], "happy", "ワガハイはコロ助ナリ！"),
    (["好き", "だいすき"], "happy", "ワガハイも好きナリ！"),
    (["元気", "げんき"], "happy", "ワガハイは元気ナリ！"),
]
MOTION_LINES = ["おっ、動いたナリ！", "なんナリ？", "びっくりしたナリ！", "元気だナリ〜！"]
GEST_BANZAI = ["バンザイ！うれしいナリ！", "わーい！一緒にバンザイナリ！", "やったーナリ！ばんざーいナリ！"]
GEST_WAVE = ["手を振ってるナリ！こんにちはナリ！", "やっほーナリ！", "元気そうナリね！うれしいナリ！"]
GEST_HAND = ["はーい、ナリ！", "なあにナリ？", "こっちだナリ！ワガハイもあげるナリ！"]
PET_LINES = ["なでなで気持ちいいナリ〜！", "うれしいナリ！もっと撫でてほしいナリ！",
             "えへへ、くすぐったいナリ！", "ワガハイ、なでられるの大好きナリ！"]
_last_pet = [0.0]
FAREWELLS = [
    "いっちゃいやナリ〜！",
    "もう行っちゃうナリ？さみしいナリ…",
    "行かないでほしいナリ〜！",
    "またすぐ来てほしいナリ！",
    "ばいばいナリ〜、またねナリ！",
    "気をつけて行くナリ！",
    "待ってるナリ、また会おうナリ！",
    "しょんぼりナリ…早く戻ってきてほしいナリ！",
    "いってらっしゃいナリ！",
    "ワガハイ、待ってるナリよ〜！",
]

# ==== 英語モード(settings["llm_lang"]=="en")用の定型セリフ。日本語版と1対1で対応 ====
GREETINGS_EN = [
    "Hello there! I am Korosuke!",
    "Hi! Nice to meet you!",
    "Yay, a visitor! I am so happy!",
    "Welcome! I was waiting for you!",
    "Hi hi! Great to see you!",
    "Hello! How are you today?",
    "Wow, someone is here! Welcome!",
    "Thanks for coming to see me!",
    "Hey there! Did you come to see me?",
    "Good day! Let's have fun together!",
]
SPEECH_REACTIONS_EN = [
    (["hello", "hi ", "hey", "good morning", "good evening"], "happy", "Hello! Nice to see you!"),
    (["korosuke", "koro"], "happy", "Did you call me? I am Korosuke!"),
    (["croquette", "croquet"], "happy", "Croquettes?! They are my favorite!"),
    (["cute", "cool", "amazing", "great", "awesome"], "happy", "Hehe, you make me blush!"),
    (["thank", "thanks"], "happy", "You are very welcome!"),
    (["bye", "goodbye", "see you"], "sad", "Bye bye! See you again!"),
    (["name", "who are you"], "happy", "I am Korosuke, a little clockwork robot!"),
    (["love", "like you"], "happy", "I like you too!"),
    (["how are you", "are you ok"], "happy", "I am great, thank you!"),
]
MOTION_LINES_EN = ["Oh, something moved!", "What was that?", "You surprised me!", "So lively!"]
GEST_BANZAI_EN = ["Hurray! I am so happy!", "Yay! Banzai together!", "Woohoo! Hurray hurray!"]
GEST_WAVE_EN = ["You're waving! Hello there!", "Hi hi! Over here!", "You look great! I'm happy!"]
GEST_HAND_EN = ["Yes! Over here!", "What is it?", "Me too! I'll raise my hand!"]
PET_LINES_EN = ["Pat pat, that feels nice!", "Yay! Please pet me more!",
                "Hehe, that tickles!", "I love being patted!"]
FAREWELLS_EN = [
    "Don't gooo!",
    "Are you leaving already? I'll miss you...",
    "Please don't go!",
    "Come back soon, okay?",
    "Bye bye! See you again!",
    "Take care out there!",
    "I'll be waiting, see you again!",
    "Aww... please come back soon!",
    "Have a safe trip!",
    "I'll be waiting for you!",
]


def clines(ja, en):
    """現在の対話言語(llm_lang)に応じて定型リストを選ぶ。"""
    return en if settings.get("llm_lang", "ja") == "en" else ja


def ctx(ja, en):
    """event_llm時にLLMへ渡す文脈も言語に合わせる。"""
    return en if settings.get("llm_lang", "ja") == "en" else ja


state = {
    "jpeg": None, "cam_ok": False,
    "dets": [], "kpts": [], "gesture": "", "yolo_ok": False, "raw": None,
    "level": 0.0, "peak_hold": 0.0, "audio_ok": False,
    "partial": "", "finals": [],
    "speech": "", "speech_log": [], "eye_ok": False, "present": False, "speaking": False,
    "spk_ok": True,
}
lock = threading.Lock()

# 自分の声をマイクが拾って自己反応するのを防ぐガード
_speak_until = [0.0]
_last_speech_react = [0.0]
_last_motion_react = [0.0]


def _playback(wav):
    """settings["spk_dev"]の出力先へ再生。
    max98357a: 小型SP最適化。HPF(低域=コーン保護)+圧縮+速リミッタでピークを均し、
    ピークをクリーン天井(peak_ceil_db)×volumeに正規化して「割れずに最大音量」。
    (MAX98357Aはハード音量非搭載/低域を無理に出すとコーン底打ちで歪むため)"""
    dev = settings.get("spk_dev", "duplexaudio")
    play = wav
    if dev == "max98357a":
        vol = max(0.0, min(1.0, float(settings.get("volume", 75)) / 100.0))
        ceil_db = float(settings.get("peak_ceil_db", -6.0))
        src = wav
        if settings.get("dsp", True):
            try:  # 低域カット+圧縮+速リミッタ(冒頭の突発ピークもここで抑える)
                hpf = int(settings.get("hpf", 250))
                af = (f"highpass=f={hpf},"
                      "acompressor=threshold=-28dB:ratio=8:attack=3:release=100,"
                      "alimiter=limit=0.9:level=false:attack=1:release=40")
                dsp = "/tmp/koro_dsp.wav"
                r = subprocess.run(["ffmpeg", "-y", "-i", wav, "-af", af,
                                    "-ar", "48000", "-ac", "2", dsp],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                if r.returncode == 0 and os.path.exists(dsp):
                    src = dsp
            except Exception:  # noqa
                src = wav
        try:  # ピークを天井×volumeへ正規化(クリップ防止+最大クリーン音量)
            import wave as _wave
            import audioop
            wi = _wave.open(src, "rb")
            params = wi.getparams()
            data = wi.readframes(wi.getnframes())
            wi.close()
            pk = audioop.max(data, params.sampwidth) / 32768.0
            target = (10 ** (ceil_db / 20.0)) * vol
            if pk > 0:
                data = audioop.mul(data, params.sampwidth, target / pk)
            play = "/tmp/koro_say_v.wav"
            wo = _wave.open(play, "wb")
            wo.setparams(params)
            wo.writeframes(data)
            wo.close()
        except Exception:  # noqa
            play = src
    subprocess.run(["aplay", "-D", f"plughw:{dev},0", play],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)


def _audio_openable(dev):
    """出力先カードが開けるか判定(0.05秒の無音を再生してPCM openを検証。無音なので聞こえない)。"""
    try:
        r = subprocess.run(["aplay", "-q", "-D", f"plughw:{dev},0",
                            "-f", "S16_LE", "-r", "48000", "-c", "2", "-t", "raw"],
                           input=b"\x00" * 9600,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        return r.returncode == 0
    except Exception:  # noqa
        return False


def ensure_audio_card():
    """MAX98357Aカードが開けるか検証し、開けなければ root修復スクリプト(sudo)で
    snd_soc_simple_card を再バインド(コールドブート時のロード順レースでカードが
    'Invalid argument' で開けなくなる問題の自動対策)。結果を state['spk_ok'] に反映。"""
    dev = settings.get("spk_dev", "max98357a")
    if dev != "max98357a":
        with lock:
            state["spk_ok"] = True
        return True
    ok = _audio_openable(dev)
    if not ok:
        try:
            subprocess.run(["sudo", "-n", "/home/sunrise/corosuke/scripts/fix_max98357a.sh"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        except Exception:  # noqa
            pass
        ok = _audio_openable(dev)
        print("[audio] max98357a ensure ->", "OK" if ok else "NG")
    with lock:
        state["spk_ok"] = ok
    return ok


_EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF"
    "\U00002190-\U000021FF\U00002B00-\U00002BFF\U0001F900-\U0001F9FF"
    "️‍❤⭐✨]+")


def _tts_clean(text):
    """絵文字・記号を除去(TTSが「グリニングフェイス」等と読み上げるのを防ぐ)。
    Web表示用のテキストには手を付けない。"""
    return _EMOJI_RE.sub("", text or "").strip()


def _synthesize(text, wav):
    """textをwavへ合成する。tts_lang=="en"かつespeak-ngがあれば英語音声、
    それ以外(または未インストール)は日本語Open JTalk。戻り値: 成功True。"""
    text = _tts_clean(text)
    if not text:
        return False
    if settings.get("tts_lang", "ja") == "en" and shutil.which("espeak-ng"):
        # 英語(espeak-ng)。コロ助らしい高めの子供っぽいロボ声。
        # 「声の高さ(oj_fm)」「話速(oj_r)」スライダを流用してWebから調整可能に。
        # 既定 fm9/r1.12 → pitch=85(高め) / speed≈145。
        pitch = max(0, min(99, int(40 + float(settings["oj_fm"]) * 5)))
        speed = max(80, min(260, int(130 * float(settings["oj_r"]))))
        voice = settings.get("tts_en_voice", "en-us+f4")   # +f3〜f5で声色変更可
        p = subprocess.run(
            ["espeak-ng", "-v", voice, "-s", str(speed), "-p", str(pitch), "-w", wav, text],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        return p.returncode == 0 and os.path.exists(wav) and os.path.getsize(wav) > 0
    # 日本語(Open JTalk)
    p = subprocess.run(
        [OJ_BIN, "-x", OJ_DIC, "-m", OJ_VOICE,
         "-fm", str(settings["oj_fm"]), "-a", str(settings["oj_a"]),
         "-r", str(settings["oj_r"]), "-ow", wav],
        input=(text + "\n").encode("utf-8"),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    return p.returncode == 0 and os.path.exists(wav) and os.path.getsize(wav) > 0


def speak(text, block=False):
    """テキストを合成(言語はtts_lang)→スピーカー再生。発話中フラグで自己反応を抑止。
    block=True で再生完了まで同期(シャットダウン時など、確実に鳴らしてから次へ進む用)。"""
    def _run():
        try:
            wav = "/tmp/koro_say.wav"
            if not _synthesize(text, wav):
                return
            dur = 3.0
            try:
                import wave
                w = wave.open(wav)
                dur = w.getnframes() / float(w.getframerate())
                w.close()
            except Exception:  # noqa
                pass
            _speak_until[0] = time.time() + dur + 0.8   # 発話中+余韻はSTT反応を無視
            with lock:
                state["speaking"] = True
            _playback(wav)
        except Exception:  # noqa
            pass
        finally:
            with lock:
                state["speaking"] = False
    if block:
        _run()                                   # 同期(再生完了まで待つ)
    else:
        threading.Thread(target=_run, daemon=True).start()


def _is_usb_video(i):
    """videoN が USBカメラ(UVC)ノードか判定。RDK内部のISP/codecノードを避けるため。"""
    try:
        return "usb" in os.path.realpath(
            "/sys/class/video4linux/video%d/device" % i).lower()
    except Exception:  # noqa
        return False


def open_camera():
    """開けてフレームが読める最初の /dev/videoN を開いて返す。
    - USBカメラ(UVC)ノードを優先 → コールドブート時にRDK内部の映像ノードを誤って掴むのを防ぐ
    - 実際にフレームが読めるノードだけ採用(メタデータ/内部ノードはread失敗で自動スキップ)
    - カメラ交換で番号が変わっても(0→1等)追従。
    """
    import glob
    cands = []
    for p in sorted(glob.glob("/dev/video*")):
        try:
            cands.append(int(p[len("/dev/video"):]))
        except ValueError:
            pass
    if not cands:
        cands = [0, 1, 2, 3]
    cands.sort(key=lambda i: (0 if _is_usb_video(i) else 1, i))   # USBカメラ優先
    for i in cands:
        cap = cv2.VideoCapture(i, cv2.CAP_V4L2)
        if cap.isOpened():
            cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            ok, frame = cap.read()
            if ok and frame is not None and getattr(frame, "size", 0) > 0:
                print("[camera] using /dev/video%d (usb=%s)" % (i, _is_usb_video(i)))
                return cap
        cap.release()
    return None


def camera_loop():
    cap = open_camera()
    while cap is None:
        with lock:
            state["cam_ok"] = False
        time.sleep(2)
        cap = open_camera()
    for _ in range(5):
        cap.read()
    while True:
        ok, frame = cap.read()
        if not ok:
            with lock:
                state["cam_ok"] = False
            try:
                cap.release()
            except Exception:  # noqa
                pass
            time.sleep(1)
            cap = open_camera()          # 抜き差し/番号変化に追従して再オープン
            while cap is None:
                time.sleep(2)
                cap = open_camera()
            for _ in range(5):
                cap.read()
            continue
        # 粗いフレーム差分モーション反応は無効化(入退室反応を打ち消す/歩行と手振りを区別不可)。
        # 「しっかりしたジェスチャ」はYOLO11-poseの骨格ベースで別途判定する(gesture_loop)。
        with lock:
            state["raw"] = frame.copy()
            dets = list(state["dets"])
            kpts = list(state["kpts"])
        for label, score, (x1, y1, x2, y2) in dets:
            cv2.rectangle(frame, (x1, y1), (x2, y2), (80, 220, 100), 2)
            cv2.putText(frame, f"{label} {score:.2f}", (x1, max(14, y1 - 6)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (80, 220, 100), 1, cv2.LINE_AA)
        # 骨格(腕のライン + キーポイント点)
        SKELETON = [(5, 7), (7, 9), (6, 8), (8, 10), (5, 6)]   # 肩-肘-手首と肩間
        for a, b in SKELETON:
            if a < len(kpts) and b < len(kpts) and kpts[a][2] > 0.4 and kpts[b][2] > 0.4:
                cv2.line(frame, kpts[a][:2], kpts[b][:2], (255, 200, 60), 2)
        for x, yv, sc in kpts:
            if sc > 0.4:
                cv2.circle(frame, (x, yv), 4, (60, 160, 255), -1)
        ok2, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if ok2:
            with lock:
                state["jpeg"] = buf.tobytes()
                state["cam_ok"] = True
        time.sleep(0.03)


def react_to_motion(motion):
    """人が居る状態で大きな動き(手振り等)を検知したら反応。過剰反応を強く抑制。"""
    now = time.time()
    if motion < 12.0:                         # 閾値: 小さな揺れは無視(要調整)
        return
    if not _greet["present"]:                 # 人が居るときだけ(新規出現は挨拶側が担当)
        return
    if now - _last_motion_react[0] < 6.0:     # 6秒に1回まで
        return
    if now < _speak_until[0]:                  # 発話中は無視
        return
    _last_motion_react[0] = now
    ml = clines(MOTION_LINES, MOTION_LINES_EN)
    line = ml[int(now) % len(ml)]
    react("surprised", line, blink=True)


# ============ 目(ESP32-S3)制御 ============
class Eyes:
    def __init__(self):
        self._ser = None

    def _ensure(self):
        if self._ser or serial is None:
            return
        ports = sorted(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*"))  # 番号自動検出
        if not ports:
            return
        try:
            self._ser = serial.Serial(ports[0], 115200, timeout=0.3)
            time.sleep(0.3)
            with lock:
                state["eye_ok"] = True
        except Exception:  # noqa
            self._ser = None

    def send(self, line):
        self._ensure()
        if not self._ser:
            return
        try:
            self._ser.write((line + "\n").encode("ascii", "ignore"))
        except Exception:  # noqa
            try:
                self._ser.close()
            finally:
                self._ser = None
                with lock:
                    state["eye_ok"] = False


eyes = Eyes()
_greet = {"present": False, "absent": 0, "idx": 0, "fidx": 0, "last_gaze": 0.0}

# 腕サーボ(ESP32 GPIO4=左/5=右, "arm l/r <角度>")。ロープ引き=角度大で腕が上がる想定。
ARM_REST, ARM_UP, ARM_DROOP = 90, 160, 60


def arm_gesture(kind):
    """腕をロープ引きで動かす(非ブロッキング)。use_arm=Offなら動かさない(調整中用)。"""
    if not settings["use_arm"]:
        return

    def _run():
        if kind == "wave":                       # 手を振る(挨拶)=両腕を振る
            for _ in range(3):
                eyes.send(f"arm l {ARM_UP}"); eyes.send(f"arm r {ARM_UP}"); time.sleep(0.30)
                eyes.send(f"arm l {ARM_UP - 45}"); eyes.send(f"arm r {ARM_UP - 45}"); time.sleep(0.30)
            eyes.send(f"arm l {ARM_REST}"); eyes.send(f"arm r {ARM_REST}")
        elif kind in ("wave_l", "wave_r"):       # 片手で振り返す
            s = kind[-1]
            for _ in range(3):
                eyes.send(f"arm {s} {ARM_UP}"); time.sleep(0.30)
                eyes.send(f"arm {s} {ARM_UP - 45}"); time.sleep(0.30)
            eyes.send(f"arm {s} {ARM_REST}")
        elif kind == "raise":                    # 両手バンザイ→戻す
            eyes.send(f"arm l {ARM_UP}"); eyes.send(f"arm r {ARM_UP}")
            time.sleep(1.6)
            eyes.send(f"arm l {ARM_REST}"); eyes.send(f"arm r {ARM_REST}")
        elif kind in ("up_l", "up_r"):           # 片手だけ上げる→戻す
            s = kind[-1]
            eyes.send(f"arm {s} {ARM_UP}")
            time.sleep(1.6)
            eyes.send(f"arm {s} {ARM_REST}")
        elif kind == "droop":                    # 退室でしょんぼり下げ
            eyes.send(f"arm l {ARM_DROOP}"); eyes.send(f"arm r {ARM_DROOP}")
            time.sleep(2.0)
            eyes.send(f"arm l {ARM_REST}"); eyes.send(f"arm r {ARM_REST}")
    threading.Thread(target=_run, daemon=True).start()


def react(emotion, text, gaze=None, blink=True):
    """反応の共通処理: 目(表情+視線+まばたき)+ セリフ発声 + Web表示。"""
    eyes.send(f"emo {emotion}")
    if gaze is not None:
        eyes.send(f"gaze {gaze:.2f} 0")
    if blink:
        eyes.send("blink")
    if text:
        speak(text)
        with lock:
            state["speech"] = text
            state["speech_log"] = ([time.strftime("%H:%M:%S ") + text] + state["speech_log"])[:8]


def _event_llm_speak(context):
    """イベント文脈からLLMで台詞生成して発話(非同期)。目/腕は呼出側で即反応済み。"""
    if not _llm["ready"] or _llm["busy"]:
        return
    _llm["busy"] = True
    _speak_until[0] = time.time() + 30
    try:
        en = settings["llm_lang"] == "en"
        persona = LLM_PERSONA_EN if en else LLM_PERSONA
        fewshot = LLM_FEWSHOT_EN if en else LLM_FEWSHOT
        r = _llm["model"].create_chat_completion(
            messages=[{"role": "system", "content": persona}] + fewshot
                     + [{"role": "user", "content": context}],
            max_tokens=48, temperature=0.85, top_p=0.9)
        reply = r["choices"][0]["message"]["content"].strip()
        if reply:
            speak(reply)
            with lock:
                state["speech"] = reply
                state["speech_log"] = ([time.strftime("%H:%M:%S ") + reply] + state["speech_log"])[:8]
    except Exception as e:  # noqa
        print("[llm-event]", e)
    finally:
        _llm["busy"] = False


def event_speech(context, canned, emotion="happy", gaze=None, arm=None):
    """入退室/ジェスチャの反応。目+腕は即時、台詞はrule(定型)かllm(生成)を設定で選択。"""
    eyes.send(f"emo {emotion}")
    if gaze is not None:
        eyes.send(f"gaze {gaze:.2f} 0")
    eyes.send("blink")
    if arm:
        arm_gesture(arm)
    if settings["event_llm"] and _llm["ready"] and not _llm["busy"]:
        threading.Thread(target=_event_llm_speak, args=(context,), daemon=True).start()
    else:
        msg = canned[int(time.time() * 7) % len(canned)]
        speak(msg)
        with lock:
            state["speech"] = msg
            state["speech_log"] = ([time.strftime("%H:%M:%S ") + msg] + state["speech_log"])[:8]


def _settle_neutral():
    """別れの後、待機中は sad(眠そう/悲しげ)のまま放置せず、数秒後に穏やかな neutral に戻す。
    (退室→戻ってきても眠そうに見える問題の対策)"""
    time.sleep(5)
    if not _greet["present"]:
        eyes.send("emo neutral")
        eyes.send("gaze 0 0")


def greet_update(person_box, frame_w):
    """人の出現/追従に応じ目を動かし、新規出現時に1回だけ挨拶。"""
    if person_box is not None:
        x1, _, x2, _ = person_box
        gaze_x = max(-1.0, min(1.0, (x1 + x2) / 2.0 / frame_w * 2.0 - 1.0))
        _greet["absent"] = 0
        if not _greet["present"]:
            _greet["present"] = True
            with lock:
                state["present"] = True
            if settings["react_greet"]:
                event_speech(ctx("目の前に人が来た。元気よく短く挨拶して。",
                                 "A person appeared in front of you. Greet them cheerfully and briefly in English."),
                             clines(GREETINGS, GREETINGS_EN), "happy", gaze_x, "wave")
            else:
                eyes.send("emo happy")
                eyes.send(f"gaze {gaze_x:.2f} 0")
        elif abs(gaze_x - _greet["last_gaze"]) > 0.15:
            eyes.send(f"gaze {gaze_x:.2f} 0")
            _greet["last_gaze"] = gaze_x
    else:
        _greet["absent"] += 1
        if _greet["present"] and _greet["absent"] >= 15:
            _greet["present"] = False
            with lock:
                state["present"] = False
            if settings["react_greet"]:
                event_speech(ctx("目の前にいた人が去っていく。名残惜しそうに短く一言。",
                                 "The person in front of you is leaving. Say a short wistful goodbye in English."),
                             clines(FAREWELLS, FAREWELLS_EN), "sad", 0.0, "droop")
                threading.Thread(target=_settle_neutral, daemon=True).start()  # 待機はneutralへ
            else:
                eyes.send("emo neutral")
                eyes.send("gaze 0 0")


_gesture = {"last": 0.0, "hist": {"l": [], "r": []}}


def detect_gesture(kxy, ksc, w):
    """COCO17骨格から「両手/片手あげ・片手振り」を判定して反応。手を目で追う。
    人の左手首=kpt9→コロ助の左腕(l)、右手首=kpt10→右腕(r)に対応。"""
    now = time.time()
    kt = float(settings["kpt_thres"])

    def ok(i):
        return ksc[i] > kt
    left_up = ok(9) and ok(5) and kxy[9][1] < kxy[5][1]      # 左手首が左肩より上
    right_up = ok(10) and ok(6) and kxy[10][1] < kxy[6][1]   # 右手首が右肩より上
    for side, wrist, up in (("l", 9, left_up), ("r", 10, right_up)):
        h = _gesture["hist"][side]
        h.append((now, float(kxy[wrist][0]))) if up else h.clear()
        _gesture["hist"][side] = [(t, x) for (t, x) in h if now - t < 1.2]

    def waving(side):
        xs = [x for (_, x) in _gesture["hist"][side]]
        return len(xs) >= 4 and (max(xs) - min(xs)) > w * 0.06

    with lock:
        state["gesture"] = ("両手あげ" if left_up and right_up
                            else "片手あげ" if left_up or right_up else "")
    if not (left_up or right_up):
        return
    if now - _gesture["last"] < float(settings["gesture_cd"]) or now < _speak_until[0] \
            or not _greet["present"] or not settings["react_greet"]:
        return   # ← 「入退室で挨拶(react_greet)」OFFならジェスチャ反応もしない
    _gesture["last"] = now

    def gaze_of(side):
        return max(-1.0, min(1.0, kxy[9 if side == "l" else 10][0] / w * 2.0 - 1.0))
    if left_up and right_up:                                  # 両手あげ → バンザイ
        event_speech(ctx("相手が両手を上げてバンザイした。一緒に喜んで短く。",
                         "They raised both hands for banzai. Cheer with them briefly in English."),
                     clines(GEST_BANZAI, GEST_BANZAI_EN), "happy", None, "raise")
    elif waving("l") or waving("r"):                          # 片手振り → 同じ手で振り返す
        s = "l" if waving("l") else "r"
        event_speech(ctx("相手が片手で手を振っている。振り返して短く挨拶。",
                         "They are waving one hand. Wave back with a short greeting in English."),
                     clines(GEST_WAVE, GEST_WAVE_EN), "happy", gaze_of(s), "wave_" + s)
    else:                                                     # 片手あげ → 同じ手を上げる
        s = "l" if left_up else "r"
        event_speech(ctx("相手が片手を上げた。元気よく短く応える。",
                         "They raised one hand. Respond cheerfully and briefly in English."),
                     clines(GEST_HAND, GEST_HAND_EN), "happy", gaze_of(s), "up_" + s)


def yolo_loop():
    try:
        import importlib.util
        import sys
        from types import SimpleNamespace
        sys.path.append("/app/pydev_demo")
        spec = importlib.util.spec_from_file_location(
            "up", os.path.join(POSE_DIR, "ultralytics_yolo11_pose.py"))
        up = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(up)
        opt = SimpleNamespace(model_path=POSE_MODEL, score_thres=0.40)
        y = up.YoloV11_Pose(opt)
        y.set_scheduling_params(priority=0, bpu_cores=[0])
    except Exception as e:  # noqa
        print("[pose] 無効化:", e)
        return
    with lock:
        state["yolo_ok"] = True
    while True:
        with lock:
            frame = state["raw"]
        if frame is None:
            time.sleep(0.1)
            continue
        try:
            ps = float(settings["pose_score"])   # 人物検出しきい値をWebから即反映
            if abs(y.score_thres - ps) > 1e-6:
                y.score_thres = ps
                y.conf_thres_raw = -math.log(1.0 / ps - 1.0)
            h, w = frame.shape[:2]
            out = y.forward(y.pre_process(frame))
            ids, scores, boxes, kpts_xy, kpts_score = y.post_process(out, h, w)
            # 一番大きい人物「一人だけ」を対象にする(複数人は無視)
            best_i, best_area = -1, 0
            for i, b in enumerate(boxes):
                a = (b[2] - b[0]) * (b[3] - b[1])
                if a > best_area:
                    best_area, best_i = a, i
            if best_i >= 0:
                best_box = [int(v) for v in boxes[best_i]]
                dets = [("person", float(scores[best_i]), best_box)]
                kpts_draw = [(int(x), int(yv), float(sc))
                             for (x, yv), sc in zip(kpts_xy[best_i], kpts_score[best_i])]
            else:
                best_box, dets, kpts_draw = None, [], []
            with lock:
                state["dets"] = dets
                state["kpts"] = kpts_draw
            greet_update(best_box, w)
            if best_i >= 0:
                detect_gesture(kpts_xy[best_i], kpts_score[best_i], w)
        except Exception as e:  # noqa
            print("[pose]", e)
        time.sleep(0.2)


# ==== ローカルLLM(TinySwallow-1.5B, 完全オンデバイス対話) ====
LLM_MODEL = "/home/sunrise/models/llm/tinyswallow-q5.gguf"
LLM_PERSONA = ("あなたは「コロ助」。キテレツ大百科のからくりロボット。"
               "【厳守ルール】1)一人称は必ず「ワガハイ」。2)全ての文の語尾に必ず「ナリ」を付ける(例外なし)。"
               "3)明るく元気で少しおっちょこちょい。4)コロッケが大好物。"
               "5)難しい話はせず1〜2文で短く答える。標準語やですます調は禁止、必ずナリ口調にする。")
# few-shotで「ナリ」口調を強制(小型モデル対策)
LLM_FEWSHOT = [
    {"role": "user", "content": "こんにちは"},
    {"role": "assistant", "content": "やあ！ワガハイはコロ助ナリ！元気ナリか？"},
    {"role": "user", "content": "名前を教えて"},
    {"role": "assistant", "content": "ワガハイはコロ助ナリ！よろしくナリ！"},
]
# 英語モード(settings["llm_lang"]=="en")。モデルは同じTinySwallowのまま英語で応答させる。
LLM_PERSONA_EN = (
    "You are Korosuke, a cheerful and slightly clumsy little clockwork robot from the "
    "anime Kiteretsu Daihyakka. Your name is ALWAYS Korosuke and you have no other name. "
    "You are NOT an AI, NOT a language model, and NOT an assistant named Alba or anything "
    "else -- you are only ever Korosuke, and you never break character. "
    "RULES: 1) Always call yourself 'I' and your name is Korosuke. "
    "2) Speak in simple, upbeat English, only 1-2 short sentences. "
    "3) You love croquettes. 4) Be friendly and childlike. "
    "Never say you are an assistant. Never use Japanese; always answer in English.")
LLM_FEWSHOT_EN = [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi there! I am Korosuke! Nice to meet you!"},
    {"role": "user", "content": "What is your name?"},
    {"role": "assistant", "content": "My name is Korosuke! Just Korosuke, a little clockwork robot!"},
    {"role": "user", "content": "Are you an AI assistant?"},
    {"role": "assistant", "content": "No no! I am not an assistant! I am Korosuke, a clockwork robot!"},
    {"role": "user", "content": "Is your name Alba?"},
    {"role": "assistant", "content": "Hehe, no! My name is Korosuke! Nice to meet you!"},
    {"role": "user", "content": "Do you like croquettes?"},
    {"role": "assistant", "content": "Yes! I love croquettes so much! They are my favorite food!"},
    {"role": "user", "content": "こんにちは"},
    {"role": "assistant", "content": "Hello! I am Korosuke! Let's talk in English!"},
]
_llm = {"model": None, "ready": False, "busy": False}


def load_llm():
    try:
        from llama_cpp import Llama
        m = Llama(model_path=LLM_MODEL, n_ctx=1024, n_threads=6, verbose=False)
        with lock:
            _llm["model"] = m
            _llm["ready"] = True
        print("[llm] TinySwallow ready")
    except Exception as e:  # noqa
        print("[llm] load失敗(キーワード応答のみで継続):", e)


def llm_respond(text):
    if not _llm["ready"] or _llm["busy"]:
        return
    _llm["busy"] = True
    _speak_until[0] = time.time() + 30       # 思考中はSTT自己反応を抑止
    with lock:
        state["speech"] = "Thinking..." if settings["llm_lang"] == "en" else "考え中ナリ…"
    try:
        eyes.send("emo thinking")             # 考え中の目(瞳がくるくる回る)
    except Exception:  # noqa
        pass
    try:
        en = settings["llm_lang"] == "en"
        persona = LLM_PERSONA_EN if en else LLM_PERSONA
        fewshot = LLM_FEWSHOT_EN if en else LLM_FEWSHOT
        r = _llm["model"].create_chat_completion(
            messages=[{"role": "system", "content": persona}]
                     + fewshot
                     + [{"role": "user", "content": text}],
            max_tokens=64, temperature=(0.5 if en else 0.7), top_p=0.9)
        reply = r["choices"][0]["message"]["content"].strip()
        if reply:
            react("happy", reply, blink=True)     # 目+発声+Web表示
        else:
            eyes.send("emo neutral")
    except Exception as e:  # noqa
        print("[llm] 生成エラー:", e)
        try:
            eyes.send("emo neutral")              # 失敗時は考え中の目を戻す
        except Exception:  # noqa
            pass
    finally:
        _llm["busy"] = False


def react_to_speech(text):
    """認識テキストにキーワードが含まれたら定型反応。無ければLLMで返答。"""
    if not settings["react_speech"]:
        return
    now = time.time()
    if now < _speak_until[0]:                  # 自分の声を拾った分は無視
        return
    if now - _last_speech_react[0] < 2.0:
        return
    for keys, emo, reply in clines(SPEECH_REACTIONS, SPEECH_REACTIONS_EN):
        if any(k in text.lower() for k in keys):
            _last_speech_react[0] = now
            react(emo, reply, blink=True)
            return
    # キーワードに無い発話 → ローカルLLMで返答(短すぎ/ノイズは除外)
    if settings["use_llm"] and _llm["ready"] and len(text.strip()) >= 4:
        _last_speech_react[0] = now
        threading.Thread(target=llm_respond, args=(text,), daemon=True).start()
        return


# STT言語→モデルディレクトリ(先勝ち)。en用の英語Zipformerが無ければ日本語へフォールバック。
STT_MODEL_GLOBS = {
    "ja": ["/home/sunrise/models/sherpa-onnx-zipformer-ja-reazonspeech*"],
    "en": ["/home/sunrise/models/sherpa-onnx-*en*"],   # 例: sherpa-onnx-zipformer-en-2023-06-26
}


def _stt_model_dir(lang):
    """指定言語のsherpa transducerモデルdir(tokens.txtを持つ)を返す。無ければNone。"""
    for pat in STT_MODEL_GLOBS.get(lang, []):
        for d in sorted(glob.glob(pat)):
            if os.path.isdir(d) and os.path.exists(d + "/tokens.txt"):
                return d
    return None


def audio_loop():
    try:
        import sherpa_onnx
        # VAD は言語非依存(silero)。一度だけ構築する。
        vcfg = sherpa_onnx.VadModelConfig()
        vcfg.silero_vad.model = "/home/sunrise/models/silero_vad.onnx"
        vcfg.silero_vad.threshold = 0.6            # 高め=雑音/弱い音を無視
        vcfg.silero_vad.min_silence_duration = 0.7  # 細切れ抑制
        vcfg.silero_vad.min_speech_duration = 0.3   # 短い誤検出を除外
        vcfg.sample_rate = 16000
        vad = sherpa_onnx.VoiceActivityDetector(vcfg, buffer_size_in_seconds=30)
        win = vcfg.silero_vad.window_size
    except Exception as e:  # noqa
        print("[audio] sherpa/VAD初期化失敗:", e)
        return

    # req=要求言語(切替検知の基準) / lang=実際にロードした言語(フォールバックで異なりうる)
    rec = {"obj": None, "lang": None, "req": None}

    def load_rec():
        """settings["stt_lang"]に合わせて認識器を(再)ロード。無い言語は日本語へフォールバック。
        戻り値: 実際にロードした言語 or None(モデル皆無/失敗)。"""
        req = settings.get("stt_lang", "ja")     # 要求された言語
        actual = req
        d = _stt_model_dir(actual)
        if d is None and actual != "ja":
            print(f"[audio] {actual} のSTTモデルが無い→日本語にフォールバック")
            actual = "ja"
            d = _stt_model_dir("ja")
        if d is None:
            print("[audio] STTモデルが見つからない(ja/en とも無し)")
            return None
        try:
            rec["obj"] = sherpa_onnx.OfflineRecognizer.from_transducer(
                encoder=sorted(glob.glob(d + "/encoder*int8.onnx"))[0],
                decoder=sorted(glob.glob(d + "/decoder*[!8].onnx"))[0],
                joiner=sorted(glob.glob(d + "/joiner*int8.onnx"))[0],
                tokens=d + "/tokens.txt", num_threads=6)   # YOLOはBPU中心なのでCPUを多めに
            # req は要求どおり記録(フォールバックでも「要求は処理済み」として無限再ロードを防ぐ)
            rec["req"] = req
            rec["lang"] = actual
            with lock:
                state["stt_lang_active"] = actual
            print(f"[audio] STTモデル ロード: req={req} actual={actual} ({os.path.basename(d)})")
            return actual
        except Exception as e:  # noqa
            print("[audio] STTモデル ロード失敗:", e)
            return None

    def decode(samples):
        st = rec["obj"].create_stream()
        st.accept_waveform(16000, samples)
        rec["obj"].decode_stream(st)
        return st.result.text.strip()

    CHUNK = 4800 * 2 * 2
    pending = []
    ratecv_state = None
    while True:
        # 言語設定に合う認識器が無ければ(再)ロード。ロードできなければ待って再試行。
        if rec["obj"] is None or rec["req"] != settings.get("stt_lang", "ja"):
            if load_rec() is None:
                time.sleep(3)
                continue
            pending.clear()
            while not vad.empty():
                vad.pop()
        p = subprocess.Popen(
            ["arecord", "-D", f"plughw:{mic_card()},0", "-f", "S16_LE",
             "-r", "48000", "-c", "2", "-t", "raw"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            while True:
                data = p.stdout.read(CHUNK)
                if not data:
                    raise IOError("stream ended")
                # 言語切替を検知。実際に使うモデルが変わる時だけ再ロード
                # (英語モデル未導入でja→ja据え置きなら、reqだけ更新して録音は継続=無音を作らない)
                want = settings.get("stt_lang", "ja")
                if want != rec["req"]:
                    new_actual = want if _stt_model_dir(want) else "ja"
                    if new_actual != rec["lang"]:
                        raise IOError("lang switch")   # モデルが変わる→再ロード
                    rec["req"] = want                  # 同じモデル→reqだけ更新し継続
                    with lock:
                        state["stt_lang_active"] = rec["lang"]
                # 自分の発話中は認識しない(スピーカー→マイクの自己エコーを排除)
                if time.time() < _speak_until[0]:
                    pending.clear()
                    while not vad.empty():
                        vad.pop()
                    with lock:
                        state["partial"] = ""
                    continue
                mono = audioop.tomono(data, 2, 0.5, 0.5)
                g = float(settings["mic_gain"])
                if g != 1.0:
                    mono = audioop.mul(mono, 2, g)   # ソフト増幅(クリップ付き)
                s = struct.unpack("<%dh" % (len(mono) // 2), mono)
                rms = math.sqrt(sum(x * x for x in s) / len(s))
                level = min(100.0, rms / 327.67)
                conv, ratecv_state = audioop.ratecv(mono, 2, 1, 48000, 16000, ratecv_state)
                s16 = struct.unpack("<%dh" % (len(conv) // 2), conv)
                pending.extend(x / 32768.0 for x in s16)
                while len(pending) >= win:
                    vad.accept_waveform(pending[:win])
                    del pending[:win]
                talking = vad.is_speech_detected()
                while not vad.empty():
                    t = decode(vad.front.samples)
                    if t:
                        with lock:
                            state["finals"] = ([time.strftime("%H:%M:%S ") + t]
                                               + state["finals"])[:10]
                        react_to_speech(t)         # ← キーワード反応
                    vad.pop()
                with lock:
                    state["audio_ok"] = True
                    state["level"] = round(level, 1)
                    state["peak_hold"] = max(state["peak_hold"] * 0.97, level)
                    state["partial"] = "（聞いてるナリ…）" if talking else ""
        except IOError:
            with lock:
                state["audio_ok"] = False
            p.kill()
            time.sleep(2)


PAGE = """<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>コロ助モニタ</title><style>
:root{--bg:#141428;--card:#1c2748;--panel:#0f3460;--acc:#4ecca3;--acc2:#ffb347;--ok:#4ecca3;--ng:#ff5c7a;--txt:#eaeaf2;--mut:#9fb3c8}
*{box-sizing:border-box}
body{font-family:system-ui,"Segoe UI",sans-serif;background:var(--bg);color:var(--txt);margin:0;padding:0}
header{position:sticky;top:0;z-index:9;background:#141428ee;backdrop-filter:blur(6px);
  padding:10px 18px;border-bottom:1px solid #ffffff14}
h1{font-size:1.15rem;margin:0;display:flex;align-items:center;gap:8px}
h1 small{font-size:.7rem;color:var(--ng);font-weight:400}
.tabs{display:flex;gap:8px;margin:10px 0 8px}
.tab{padding:7px 20px;border-radius:22px;border:1px solid #ffffff22;background:transparent;
  color:var(--mut);cursor:pointer;font-size:.95rem;transition:.15s}
.tab.active{background:var(--acc);color:#06231b;border-color:var(--acc);font-weight:700}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chip{background:var(--card);border-radius:16px;padding:4px 12px;font-size:.82rem;border:1px solid #ffffff12}
.view{padding:18px;max-width:1180px;margin:0 auto}
.grid{display:flex;flex-wrap:wrap;gap:16px}
.card,.grp{background:var(--card);border-radius:14px;padding:15px;flex:1;min-width:320px}
.card h2,.grp h2{font-size:.95rem;margin:0 0 10px;color:var(--acc2)}
.grp{margin-bottom:16px}
.full{flex-basis:100%}
img{width:100%;border-radius:10px;background:#000;display:block}
.speechcard{margin-bottom:16px}
#speech{background:var(--panel);border-radius:12px;padding:20px;font-size:1.5rem;color:#ffe08a;
  min-height:1.6em;transition:background .2s;line-height:1.4}
#speech.talk{background:#3a5a1c}
#speechlog{margin-top:10px;font-size:.85rem;color:var(--mut)}
#speechlog div{padding:2px 0;border-bottom:1px solid #ffffff0d}
.meterbox{background:var(--panel);border-radius:7px;height:26px;position:relative;overflow:hidden}
#meter{background:linear-gradient(90deg,#4ecca3,#ffd460 70%,#ff2e63 90%);height:100%;width:0%;transition:width .1s}
#peak{position:absolute;top:0;width:2px;height:100%;background:#fff}
#lv{font-variant-numeric:tabular-nums}
#partial{color:var(--acc);min-height:1.4em;font-size:1.1rem}
#dets{color:#8fd;font-size:.85rem;min-height:1.2em;margin-top:8px}
#finals{max-height:240px;overflow:auto}
#finals div{border-bottom:1px solid var(--panel);padding:3px 0;font-size:.9rem}
.ok{color:var(--ok)}.ng{color:var(--ng)}
.ctl{margin:11px 0;font-size:.95rem;display:flex;align-items:center;flex-wrap:wrap;gap:8px}
.ctl>span.lab{min-width:8.5em}
.ctl input[type=range]{vertical-align:middle;width:170px;accent-color:var(--acc)}
.ctl button{padding:6px 13px;border-radius:9px;border:1px solid var(--acc);background:transparent;color:var(--txt);cursor:pointer}
.ctl button:hover{background:var(--panel)}
.ctl label{display:inline-flex;align-items:center;gap:5px;margin:0 4px}
.ctl input[type=text]{background:var(--panel);border:1px solid var(--acc);color:var(--txt);border-radius:7px;padding:5px 8px}
.ctl select{background:var(--panel);border:1px solid var(--acc);color:var(--txt);border-radius:7px;padding:5px}
small{color:var(--mut);font-size:.78rem}
</style></head><body>
<header>
  <h1>🤖 コロ助 <small id="st"></small></h1>
  <div class="tabs">
    <button class="tab active" id="tab-monitor" onclick="tab(this,'monitor')">📺 モニタ</button>
    <button class="tab" id="tab-settings" onclick="tab(this,'settings')">⚙ 設定</button>
    <button class="tab" id="langbtn" onclick="toggleLang()" style="margin-left:auto"
      title="全部まとめて切替: 表示 + 音声認識 + 対話 + 音声 / Switch everything (display + STT + LLM + TTS)">🌐 EN</button>
  </div>
  <div class="chips">
    <span class="chip">👁 目 <span id="eyest">…</span></span>
    <span class="chip">📷 カメラ <span id="camst">…</span></span>
    <span class="chip">🎙 マイク <span id="micst">…</span></span>
    <span class="chip">🔈 音声 <span id="spkst">…</span></span>
    <span class="chip">🤖 LLM <span id="llmst2">…</span></span>
  </div>
</header>

<section id="view-monitor" class="view">
  <div class="card full speechcard"><h2>🗣 コロ助のセリフ</h2>
    <div id="speech">…</div><div id="speechlog"></div></div>
  <div class="card full"><h2>💬 チャット / Chat</h2>
    <div style="display:flex;gap:8px">
      <input type="text" id="c_chat" placeholder="コロ助に話しかける / talk to Korosuke" style="flex:1"
             onkeydown="if(event.key==='Enter')chat()">
      <button onclick="chat()">送信 / Send</button></div>
    <div><small>入力するとローカルLLMが返答(5〜10秒)→上の吹き出し＆発声</small></div></div>
  <div class="grid">
    <div class="card"><h2>👁 カメラ + 人物/姿勢検知</h2>
      <img id="cam" src="/stream" alt="camera"><div id="dets"></div>
      <div style="margin-top:6px"><small>認識: <b id="reco">—</b></small></div></div>
    <div class="card"><h2>🎙 マイク / 💬 音声認識 (sherpa-onnx)</h2>
      <div class="meterbox"><div id="meter"></div><div id="peak"></div></div>
      <p style="margin:6px 0"><small>レベル: <span id="lv">0</span> %FS</small></p>
      <p id="partial"></p><div id="finals"></div></div>
  </div>
</section>

<section id="view-settings" class="view" hidden>
  <div class="grp"><h2>🔊 音声</h2>
    <div class="ctl"><span class="lab">🔈 出力先</span>
      <select id="c_spk" onchange="set('spk_dev',this.value)">
        <option value="max98357a" selected>MAX98357A(I2Sアンプ40pin・φ50)</option>
        <option value="duplexaudio">ES8326(旧・大型SP)</option></select></div>
    <div class="ctl"><span class="lab">🔊 音量</span>
      <input type="range" min="0" max="100" value="75" id="c_vol"
       oninput="lbl('l_vol',this.value);set('volume',this.value)"><span id="l_vol">75</span>%</div>
    <div class="ctl"><span class="lab">🎛 小型SP最適化</span>
      <label><input type="checkbox" id="c_dsp" checked onchange="set('dsp',this.checked?1:0)"> HPF+圧縮+リミッタ</label>
      クリーン上限<input type="range" min="-12" max="0" step="0.5" value="-6" id="c_ceil"
       oninput="lbl('l_ceil',this.value);set('peak_ceil_db',this.value)"><span id="l_ceil">-6</span>dB</div>
    <div class="ctl"><small>（φ50=0.2Wは-6運用。高耐入力SP/箱固定なら上げて大音量化）</small></div>
    <div class="ctl"><span class="lab">🎙 マイク感度</span>
      <input type="range" min="1" max="8" step="0.5" value="3" id="c_mic"
       oninput="lbl('l_mic',this.value);set('mic_gain',this.value)"><span id="l_mic">3</span>x</div>
    <div class="ctl"><span class="lab">🎵 声の高さ</span>
      <input type="range" min="0" max="15" value="9" id="c_fm"
       oninput="lbl('l_fm',this.value);set('oj_fm',this.value)"><span id="l_fm">9</span></div>
    <div class="ctl"><span class="lab">⏩ 話速</span>
      <input type="range" min="0.7" max="1.5" step="0.05" value="1.12" id="c_r"
       oninput="lbl('l_r',this.value);set('oj_r',this.value)"><span id="l_r">1.12</span></div>
    <div class="ctl"><span class="lab">🗣 テスト発声</span>
      <input type="text" id="c_say" value="ワガハイはコロ助ナリ！" size="22">
      <button onclick="say()">喋る</button></div>
    <div class="ctl"><span class="lab">🔈 音声チェック</span>
      <button onclick="audiocheck()">カード検証＋テスト発声</button>
      <small>(開けなければ自動で再バインド。「音声チェックOKナリ」が聞こえれば正常)</small></div>
    <div class="ctl"><span class="lab">🤖 LLM対話テスト</span>
      <input type="text" id="c_llmq" value="今日の調子はどう？" size="18">
      <button onclick="llmsay()">LLMに聞く</button> <small>(応答5〜10秒→上の吹き出し)</small></div>
  </div>

  <div class="grp"><h2>🔁 反応と会話</h2>
    <div class="ctl">
      <label><input type="checkbox" id="c_g" checked onchange="set('react_greet',this.checked?1:0)"> 入退室で挨拶</label>
      <label><input type="checkbox" id="c_s" checked onchange="set('react_speech',this.checked?1:0)"> 話しかけに反応</label>
      <label><input type="checkbox" id="c_llm" checked onchange="set('use_llm',this.checked?1:0)"> LLM会話 <span id="llmst"></span></label></div>
    <div class="ctl">
      <label><input type="checkbox" id="c_arm" checked onchange="set('use_arm',this.checked?1:0)"> 腕を自動で動かす(調整中はOFF)</label>
      <label><input type="checkbox" id="c_ev" onchange="set('event_llm',this.checked?1:0)"> 入退室/ジェスチャ台詞をLLM生成(OFF=定型・即時)</label></div>
  </div>

  <div class="grp"><h2>🌐 言語 / Language</h2>
    <div class="ctl"><span class="lab">🌐 一括 / All</span>
      <button onclick="setAllLang('ja')">日本語</button>
      <button onclick="setAllLang('en')">English</button>
      <small>STT・LLM・TTS・表示をまとめて切替</small></div>
    <div class="ctl"><span class="lab">🖥 表示言語 / Display</span>
      <select id="c_uilang" onchange="setUiLang(this.value)">
        <option value="ja" selected>日本語</option>
        <option value="en">English</option></select>
      <small>Web画面の表示だけ切替(発話は変えない)</small></div>
    <div class="ctl"><span class="lab">💬 音声認識 STT</span>
      <select id="c_sttlang" onchange="set('stt_lang',this.value)">
        <option value="ja" selected>日本語 (ReazonSpeech)</option>
        <option value="en">English</option></select>
      <small id="sttlangnote"></small></div>
    <div class="ctl"><span class="lab">🤖 LLM応答</span>
      <select id="c_llmlang" onchange="set('llm_lang',this.value)">
        <option value="ja" selected>日本語（ナリ口調）</option>
        <option value="en">English</option></select></div>
    <div class="ctl"><span class="lab">🔊 音声合成 TTS</span>
      <select id="c_ttslang" onchange="set('tts_lang',this.value)">
        <option value="ja" selected>日本語 (Open JTalk)</option>
        <option value="en">English (espeak-ng)</option></select></div>
    <div class="ctl"><small>英語STTは英語sherpaモデル、英語TTSは espeak-ng が必要。未導入時は自動で日本語にフォールバックします。</small></div>
  </div>

  <div class="grp"><h2>🔍 認識しきい値</h2>
    <div class="ctl"><span class="lab">👤 人物検出</span>
      <input type="range" min="0.1" max="0.9" step="0.05" value="0.40" id="c_ps"
       oninput="lbl('l_ps',this.value);set('pose_score',this.value)"><span id="l_ps">0.40</span></div>
    <div class="ctl"><span class="lab">🦴 骨格</span>
      <input type="range" min="0.1" max="0.9" step="0.05" value="0.40" id="c_kt"
       oninput="lbl('l_kt',this.value);set('kpt_thres',this.value)"><span id="l_kt">0.40</span></div>
    <div class="ctl"><span class="lab">⏱ ジェスチャ間隔</span>
      <input type="range" min="1" max="15" step="1" value="5" id="c_gcd"
       oninput="lbl('l_gcd',this.value);set('gesture_cd',this.value)"><span id="l_gcd">5</span>秒</div>
  </div>

  <div class="grp"><h2>💪 腕サーボ</h2>
    <div class="ctl"><span class="lab">両方</span>
      <button onclick="armdo('wave')">👋手を振る</button>
      <button onclick="armdo('raise')">🙌バンザイ</button>
      <button onclick="armdo('droop')">😔下げる</button>
      <button onclick="fetch('/arm?off=both')">🪫脱力(PWM OFF)</button></div>
    <div class="ctl"><span class="lab">🫲 左腕のみ</span>
      <button onclick="fetch('/arm?l=160')">上げ</button>
      <button onclick="fetch('/arm?l=90')">中立</button>
      <button onclick="fetch('/arm?l=60')">下げ</button>
      <button onclick="fetch('/arm?off=l')">🪫脱力</button>
      <input type="range" min="0" max="180" value="90" id="c_al"
       oninput="lbl('l_al',this.value);fetch('/arm?l='+this.value)"><span id="l_al">90</span>°</div>
    <div class="ctl"><span class="lab">🫱 右腕のみ</span>
      <button onclick="fetch('/arm?r=160')">上げ</button>
      <button onclick="fetch('/arm?r=90')">中立</button>
      <button onclick="fetch('/arm?r=60')">下げ</button>
      <button onclick="fetch('/arm?off=r')">🪫脱力</button>
      <input type="range" min="0" max="180" value="90" id="c_ar"
       oninput="lbl('l_ar',this.value);fetch('/arm?r='+this.value)"><span id="l_ar">90</span>°</div>
  </div>

  <div class="grp"><h2>👁 目テスト</h2>
    <div class="ctl">
      <button onclick="eye('emo','happy')">😊 笑顔</button>
      <button onclick="eye('emo','sad')">😢 悲しい</button>
      <button onclick="eye('emo','angry')">😠 怒り</button>
      <button onclick="eye('emo','surprised')">😲 驚き</button>
      <button onclick="eye('emo','sleepy')">😴 眠い</button>
      <button onclick="eye('emo','thinking')">🌀 考え中</button>
      <button onclick="eye('emo','neutral')">😐 通常</button>
      <button onclick="eye('emo','x')">✕ 終了マーク</button>
      <button onclick="eye('blink','1')">まばたき</button></div>
  </div>
</section>

<script>
function tab(btn,n){
  document.querySelectorAll('.view').forEach(v=>{v.hidden = (v.id!=='view-'+n);});
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
  btn.classList.add('active');
}
function set(k,v){ fetch('/set?'+k+'='+encodeURIComponent(v)); }
function lbl(id,v){ document.getElementById(id).textContent=v; }
function say(){ fetch('/say?text='+encodeURIComponent(document.getElementById('c_say').value)); }
function llmsay(){ fetch('/llm?text='+encodeURIComponent(document.getElementById('c_llmq').value)); }
function chat(){ const el=document.getElementById('c_chat'); const v=el.value.trim(); if(v){ fetch('/llm?text='+encodeURIComponent(v)); el.value=''; } }
function setUiLang(lang){ uiEN=(lang==='en'); localStorage.setItem('koro_ui',lang); applyUiLang(); }
function audiocheck(){ fetch('/audiocheck'); }
function eye(k,v){ fetch('/eye?'+k+'='+encodeURIComponent(v)); }
function armdo(v){ fetch('/arm?do='+v); }
function setHTML(id,h){ const el=document.getElementById(id); if(el) el.innerHTML=h; }

// ===== UI多言語 (クライアント側i18n・外部依存なし) =====
const I18N = {
  "🤖 コロ助":"🤖 Korosuke","📺 モニタ":"📺 Monitor","⚙ 設定":"⚙ Settings",
  "👁 目":"👁 Eyes","📷 カメラ":"📷 Camera","🎙 マイク":"🎙 Mic","🔈 音声":"🔈 Audio",
  "🗣 コロ助のセリフ":"🗣 Korosuke says","👁 カメラ + 人物/姿勢検知":"👁 Camera + person/pose",
  "認識:":"Detected:","🎙 マイク / 💬 音声認識 (sherpa-onnx)":"🎙 Mic / 💬 Speech recognition (sherpa-onnx)",
  "レベル:":"Level:",
  "🔊 音声":"🔊 Audio","🔈 出力先":"🔈 Output",
  "MAX98357A(I2Sアンプ40pin・φ50)":"MAX98357A (I2S amp 40pin, φ50)","ES8326(旧・大型SP)":"ES8326 (old large SP)",
  "🔊 音量":"🔊 Volume","🎛 小型SP最適化":"🎛 Small-SP tuning","HPF+圧縮+リミッタ":"HPF+comp+limiter",
  "クリーン上限":"Clean ceiling",
  "（φ50=0.2Wは-6運用。高耐入力SP/箱固定なら上げて大音量化）":"(φ50 0.2W uses -6; raise for louder with a tougher SP / fixed box)",
  "🎙 マイク感度":"🎙 Mic gain","🎵 声の高さ":"🎵 Pitch","⏩ 話速":"⏩ Speed","🗣 テスト発声":"🗣 Test speak",
  "喋る":"Speak","🔈 音声チェック":"🔈 Audio check","カード検証＋テスト発声":"Verify card + test speak",
  "(開けなければ自動で再バインド。「音声チェックOKナリ」が聞こえれば正常)":"(auto re-binds if it can't open; OK if you hear the check line)",
  "🤖 LLM対話テスト":"🤖 LLM chat test","LLMに聞く":"Ask LLM","(応答5〜10秒→上の吹き出し)":"(reply 5-10s -> bubble above)",
  "🔁 反応と会話":"🔁 Reactions & chat","入退室で挨拶":"Greet on enter/leave","話しかけに反応":"React to speech",
  "LLM会話":"LLM chat","腕を自動で動かす(調整中はOFF)":"Move arms automatically (OFF while tuning)",
  "入退室/ジェスチャ台詞をLLM生成(OFF=定型・即時)":"LLM-generate lines for enter/gesture (OFF=preset, instant)",
  "🌐 言語 / Language":"🌐 Language","🌐 一括 / All":"🌐 All at once",
  "STT・LLM・TTS・表示をまとめて切替":"Switch STT, LLM, TTS & display all at once",
  "🖥 表示言語 / Display":"🖥 Display language","Web画面の表示だけ切替(発話は変えない)":"Changes on-screen display only (not speech)",
  "💬 チャット / Chat":"💬 Chat","送信 / Send":"Send",
  "入力するとローカルLLMが返答(5〜10秒)→上の吹き出し＆発声":"Type to get a local-LLM reply (5-10s) -> bubble above + voice",
  "💬 音声認識 STT":"💬 Speech recognition (STT)","🤖 LLM応答":"🤖 LLM replies",
  "🔊 音声合成 TTS":"🔊 Speech synthesis (TTS)","日本語 (ReazonSpeech)":"Japanese (ReazonSpeech)",
  "日本語（ナリ口調）":"Japanese (nari style)","日本語 (Open JTalk)":"Japanese (Open JTalk)",
  "英語STTは英語sherpaモデル、英語TTSは espeak-ng が必要。未導入時は自動で日本語にフォールバックします。":"English STT needs an English sherpa model; English TTS needs espeak-ng. Falls back to Japanese if absent.",
  "🔍 認識しきい値":"🔍 Detection thresholds","👤 人物検出":"👤 Person detect","🦴 骨格":"🦴 Skeleton",
  "⏱ ジェスチャ間隔":"⏱ Gesture interval","秒":"s",
  "💪 腕サーボ":"💪 Arm servos","両方":"Both","👋手を振る":"👋 Wave","🙌バンザイ":"🙌 Hurray","😔下げる":"😔 Lower",
  "🪫脱力(PWM OFF)":"🪫 Relax (PWM OFF)","🫲 左腕のみ":"🫲 Left arm","🫱 右腕のみ":"🫱 Right arm",
  "上げ":"Up","中立":"Center","下げ":"Down","🪫脱力":"🪫 Relax",
  "👁 目テスト":"👁 Eye test","😊 笑顔":"😊 Happy","😢 悲しい":"😢 Sad","😠 怒り":"😠 Angry",
  "😲 驚き":"😲 Surprised","😴 眠い":"😴 Sleepy","🌀 考え中":"🌀 Thinking","😐 通常":"😐 Neutral",
  "✕ 終了マーク":"✕ Shutdown mark","まばたき":"Blink"
};
// 動的文字列(JSが都度生成)用
const TD = {
  "停止":"Stopped","稼働":"Running","喋ってる":"Speaking","人を発見":"Person found","待機":"Idle",
  "未接続":"Disconnected","稼働中":"Running","準備OK":"Ready","読込中":"Loading","(準備OK)":"(ready)",
  "(読込中/未導入)":"(loading/absent)","人物なし":"No person","追跡中":"tracking",
  "(まだ何も話してないナリ)":"(nothing said yet)","（聞いてるナリ…）":"(listening...)","実際: ":"actual: "
};
let uiEN = localStorage.getItem('koro_ui') === 'en';
function t(s){ return uiEN && TD[s] !== undefined ? TD[s] : s; }
let _i18nNodes = null;
function _collect(){
  const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT), a = [];
  while (w.nextNode()) { const n = w.currentNode, k = n.nodeValue.trim();
    if (k && I18N[k] !== undefined) a.push({n: n, raw: n.nodeValue, k: k}); }
  return a;
}
function applyUiLang(){
  if (!_i18nNodes) _i18nNodes = _collect();
  _i18nNodes.forEach(o => { o.n.nodeValue = uiEN ? o.raw.replace(o.k, I18N[o.k]) : o.raw; });
  document.documentElement.lang = uiEN ? 'en' : 'ja';
  const b = document.getElementById('langbtn'); if (b) b.textContent = uiEN ? '🌐 日本語' : '🌐 EN';
  const u = document.getElementById('c_uilang'); if (u) u.value = uiEN ? 'en' : 'ja';
}
// ヘッダの🌐ボタン: UI表示だけでなく、STT/LLM/TTSの発話言語もまとめて切替
function toggleLang(){ setAllLang(uiEN ? 'ja' : 'en'); }
// 一括切替: STT/LLM/TTS(サーバ側)＋画面表示(UI)をまとめてja/enに
function setAllLang(lang){
  ['stt_lang','llm_lang','tts_lang'].forEach(k => set(k, lang));
  const ids = ['c_sttlang','c_llmlang','c_ttslang'];
  ids.forEach(id => { const el = document.getElementById(id); if (el) el.value = lang; });
  uiEN = (lang === 'en'); localStorage.setItem('koro_ui', lang); applyUiLang();
}

const es = new EventSource('/events');
es.onmessage = e => {
  const d = JSON.parse(e.data);
  document.getElementById('meter').style.width = d.level + '%';
  document.getElementById('peak').style.left = d.peak_hold + '%';
  document.getElementById('lv').textContent = d.level.toFixed(1);
  document.getElementById('partial').textContent = t(d.partial || '');
  document.getElementById('dets').textContent =
      (d.dets.length ? (uiEN ? 'People: ' + d.dets.length : '人物検知: ' + d.dets.length + '人') : t('人物なし'))
      + (d.gesture ? '  🖐 ' + d.gesture : '');
  const reco = document.getElementById('reco');
  if (reco) reco.textContent =
      (d.dets.length ? d.dets.length + (uiEN ? ' ppl (' : '人 (') + d.dets.map(x=>x[1].toFixed(2)).join(',') + ')' : t('人物なし'))
      + (d.gesture ? ' / 🖐 ' + d.gesture : '') + (d.present ? ' / ' + t('追跡中') : '');
  document.getElementById('finals').innerHTML = d.finals.map(x => '<div>' + x + '</div>').join('');
  const sp = document.getElementById('speech');
  sp.textContent = d.speech || t('(まだ何も話してないナリ)');
  sp.className = d.speaking ? 'talk' : '';
  document.getElementById('speechlog').innerHTML = d.speech_log.map(x => '<div>' + x + '</div>').join('');
  const eh = d.eye_ok
      ? (d.speaking ? '<span class=ok>' + t('喋ってる') + '</span>' : (d.present ? '<span class=ok>' + t('人を発見') + '</span>' : '<span class=ok>' + t('待機') + '</span>'))
      : '<span class=ng>' + t('未接続') + '</span>';
  setHTML('eyest', eh);
  const ch = d.cam_ok ? '<span class=ok>' + t('稼働') + (d.yolo_ok ? '+YOLO' : '') + '</span>' : '<span class=ng>' + t('停止') + '</span>';
  setHTML('camst', ch);
  const alng = (d.stt_lang_active || 'ja').toUpperCase();
  setHTML('micst', (d.audio_ok ? '<span class=ok>' + t('稼働中') + '</span>' : '<span class=ng>' + t('停止') + '</span>') + ' <small>(' + alng + ')</small>');
  setHTML('sttlangnote', ' ' + t('実際: ') + alng);
  setHTML('spkst', d.spk_ok ? '<span class=ok>OK</span>' : '<span class=ng>NG</span>');
  setHTML('llmst2', d.llm_ready ? '<span class=ok>' + t('準備OK') + '</span>' : '<span class=ng>' + t('読込中') + '</span>');
  setHTML('llmst', d.llm_ready ? '<span class=ok>' + t('(準備OK)') + '</span>' : '<span class=ng>' + t('(読込中/未導入)') + '</span>');
};
es.onerror = () => { document.getElementById('st').textContent = uiEN ? '(disconnected - reconnecting...)' : '(切断 — 再接続中…)'; };
es.onopen = () => { document.getElementById('st').textContent = ''; };
const cam = document.getElementById('cam');
cam.onerror = () => { setTimeout(() => { cam.src = '/stream?' + Date.now(); }, 1000); };
applyUiLang();   // 保存済みのUI言語をロード時に適用
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json_ok(self):
        b = b'{"ok":true}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path.startswith("/set?"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            for k, v in q.items():
                val = v[0]
                if k == "volume":
                    apply_volume(val)
                elif k == "oj_fm":
                    try:
                        settings["oj_fm"] = int(float(val))
                    except ValueError:
                        pass
                elif k in ("oj_a", "oj_r", "mic_gain", "pose_score", "kpt_thres",
                           "gesture_cd", "peak_ceil_db", "hpf"):
                    try:
                        settings[k] = float(val)
                    except ValueError:
                        pass
                elif k == "spk_dev":
                    if val in ("duplexaudio", "max98357a"):
                        settings["spk_dev"] = val
                elif k in ("stt_lang", "llm_lang", "tts_lang"):
                    if val in ("ja", "en"):
                        settings[k] = val
                elif k in ("react_greet", "react_speech", "use_llm", "use_arm",
                           "event_llm", "dsp"):
                    settings[k] = val in ("1", "true", "on")
            self._json_ok()
            return
        if self.path.startswith("/audiocheck"):     # 音声カード検証&自動修復+テスト発声
            ok = ensure_audio_card()
            if ok:
                speak("音声チェック、OKナリ！")     # 聞こえれば正常
            self._json_ok()
            return
        if self.path.startswith("/say?"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            txt = (q.get("text") or [""])[0].strip()
            if txt:
                with lock:
                    state["speech"] = txt
                    state["speech_log"] = ([time.strftime("%H:%M:%S ") + txt] + state["speech_log"])[:8]
                speak(txt, block=("sync" in q))   # sync時は再生完了までブロック(シャットダウン用)
            self._json_ok()
            return
        if self.path.startswith("/llm?"):          # Webから直接LLM対話テスト
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            txt = (q.get("text") or [""])[0].strip()
            if txt and _llm["ready"] and not _llm["busy"]:
                threading.Thread(target=llm_respond, args=(txt,), daemon=True).start()
            self._json_ok()
            return
        if self.path.startswith("/eye?"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "emo" in q:
                eyes.send("emo " + q["emo"][0])
            if "blink" in q:
                eyes.send("blink")
            self._json_ok()
            return
        if self.path.startswith("/arm?"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "l" in q:
                eyes.send("arm l " + q["l"][0])
            if "r" in q:
                eyes.send("arm r " + q["r"][0])
            if "do" in q:
                arm_gesture(q["do"][0])            # wave/raise/droop
            if "off" in q:                          # 脱力(省電流): l / r / both
                v = q["off"][0]
                if v in ("l", "both"):
                    eyes.send("arm l off")
                if v in ("r", "both"):
                    eyes.send("arm r off")
            self._json_ok()
            return
        if self.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, must-revalidate")  # 常に最新UIを配信
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path.startswith("/stream"):
            self.send_response(200)
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=FRAME")
            self.end_headers()
            try:
                while True:
                    with lock:
                        jpg = state["jpeg"]
                    if jpg:
                        self.wfile.write(b"--FRAME\r\nContent-Type: image/jpeg\r\n")
                        self.wfile.write(("Content-Length: %d\r\n\r\n" % len(jpg)).encode())
                        self.wfile.write(jpg)
                        self.wfile.write(b"\r\n")
                    time.sleep(0.05)
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif self.path == "/events":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            try:
                while True:
                    with lock:
                        snap = {k: state[k] for k in
                                ("level", "peak_hold", "partial", "finals", "cam_ok",
                                 "audio_ok", "yolo_ok", "dets", "gesture", "speech",
                                 "speech_log", "eye_ok", "present", "speaking", "spk_ok")}
                    snap["llm_ready"] = _llm["ready"]
                    snap["stt_lang_active"] = state.get("stt_lang_active", settings["stt_lang"])
                    self.wfile.write(("data: " + json.dumps(snap, ensure_ascii=False) + "\n\n").encode("utf-8"))
                    self.wfile.flush()
                    time.sleep(0.1)
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_response(404)
            self.end_headers()


def touch_loop():
    """目ESP32のシリアルから'EVENT touch'(撫で)を受けて反応する。"""
    while True:
        try:
            ser = eyes._ser
            if ser and ser.is_open and ser.in_waiting:
                line = ser.readline().decode("ascii", "ignore").strip()
                if "EVENT touch" in line:
                    now = time.time()
                    if now - _last_pet[0] > 3.0 and now >= _speak_until[0] and settings["react_speech"]:
                        _last_pet[0] = now
                        event_speech(ctx("頭を撫でられた。うれしそうに短く。",
                                         "You were patted on the head. React happily and briefly in English."),
                                     clines(PET_LINES, PET_LINES_EN), "happy")
            else:
                time.sleep(0.05)
        except Exception:  # noqa
            time.sleep(0.3)


BOOT_LINES = [
    "おはようナリ！コロ助、起きたナリ！",
    "むくっ…おはようナリ！今日も元気にがんばるナリ！",
    "やっほー！コロ助、起動したナリ！",
    "おはようナリ〜！さあ、はじめるナリ！",
]
BOOT_LINES_EN = [
    "Good morning! Korosuke is awake!",
    "Mmm... good morning! I'll do my best today!",
    "Hi hi! Korosuke is up and running!",
    "Good morning! Let's get started!",
]


def boot_greet():
    """起動時のあいさつ(目/スピーカーの準備を待ってから1回だけ)。"""
    time.sleep(8)                                        # 目の接続+音声準備を待つ
    bl = clines(BOOT_LINES, BOOT_LINES_EN)
    line = bl[int(time.time()) % len(bl)]
    react("happy", line, blink=True)                     # にっこり+発声+Web表示
    if settings.get("use_arm", True):
        try:
            arm_gesture("wave")                          # 手を振ってごあいさつ
        except Exception:  # noqa
            pass


if __name__ == "__main__":
    apply_volume(settings["volume"])
    apply_mic_hw_gain()
    ensure_audio_card()                                       # 起動時: 音声カード検証&自動修復
    threading.Thread(target=load_llm, daemon=True).start()   # LLMロード(数十秒)
    threading.Thread(target=touch_loop, daemon=True).start()  # 撫で検知
    threading.Thread(target=camera_loop, daemon=True).start()
    threading.Thread(target=yolo_loop, daemon=True).start()
    threading.Thread(target=audio_loop, daemon=True).start()
    threading.Thread(target=boot_greet, daemon=True).start()  # 起動あいさつ「おはよう」
    print("コロ助モニタv4起動: http://0.0.0.0:%d/" % PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
