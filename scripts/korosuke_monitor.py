#!/usr/bin/env python3
"""コロ助 Web監視モニタ — カメラ / マイクレベル / 音声認識をブラウザで確認
使い方: python3 korosuke_monitor.py  →  http://<RDKのIP>:8080
依存: cv2(同梱), vosk(導入済), ALSA(arecord)。Flask不要(標準ライブラリのみ)
"""
import audioop
import json
import math
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import cv2

PORT = 8080
state = {
    "jpeg": None,          # 最新カメラフレーム(JPEGバイト列)
    "cam_ok": False,
    "level": 0.0,          # マイクRMS(%FS)
    "peak_hold": 0.0,
    "partial": "",         # vosk途中認識
    "finals": [],          # vosk確定認識(新しい順, 最大10件)
    "audio_ok": False,
}
lock = threading.Lock()


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
        ok2, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if ok2:
            with lock:
                state["jpeg"] = buf.tobytes()
                state["cam_ok"] = True
        time.sleep(0.03)   # ~20fps上限


def audio_loop():
    from vosk import Model, KaldiRecognizer, SetLogLevel
    SetLogLevel(-1)
    model = Model("/home/sunrise/models/vosk-model-small-ja-0.22")
    rec = KaldiRecognizer(model, 16000)
    CHUNK_FRAMES = 4800                    # 0.1秒 @48k
    CHUNK_BYTES = CHUNK_FRAMES * 2 * 2     # 16bit x 2ch
    while True:
        p = subprocess.Popen(
            ["arecord", "-D", "plughw:Microphone,0", "-f", "S16_LE",
             "-r", "48000", "-c", "2", "-t", "raw"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        ratecv_state = None
        try:
            while True:
                data = p.stdout.read(CHUNK_BYTES)
                if not data:
                    raise IOError("arecord stream ended")
                mono = audioop.tomono(data, 2, 0.5, 0.5)  # L/R平均(逆相電気ノイズを相殺)
                s = struct.unpack("<%dh" % (len(mono) // 2), mono)
                rms = math.sqrt(sum(x * x for x in s) / len(s))
                level = min(100.0, rms / 327.67)          # %FS
                conv, ratecv_state = audioop.ratecv(mono, 2, 1, 48000, 16000, ratecv_state)
                with lock:
                    state["audio_ok"] = True
                    state["level"] = round(level, 1)
                    state["peak_hold"] = max(state["peak_hold"] * 0.97, level)
                if rec.AcceptWaveform(conv):
                    t = json.loads(rec.Result()).get("text", "").replace(" ", "")
                    with lock:
                        state["partial"] = ""
                        if t:
                            state["finals"] = ([time.strftime("%H:%M:%S ") + t]
                                               + state["finals"])[:10]
                else:
                    pt = json.loads(rec.PartialResult()).get("partial", "").replace(" ", "")
                    with lock:
                        state["partial"] = pt
        except IOError:
            with lock:
                state["audio_ok"] = False
            p.kill()
            time.sleep(2)   # デバイス競合/抜き差し時は再試行


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
#finals div{border-bottom:1px solid #0f3460;padding:3px 0}
.ok{color:#4ecca3}.ng{color:#ff2e63}
</style></head><body>
<h1>🤖 コロ助モニタ <small id="st"></small></h1>
<div class="grid">
<div class="card"><h2>👁 カメラ (<span id="camst">…</span>)</h2><img src="/stream" alt="camera"></div>
<div class="card"><h2>🎙 マイク (<span id="micst">…</span>)</h2>
<div class="meterbox"><div id="meter"></div><div id="peak"></div></div>
<p>レベル: <span id="lv">0</span> %FS</p>
<h2>💬 音声認識 (vosk)</h2>
<p id="partial"></p><div id="finals"></div></div>
</div>
<script>
const es = new EventSource('/events');
es.onmessage = e => {
  const d = JSON.parse(e.data);
  document.getElementById('meter').style.width = d.level + '%';
  document.getElementById('peak').style.left = d.peak_hold + '%';
  document.getElementById('lv').textContent = d.level.toFixed(1);
  document.getElementById('partial').textContent = d.partial ? '…' + d.partial : '';
  document.getElementById('finals').innerHTML = d.finals.map(t => '<div>' + t + '</div>').join('');
  document.getElementById('camst').innerHTML = d.cam_ok ? '<span class=ok>稼働中</span>' : '<span class=ng>停止</span>';
  document.getElementById('micst').innerHTML = d.audio_ok ? '<span class=ok>稼働中</span>' : '<span class=ng>停止</span>';
};
es.onerror = () => { document.getElementById('st').textContent = '(切断 — 再接続中…)'; };
es.onopen = () => { document.getElementById('st').textContent = ''; };
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == "/":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/stream":
            self.send_response(200)
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=frame")
            self.end_headers()
            try:
                while True:
                    with lock:
                        jpg = state["jpeg"]
                    if jpg:
                        self.wfile.write(b"--frame\r\nContent-Type: image/jpeg\r\n\r\n")
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
                                ("level", "peak_hold", "partial", "finals", "cam_ok", "audio_ok")}
                    self.wfile.write(("data: " + json.dumps(snap) + "\n\n").encode("utf-8"))
                    self.wfile.flush()
                    time.sleep(0.1)
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_response(404)
            self.end_headers()


if __name__ == "__main__":
    threading.Thread(target=camera_loop, daemon=True).start()
    threading.Thread(target=audio_loop, daemon=True).start()
    print("コロ助モニタ起動: http://0.0.0.0:%d/" % PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
