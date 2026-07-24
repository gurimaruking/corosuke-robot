#!/usr/bin/env python3
"""コロ助 Web監視モニタ v4 — 見て/聞いて/動きに反応して/喋る
  カメラ+YOLO人物検知+モーション検知 / sherpa音声認識+キーワード反応 / 目+OpenJTalk発声
使い方: python3 korosuke_monitor.py  →  http://<RDKのIP>:8080
依存: cv2, sherpa-onnx, open_jtalk, D-Robotics YOLO demo。各機能は失敗しても縮退。
"""
import audioop
import glob
import json
import math
import os
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
EYE_DEV = "/dev/ttyACM0"           # 目コプロセッサ(ESP32-S3)
SPK_DEV = "plughw:duplexaudio,0"   # スピーカー(ES8326、名前指定=再起動耐性)

# ---- Open JTalk(動的日本語TTS) ----
OJ_BIN = "open_jtalk"
OJ_DIC = "/var/lib/mecab/dic/open-jtalk/naist-jdic"
OJ_VOICE = "/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice"
os.chdir(YOLO_DIR)   # デモの相対import解決のため(以降は全て絶対パス使用)

# ==== Webから変更できる実行時設定 ====
settings = {
    "volume": 75,          # スピーカー音量 %(amixer DAC)
    "mic_gain": 3.0,       # マイク感度(ソフト増幅倍率)。ハードゲインは起動時に最大化
    "oj_fm": 9,            # 声の高さ(Open JTalk -fm)。voice B=9
    "oj_a": 0.40,         # 声道長(小=子供っぽい)
    "oj_r": 1.12,         # 話速
    "react_greet": True,   # 入退室で挨拶する
    "react_speech": True,  # 話しかけに反応する
}


def apply_mic_hw_gain():
    """USBマイクのハードキャプチャゲインを最大化(起動時)。"""
    try:
        subprocess.run(["amixer", "-c", "Microphone", "sset", "Mic Capture Volume", "100%"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        subprocess.run(["amixer", "-c", "Microphone", "sset", "Mic Capture Switch", "on"],
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
FAREWELLS = [
    "いっちゃいやナリ〜！",
    "もう行っちゃうナリ？さみしいナリ…",
    "行かないでほしいナリ〜！",
    "またすぐ来てほしいナリ！",
]

state = {
    "jpeg": None, "cam_ok": False,
    "dets": [], "yolo_ok": False, "raw": None,
    "level": 0.0, "peak_hold": 0.0, "audio_ok": False,
    "partial": "", "finals": [],
    "speech": "", "speech_log": [], "eye_ok": False, "present": False, "speaking": False,
}
lock = threading.Lock()

# 自分の声をマイクが拾って自己反応するのを防ぐガード
_speak_until = [0.0]
_last_speech_react = [0.0]
_last_motion_react = [0.0]


def speak(text):
    """Open JTalkで動的合成→スピーカー再生(非ブロッキング)。発話中フラグで自己反応を抑止。"""
    def _run():
        try:
            wav = "/tmp/koro_say.wav"
            p = subprocess.run([OJ_BIN, "-x", OJ_DIC, "-m", OJ_VOICE,
                                "-fm", str(settings["oj_fm"]), "-a", str(settings["oj_a"]),
                                "-r", str(settings["oj_r"]), "-ow", wav],
                               input=(text + "\n").encode("utf-8"),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            if p.returncode != 0 or not os.path.exists(wav):
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
            subprocess.run(["aplay", "-D", SPK_DEV, wav],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        except Exception:  # noqa
            pass
        finally:
            with lock:
                state["speaking"] = False
    threading.Thread(target=_run, daemon=True).start()


def camera_loop():
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    for _ in range(5):
        cap.read()
    while True:
        ok, frame = cap.read()
        if not ok:
            with lock:
                state["cam_ok"] = False
            time.sleep(1)
            continue
        # 粗いフレーム差分モーション反応は無効化(入退室反応を打ち消す/歩行と手振りを区別不可)。
        # 「しっかりしたジェスチャ」はYOLO11-poseの骨格ベースで別途判定する(gesture_loop)。
        with lock:
            state["raw"] = frame.copy()
            dets = list(state["dets"])
        for label, score, (x1, y1, x2, y2) in dets:
            col = (80, 220, 100) if label == "person" else (60, 160, 255)
            cv2.rectangle(frame, (x1, y1), (x2, y2), col, 2)
            cv2.putText(frame, f"{label} {score:.2f}", (x1, max(14, y1 - 6)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, col, 1, cv2.LINE_AA)
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
    line = MOTION_LINES[int(now) % len(MOTION_LINES)]
    react("surprised", line, blink=True)


# ============ 目(ESP32-S3)制御 ============
class Eyes:
    def __init__(self):
        self._ser = None

    def _ensure(self):
        if self._ser or serial is None or not os.path.exists(EYE_DEV):
            return
        try:
            self._ser = serial.Serial(EYE_DEV, 115200, timeout=0.3)
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
                msg = GREETINGS[_greet["idx"] % len(GREETINGS)]
                _greet["idx"] += 1
                react("happy", msg, gaze=gaze_x, blink=True)
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
                # 退室時は寂しがる(いっちゃいやナリ)
                msg = FAREWELLS[_greet["fidx"] % len(FAREWELLS)]
                _greet["fidx"] += 1
                react("sad", msg, gaze=0.0, blink=True)
            else:
                eyes.send("emo neutral")
                eyes.send("gaze 0 0")


def yolo_loop():
    try:
        import importlib.util
        import sys
        from types import SimpleNamespace
        sys.path.append("/app/pydev_demo")
        spec = importlib.util.spec_from_file_location(
            "uy", os.path.join(YOLO_DIR, "ultralytics_yolo11.py"))
        uy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(uy)
        import utils.common_utils as common
        opt = SimpleNamespace(
            model_path=os.path.join(YOLO_DIR, "yolo11n_detect_bayese_640x640_nv12.bin"),
            priority=0, bpu_cores=[0], nms_thres=0.45, score_thres=0.40)
        y = uy.YoloV11(opt)
        names = common.load_class_names(os.path.join(YOLO_DIR, "coco_classes.names"))
    except Exception as e:  # noqa
        print("[yolo] 無効化:", e)
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
            h, w = frame.shape[:2]
            out = y.forward(y.pre_process(frame))
            boxes, cls, sc = y.post_process(out, w, h)
            dets = [(names[int(c)], float(s), [int(v) for v in b])
                    for b, c, s in zip(boxes, cls, sc)]
            with lock:
                state["dets"] = dets
            persons = [(b, (b[2] - b[0]) * (b[3] - b[1]))
                       for b, c in zip(boxes, cls) if int(c) == 0]
            best = max(persons, key=lambda p: p[1])[0] if persons else None
            greet_update(best, w)
        except Exception as e:  # noqa
            print("[yolo]", e)
        time.sleep(0.2)


def react_to_speech(text):
    """認識テキストにキーワードが含まれたら反応。自己発話・連発を抑止。"""
    if not settings["react_speech"]:
        return
    now = time.time()
    if now < _speak_until[0]:                  # 自分の声を拾った分は無視
        return
    if now - _last_speech_react[0] < 2.0:
        return
    for keys, emo, reply in SPEECH_REACTIONS:
        if any(k in text for k in keys):
            _last_speech_react[0] = now
            react(emo, reply, blink=True)
            return


def audio_loop():
    try:
        import sherpa_onnx
        d = sorted(glob.glob("/home/sunrise/models/sherpa-onnx-zipformer-ja-reazonspeech*"))[0]
        rec = sherpa_onnx.OfflineRecognizer.from_transducer(
            encoder=sorted(glob.glob(d + "/encoder*int8.onnx"))[0],
            decoder=sorted(glob.glob(d + "/decoder*[!8].onnx"))[0],
            joiner=sorted(glob.glob(d + "/joiner*int8.onnx"))[0],
            tokens=d + "/tokens.txt", num_threads=6)   # YOLOはBPU中心なのでCPUを多めに
        vcfg = sherpa_onnx.VadModelConfig()
        vcfg.silero_vad.model = "/home/sunrise/models/silero_vad.onnx"
        vcfg.silero_vad.threshold = 0.6            # 高め=雑音/弱い音を無視
        vcfg.silero_vad.min_silence_duration = 0.7  # 細切れ抑制
        vcfg.silero_vad.min_speech_duration = 0.3   # 短い誤検出を除外
        vcfg.sample_rate = 16000
        vad = sherpa_onnx.VoiceActivityDetector(vcfg, buffer_size_in_seconds=30)
        win = vcfg.silero_vad.window_size
    except Exception as e:  # noqa
        print("[audio] sherpa初期化失敗:", e)
        return

    def decode(samples):
        st = rec.create_stream()
        st.accept_waveform(16000, samples)
        rec.decode_stream(st)
        return st.result.text.strip()

    CHUNK = 4800 * 2 * 2
    pending = []
    ratecv_state = None
    while True:
        p = subprocess.Popen(
            ["arecord", "-D", "plughw:Microphone,0", "-f", "S16_LE",
             "-r", "48000", "-c", "2", "-t", "raw"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            while True:
                data = p.stdout.read(CHUNK)
                if not data:
                    raise IOError("stream ended")
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
body{font-family:sans-serif;background:#1a1a2e;color:#eee;margin:0;padding:16px}
h1{font-size:1.2rem;margin:0 0 12px}
.grid{display:flex;flex-wrap:wrap;gap:16px}
.card{background:#16213e;border-radius:10px;padding:12px;flex:1;min-width:320px}
.card h2{font-size:1rem;margin:0 0 8px;color:#ffb347}
img{width:100%;border-radius:6px;background:#000}
.meterbox{background:#0f3460;border-radius:6px;height:28px;position:relative;overflow:hidden}
#meter{background:linear-gradient(90deg,#4ecca3,#ffd460 70%,#ff2e63 90%);height:100%;width:0%;transition:width .1s}
#peak{position:absolute;top:0;width:2px;height:100%;background:#fff}
#lv{font-variant-numeric:tabular-nums}
#partial{color:#4ecca3;min-height:1.4em;font-size:1.1rem}
#dets{color:#8fd;font-size:.85rem;min-height:1.2em}
#finals div{border-bottom:1px solid #0f3460;padding:3px 0}
.ok{color:#4ecca3}.ng{color:#ff2e63}
#speech{background:#0f3460;border-radius:8px;padding:14px;font-size:1.4rem;color:#ffe08a;min-height:1.6em;transition:background .2s}
#speech.talk{background:#3a5a1c}
#speechlog{margin-top:8px;font-size:.85rem;color:#9bb}
#speechlog div{padding:2px 0}
.full{flex-basis:100%}
.ctl{margin:8px 0;font-size:.95rem}
.ctl input[type=range]{vertical-align:middle;width:180px}
.ctl button{margin:2px;padding:4px 10px;border-radius:6px;border:1px solid #4ecca3;background:#16213e;color:#eee;cursor:pointer}
.ctl button:hover{background:#0f3460}
.ctl label{margin:0 8px}
.ctl input[type=text]{background:#0f3460;border:1px solid #4ecca3;color:#eee;border-radius:4px;padding:3px}
</style></head><body>
<h1>🤖 コロ助モニタ <small id="st"></small></h1>
<div class="grid">
<div class="card full"><h2>🗣 コロ助のセリフ (<span id="eyest">…</span>)</h2>
<div id="speech">…</div><div id="speechlog"></div></div>
<div class="card"><h2>👁 カメラ+検知 (<span id="camst">…</span>)</h2>
<img id="cam" src="/stream" alt="camera"><div id="dets"></div></div>
<div class="card"><h2>🎙 マイク (<span id="micst">…</span>)</h2>
<div class="meterbox"><div id="meter"></div><div id="peak"></div></div>
<p>レベル: <span id="lv">0</span> %FS</p>
<h2>💬 音声認識 (sherpa-onnx)</h2>
<p id="partial"></p><div id="finals"></div></div>
<div class="card full"><h2>⚙ 設定</h2>
<div class="ctl">🔊 音量 <input type="range" min="0" max="100" value="75" id="c_vol"
  oninput="lbl('l_vol',this.value);set('volume',this.value)"><span id="l_vol">75</span>%</div>
<div class="ctl">🎙 マイク感度 <input type="range" min="1" max="8" step="0.5" value="3" id="c_mic"
  oninput="lbl('l_mic',this.value);set('mic_gain',this.value)"><span id="l_mic">3</span>x</div>
<div class="ctl">🎵 声の高さ <input type="range" min="0" max="15" value="9" id="c_fm"
  oninput="lbl('l_fm',this.value);set('oj_fm',this.value)"><span id="l_fm">9</span></div>
<div class="ctl">⏩ 話速 <input type="range" min="0.7" max="1.5" step="0.05" value="1.12" id="c_r"
  oninput="lbl('l_r',this.value);set('oj_r',this.value)"><span id="l_r">1.12</span></div>
<div class="ctl">🗣 テスト発声 <input type="text" id="c_say" value="ワガハイはコロ助ナリ！" size="24">
  <button onclick="say()">喋る</button></div>
<div class="ctl">🔁 反応
  <label><input type="checkbox" id="c_g" checked onchange="set('react_greet',this.checked?1:0)"> 入退室で挨拶</label>
  <label><input type="checkbox" id="c_s" checked onchange="set('react_speech',this.checked?1:0)"> 話しかけに反応</label></div>
<div class="ctl">👁 目テスト
  <button onclick="eye('emo','happy')">😊</button>
  <button onclick="eye('emo','sad')">😢</button>
  <button onclick="eye('emo','angry')">😠</button>
  <button onclick="eye('emo','surprised')">😲</button>
  <button onclick="eye('emo','sleepy')">😴</button>
  <button onclick="eye('emo','neutral')">😐</button>
  <button onclick="eye('blink','1')">まばたき</button></div>
</div>
</div>
<script>
function set(k,v){ fetch('/set?'+k+'='+encodeURIComponent(v)); }
function lbl(id,v){ document.getElementById(id).textContent=v; }
function say(){ fetch('/say?text='+encodeURIComponent(document.getElementById('c_say').value)); }
function eye(k,v){ fetch('/eye?'+k+'='+encodeURIComponent(v)); }
const es = new EventSource('/events');
es.onmessage = e => {
  const d = JSON.parse(e.data);
  document.getElementById('meter').style.width = d.level + '%';
  document.getElementById('peak').style.left = d.peak_hold + '%';
  document.getElementById('lv').textContent = d.level.toFixed(1);
  document.getElementById('partial').textContent = d.partial || '';
  document.getElementById('dets').textContent = d.dets.length
      ? '検知: ' + d.dets.map(x => x[0]+'('+x[1].toFixed(2)+')').join(', ') : '';
  document.getElementById('finals').innerHTML = d.finals.map(t => '<div>' + t + '</div>').join('');
  const sp = document.getElementById('speech');
  sp.textContent = d.speech || '(まだ何も話してないナリ)';
  sp.className = d.speaking ? 'talk' : '';
  document.getElementById('speechlog').innerHTML = d.speech_log.map(t => '<div>' + t + '</div>').join('');
  document.getElementById('eyest').innerHTML = d.eye_ok
      ? (d.speaking ? '<span class=ok>喋ってるナリ</span>' : (d.present ? '<span class=ok>人を発見！</span>' : '<span class=ok>待機</span>'))
      : '<span class=ng>目未接続</span>';
  document.getElementById('camst').innerHTML = d.cam_ok
      ? '<span class=ok>稼働' + (d.yolo_ok ? '+YOLO' : '') + '</span>' : '<span class=ng>停止</span>';
  document.getElementById('micst').innerHTML = d.audio_ok ? '<span class=ok>稼働中</span>' : '<span class=ng>停止</span>';
};
es.onerror = () => { document.getElementById('st').textContent = '(切断 — 再接続中…)'; };
es.onopen = () => { document.getElementById('st').textContent = ''; };
const cam = document.getElementById('cam');
cam.onerror = () => { setTimeout(() => { cam.src = '/stream?' + Date.now(); }, 1000); };
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
                elif k in ("oj_a", "oj_r", "mic_gain"):
                    try:
                        settings[k] = float(val)
                    except ValueError:
                        pass
                elif k in ("react_greet", "react_speech"):
                    settings[k] = val in ("1", "true", "on")
            self._json_ok()
            return
        if self.path.startswith("/say?"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            txt = (q.get("text") or [""])[0].strip()
            if txt:
                speak(txt)
                with lock:
                    state["speech"] = txt
                    state["speech_log"] = ([time.strftime("%H:%M:%S ") + txt] + state["speech_log"])[:8]
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
        if self.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
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
                                 "audio_ok", "yolo_ok", "dets", "speech", "speech_log",
                                 "eye_ok", "present", "speaking")}
                    self.wfile.write(("data: " + json.dumps(snap, ensure_ascii=False) + "\n\n").encode("utf-8"))
                    self.wfile.flush()
                    time.sleep(0.1)
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_response(404)
            self.end_headers()


if __name__ == "__main__":
    apply_volume(settings["volume"])
    apply_mic_hw_gain()
    threading.Thread(target=camera_loop, daemon=True).start()
    threading.Thread(target=yolo_loop, daemon=True).start()
    threading.Thread(target=audio_loop, daemon=True).start()
    print("コロ助モニタv4起動: http://0.0.0.0:%d/" % PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
