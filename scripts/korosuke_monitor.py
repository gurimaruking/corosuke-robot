#!/usr/bin/env python3
"""コロ助 Web監視モニタ v2 — カメラ+YOLO検知 / マイクレベル / sherpa音声認識
使い方: python3 korosuke_monitor.py  →  http://<RDKのIP>:8080
依存: cv2, sherpa-onnx, D-Robotics YOLO demo(/app/pydev_demo)。全て導入済み前提。
各機能は失敗しても他を巻き込まず縮退(YOLO落ちても素の映像は出る等)。
"""
import audioop
import glob
import json
import math
import os
import struct
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import cv2

PORT = 8080
YOLO_DIR = "/app/pydev_demo/02_detection_sample/02_ultralytics_yolo11"
os.chdir(YOLO_DIR)   # デモの相対import解決のため(以降は全て絶対パス使用)

state = {
    "jpeg": None, "cam_ok": False,
    "dets": [], "yolo_ok": False,
    "raw": None,
    "level": 0.0, "peak_hold": 0.0, "audio_ok": False,
    "partial": "", "finals": [],
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
        print("[yolo] 無効化(初期化失敗):", e)
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
        except Exception as e:  # noqa
            print("[yolo] 推論エラー:", e)
        time.sleep(0.2)   # ~4-5fps(BPUは余裕、CPU描画とのバランス)


def audio_loop():
    import subprocess
    try:
        import sherpa_onnx
        d = sorted(glob.glob("/home/sunrise/models/sherpa-onnx-zipformer-ja-reazonspeech*"))[0]
        rec = sherpa_onnx.OfflineRecognizer.from_transducer(
            encoder=sorted(glob.glob(d + "/encoder*int8.onnx"))[0],
            decoder=sorted(glob.glob(d + "/decoder*[!8].onnx"))[0],
            joiner=sorted(glob.glob(d + "/joiner*int8.onnx"))[0],
            tokens=d + "/tokens.txt", num_threads=6)
        vcfg = sherpa_onnx.VadModelConfig()
        vcfg.silero_vad.model = "/home/sunrise/models/silero_vad.onnx"
        vcfg.silero_vad.threshold = 0.5
        vcfg.silero_vad.min_silence_duration = 0.5
        vcfg.silero_vad.min_speech_duration = 0.2
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

    CHUNK = 4800 * 2 * 2   # 0.1s @48k/16bit/2ch
    pending = []           # 16k float32 の蓄積
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
                mono = audioop.tomono(data, 2, 0.5, 0.5)
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
</style></head><body>
<h1>🤖 コロ助モニタ <small id="st"></small></h1>
<div class="grid">
<div class="card"><h2>👁 カメラ+検知 (<span id="camst">…</span>)</h2>
<img src="/stream" alt="camera"><div id="dets"></div></div>
<div class="card"><h2>🎙 マイク (<span id="micst">…</span>)</h2>
<div class="meterbox"><div id="meter"></div><div id="peak"></div></div>
<p>レベル: <span id="lv">0</span> %FS</p>
<h2>💬 音声認識 (sherpa-onnx)</h2>
<p id="partial"></p><div id="finals"></div></div>
</div>
<script>
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
  document.getElementById('camst').innerHTML = d.cam_ok
      ? '<span class=ok>稼働' + (d.yolo_ok ? '+YOLO' : '') + '</span>' : '<span class=ng>停止</span>';
  document.getElementById('micst').innerHTML = d.audio_ok ? '<span class=ok>稼働中</span>' : '<span class=ng>停止</span>';
};
es.onerror = () => { document.getElementById('st').textContent = '(切断 — 再接続中…)'; };
es.onopen = () => { document.getElementById('st').textContent = ''; };
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

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
            self.send_header("Age", "0")
            self.send_header("Cache-Control", "no-cache, private")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=FRAME")
            self.end_headers()
            try:
                while True:
                    with lock:
                        jpg = state["jpeg"]
                    if jpg:
                        self.wfile.write(b"--FRAME\r\n")
                        self.wfile.write(b"Content-Type: image/jpeg\r\n")
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
            self.send_header("Connection", "keep-alive")
            self.end_headers()
            try:
                while True:
                    with lock:
                        snap = {k: state[k] for k in
                                ("level", "peak_hold", "partial", "finals",
                                 "cam_ok", "audio_ok", "yolo_ok", "dets")}
                    self.wfile.write(("data: " + json.dumps(snap, ensure_ascii=False) + "\n\n").encode("utf-8"))
                    self.wfile.flush()
                    time.sleep(0.1)
            except (BrokenPipeError, ConnectionResetError):
                pass
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()


if __name__ == "__main__":
    threading.Thread(target=camera_loop, daemon=True).start()
    threading.Thread(target=yolo_loop, daemon=True).start()
    threading.Thread(target=audio_loop, daemon=True).start()
    print("コロ助モニタv2起動: http://0.0.0.0:%d/" % PORT)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
