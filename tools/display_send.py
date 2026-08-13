#!/usr/bin/env python3
"""
コロ助 胴体ディスプレイ 送信スクリプト — USB(シリアル)経由でJPEG映像をESP32-4827S043へ送る。

対応ソース:
  --source test        合成アニメ(カメラ不要。パイプライン検証用)
  --source cam[:<idx>]  webカメラ (既定 index 0)
  --source <file>       動画ファイル (mp4等)
  --source mjpeg:<url>  MJPEGストリーム(例 コロ助RDKの http://<ip>:8080/stream)

フレーミング: b'\\xA5\\x5A' + len(uint32 LE) + JPEG。ESP32は1枚描くごとに ACK(0x06) を返す
(フロー制御=RXオーバーラン防止)。ESP32のテキスト出力は "[esp] ..." で表示。

例(このWindows PCから合成アニメを送る):
  python tools/display_send.py --port COM16 --source test --duration 15
最終形(RDK X5から自分のカメラ映像を送る):
  python3 tools/display_send.py --port /dev/ttyUSB0 --source cam:0
"""
import argparse
import json
import struct
import sys
import threading
import time
import urllib.parse
import urllib.request

import numpy as np
import cv2
import serial  # pyserial
try:
    from PIL import Image, ImageDraw, ImageFont   # 日本語テキスト合成用(無ければ映像のみ)
except Exception:
    Image = None

MAGIC = b"\xA5\x5A"
ACK = 0x06

# ディスプレイ基板 = Sunton CYD の CH340C (WCH)。目ESP32(CH343=1a86:55d3 / ネイティブ=303a:1001)
# とは別物。RDKにはS3が2枚あるので、VID/PIDでディスプレイだけを厳密に選ぶ(目基板の誤選択防止)。
DISPLAY_VID, DISPLAY_PID = 0x1A86, 0x7523

# 胴体ディスプレイの回転(度)。korosuke_monitor の /dispcfg をポーリングして更新。
# cam=入力映像(カメラ向き補正) / disp=表示映像(パネル向き補正)。両者は合成される。
_rot = {"cam": 0, "disp": 0}

# 認識テキスト+返答( korosuke_monitor の /disptext をポーリング)。上帯=聞いた声 / 下帯=コロ助の返答
_txt = {"heard": "", "reply": "", "lang": "auto"}
_FONT = None
_ctl = {"base": ""}                       # monitorのベースURL(タッチ言語切替に使用)
_toast = {"t": "", "until": 0.0}          # 画面中央の一時表示(言語切替の確認)
_btn = {"rect": (0, 0, 0, 0), "vw": 480, "vh": 272}   # 言語ボタン(viewer空間)のヒット領域
_UI = {"lh": 26, "btn": True}    # 行高/ボタン有無(小画面・タッチ無しパネルでmainが調整)


def on_touch(px, py):
    """パネル座標(480x272)のタップを viewer座標へ逆回転し、言語ボタンなら切替。"""
    d = _rot["disp"] % 360
    vw, vh = _btn["vw"], _btn["vh"]
    if d == 0:
        vx, vy = px, py
    elif d == 90:      # viewerを90°CWしてパネルにした → 逆変換
        vx, vy = py, vh - 1 - px
    elif d == 180:
        vx, vy = vw - 1 - px, vh - 1 - py
    else:              # 270
        vx, vy = vw - 1 - py, px
    x0, y0, x1, y1 = _btn["rect"]
    if x0 <= vx <= x1 and y0 <= vy <= y1:
        threading.Thread(target=cycle_lang, daemon=True).start()
    else:
        # ボタン以外=お腹タッチ → くすぐったい反応(2.5秒クールダウン)
        now = time.time()
        if now - _tickle["last"] > 2.5:
            _tickle["last"] = now
            threading.Thread(target=tickle, daemon=True).start()


_tickle = {"last": 0.0}
TICKLE_LINES = ["くすぐったいナリ！", "わははっ、くすぐったいナリ〜！",
                "えへへ、お腹をさわったナリ？", "ひゃっ！びっくりしたナリ！"]
TICKLE_LINES_EN = ["That tickles, nari!", "Hahaha, that tickles!",
                   "Hehe, did you touch my belly?", "Whoa! You surprised me, nari!"]


def tickle():
    """お腹(ボタン以外)タッチ → 笑い目+くすぐったい発話(言語モードに合わせてJP/EN)。"""
    base = _ctl["base"]
    if not base:
        return
    import random
    lines = TICKLE_LINES_EN if _txt.get("lang") == "en" else TICKLE_LINES
    try:
        urllib.request.urlopen(base + "/eye?emo=happy&blink=1", timeout=3).read()
        urllib.request.urlopen(
            base + "/say?text=" + urllib.parse.quote(random.choice(lines)), timeout=3).read()
        print("[ctl] くすぐったい反応")
    except Exception as e:
        print("[ctl] tickle失敗:", e)


def cycle_lang():
    """CYDタップ → 言語を ja→en→auto で巡回。/setで一括切替し、トースト+音声で確認。"""
    base = _ctl["base"]
    if not base:
        return
    order = ["ja", "en", "auto"]
    cur = _txt.get("lang") or "auto"
    nxt = order[(order.index(cur) + 1) % 3] if cur in order else "ja"
    names = {"ja": "日本語", "en": "English", "auto": "Auto(バイリンガル)"}
    say = {"ja": "日本語モードナリ！", "en": "English mode nari!", "auto": "バイリンガルモードナリ！"}
    try:
        urllib.request.urlopen(
            f"{base}/set?stt_lang={nxt}&llm_lang={nxt}&tts_lang={nxt}", timeout=3).read()
        _txt["lang"] = nxt
        _toast["t"] = "言語: " + names[nxt]
        _toast["until"] = time.time() + 2.5
        urllib.request.urlopen(base + "/say?text=" + urllib.parse.quote(say[nxt]), timeout=3).read()
        print(f"[ctl] 言語切替 → {nxt}")
    except Exception as e:
        print("[ctl] 言語切替失敗:", e)


def _load_jp_font(size=19):
    """日本語フォントを探して読む(RDK=Noto CJK / Windows=メイリオ)。無ければNone=帯を出さない。"""
    import glob as _g
    cands = ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
             "/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc",
             "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc",
             "C:/Windows/Fonts/meiryo.ttc", "C:/Windows/Fonts/YuGothM.ttc"]
    cands += _g.glob("/usr/share/fonts/**/*CJK*.tt[cf]", recursive=True)
    for f in cands:
        try:
            return ImageFont.truetype(f, size)
        except Exception:
            continue
    return None


def text_poller(url):
    """/disptext を0.5秒毎に取得して _txt を更新。失敗時は前値維持。"""
    while True:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                d = json.loads(r.read().decode("utf-8"))
                _txt["heard"] = (d.get("heard") or "").strip()
                _txt["reply"] = (d.get("reply") or "").strip()
                _txt["lang"] = d.get("lang") or _txt["lang"]
        except Exception:
            pass
        time.sleep(0.5)


LANG_LABEL = {"ja": "日本語", "en": "English", "auto": "Auto"}


def overlay_text(canvas):
    """上帯=認識した声(白) / 下帯=返答(黄) / 右下=言語ボタン(常時) を合成。
    ※viewer空間(回転前)で描く。回転はこの後に適用されるので、画面回転時も正立で見える。"""
    heard, reply = _txt["heard"], _txt["reply"]
    toast = _toast["t"] if time.time() < _toast["until"] else ""
    if _FONT is None or Image is None:
        return canvas
    img = Image.fromarray(cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB)).convert("RGBA")
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    W, H = img.size
    LH = _UI["lh"]                           # 1行の高さ(小画面では縮小)
    MAXLINES = 2                             # 認識/返答とも最大2行(超過は…)

    def wrap(text, maxw):
        lines, cur = [], ""
        for ch in text:
            if d.textlength(cur + ch, font=_FONT) > maxw:
                lines.append(cur)
                cur = ch
                if len(lines) == MAXLINES:
                    break
            else:
                cur += ch
        else:
            if cur:
                lines.append(cur)
            return lines
        last = lines[-1]                     # 溢れた: 最終行に…を付ける
        while last and d.textlength(last + "…", font=_FONT) > maxw:
            last = last[:-1]
        lines[-1] = last + "…"
        return lines

    def band(top, text, fill):
        """topがNoneなら下端に配置。行数に応じて帯高さを可変。帯の高さを返す。"""
        ls = wrap(text, W - 10)
        hb = len(ls) * LH + 8
        y0b = 0 if top else H - hb
        d.rectangle([0, y0b, W, y0b + hb], fill=(0, 0, 0, 150))
        for i, t in enumerate(ls):
            d.text((5, y0b + 4 + i * LH), t, font=_FONT, fill=fill)
        return hb

    reply_h = 0
    if heard:
        band(True, heard, (255, 255, 255, 255))
    if reply:
        reply_h = band(False, reply, (255, 224, 110, 255))
    if toast:                                # 画面中央: 言語切替の確認表示
        tw = d.textlength(toast, font=_FONT)
        d.rectangle([(W - tw) / 2 - 14, H / 2 - 20, (W + tw) / 2 + 14, H / 2 + 20],
                    fill=(0, 60, 40, 210))
        d.text(((W - tw) / 2, H / 2 - 11), toast, font=_FONT, fill=(120, 255, 200, 255))
    # 言語ボタン(右下、返答帯の上): タップで ja→en→auto 巡回。--no-button で非表示
    if _UI["btn"]:
        label = "言語: " + LANG_LABEL.get(_txt.get("lang") or "auto", "Auto")
        tw = d.textlength(label, font=_FONT)
        bw, bh2 = int(tw) + 24, LH + 10
        x1, y1 = W - 8, H - reply_h - 8   # 右下(返答帯の高さに追従して上へ避ける)
        x0, y0 = x1 - bw, y1 - bh2
        d.rounded_rectangle([x0, y0, x1, y1], radius=9,
                            fill=(0, 90, 70, 215), outline=(120, 255, 200, 255), width=2)
        d.text((x0 + 12, y0 + 5), label, font=_FONT, fill=(220, 255, 240, 255))
        _btn["rect"] = (x0 - 10, y0 - 10, x1 + 10, y1 + 10)   # ヒット領域(余白+10px)
        _btn["vw"], _btn["vh"] = W, H
    else:
        _btn["rect"] = (-1, -1, -1, -1)   # ヒット無し(タッチ非搭載パネル)
    out = Image.alpha_composite(img, ov).convert("RGB")
    return cv2.cvtColor(np.array(out), cv2.COLOR_RGB2BGR)


def rotate_frame(frame, deg):
    if deg == 90:
        return cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
    if deg == 180:
        return cv2.rotate(frame, cv2.ROTATE_180)
    if deg == 270:
        return cv2.rotate(frame, cv2.ROTATE_90_COUNTERCLOCKWISE)
    return frame


def rotation_poller(url):
    """/dispcfg を1秒毎に取得して _rot を更新(Web設定→即反映)。失敗時は前値維持。"""
    while True:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                c = json.loads(r.read().decode())
                _rot["cam"] = int(c.get("cam_rotate", 0)) % 360
                _rot["disp"] = int(c.get("disp_rotate", 0)) % 360
        except Exception:
            pass
        time.sleep(1.0)


def list_ports_verbose():
    """全シリアルポートを VID:PID 付きで表示。ディスプレイ(CH340 1a86:7523)を明示。"""
    from serial.tools import list_ports
    ports = list(list_ports.comports())
    if not ports:
        print("シリアルポートが見つからない")
        return
    for p in ports:
        vid = f"{p.vid:04x}" if p.vid is not None else "----"
        pid = f"{p.pid:04x}" if p.pid is not None else "----"
        tag = ""
        if (p.vid, p.pid) == (DISPLAY_VID, DISPLAY_PID):
            tag = "  <== DISPLAY (CYD/CH340) ★これを使う"
        elif p.vid == 0x1A86 and p.pid == 0x55D3:
            tag = "  (eyes CH343 — 使わない)"
        elif p.vid == 0x303A:
            tag = "  (eyes native-USB — 使わない)"
        print(f"  {p.device:18} {vid}:{pid}  {p.product or ''}{tag}")


def resolve_port(port):
    """--port auto のとき、CH340(1a86:7523)のディスプレイ基板を自動特定する。
    目基板(1a86:55d3 / 303a:1001)は掴まない。複数/未検出は明示指定を促して停止。"""
    if port and port.lower() != "auto":
        return port
    from serial.tools import list_ports
    cands = [p for p in list_ports.comports()
             if p.vid == DISPLAY_VID and p.pid == DISPLAY_PID]
    others = [(p.device, f"{p.vid:04x}:{p.pid:04x}") for p in list_ports.comports()
              if p.vid is not None and (p.vid, p.pid) != (DISPLAY_VID, DISPLAY_PID)]
    if not cands:
        raise RuntimeError(
            f"ディスプレイ基板(CH340 {DISPLAY_VID:04x}:{DISPLAY_PID:04x})が見つからない。"
            f"他のシリアル: {others}  ※目基板(1a86:55d3 / 303a:1001)は選ばない")
    if len(cands) > 1:
        raise RuntimeError(f"CH340が複数: {[c.device for c in cands]} — --port で1つに絞って")
    print(f"[auto] display board = {cands[0].device} ({DISPLAY_VID:04x}:{DISPLAY_PID:04x})")
    return cands[0].device


def make_test_frame(w, h, i, t0):
    """合成アニメ1枚を返す(BGR)。動く円 + フレーム番号 + 経過秒 + 帯。"""
    img = np.zeros((h, w, 3), np.uint8)
    # 動くグラデーション背景(int32で計算してからuint8へ)
    shift = (i * 3) % 256
    xr = np.linspace(0, 255, w).astype(np.int32)
    img[:, :, 0] = (((xr + shift) % 256).astype(np.uint8))[None, :]    # B
    img[:, :, 1] = (np.linspace(0, 128, h).astype(np.uint8))[:, None]  # G
    img[:, :, 2] = ((255 - xr).astype(np.uint8))[None, :]             # R
    # 弾む円
    cx = int((w - 60) * (0.5 + 0.45 * np.sin(i * 0.08))) + 30
    cy = int((h - 60) * (0.5 + 0.45 * np.cos(i * 0.11))) + 30
    cv2.circle(img, (cx, cy), 26, (0, 255, 255), -1)
    cv2.circle(img, (cx, cy), 26, (0, 0, 0), 2)
    # テキスト
    cv2.rectangle(img, (0, 0), (w, 30), (0, 0, 0), -1)
    cv2.putText(img, "Korosuke USB video test", (6, 22),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2, cv2.LINE_AA)
    el = time.time() - t0
    cv2.putText(img, f"frame {i}  {el:5.1f}s", (6, h - 12),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2, cv2.LINE_AA)
    return img


def frames_from_source(src, w, h):
    """ソースに応じて BGR フレームを無限に yield する。"""
    if src == "test":
        i, t0 = 0, time.time()
        while True:
            yield make_test_frame(w, h, i, t0)
            i += 1
        return

    if src.startswith("cam"):
        idx = int(src.split(":", 1)[1]) if ":" in src else 0
        cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW if sys.platform == "win32" else 0)
    elif src.startswith("mjpeg:"):
        cap = cv2.VideoCapture(src.split(":", 1)[1])
    else:
        cap = cv2.VideoCapture(src)
    if not cap.isOpened():
        sys.exit(f"ソースを開けない: {src}")

    if src.startswith(("cam", "mjpeg")):
        # ライブソース: drop-to-latest。ソース(~20fps)が消費(~4fps)より速いと
        # cv2/ソケットにフレームが溜まり遅延が増え続ける。別スレッドで常に最新だけ保持し、
        # 古いフレームは捨てる → 遅延を1フレーム程度に抑える。
        try:
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)   # ffmpegバッファ最小化(効かない場合あり)
        except Exception:
            pass
        grab = _LatestFrame(cap)
        try:
            while True:
                f = grab.read()
                if f is None:
                    time.sleep(0.003)
                    continue
                yield f
        finally:
            grab.stop = True
    else:
        while True:                               # 動画ファイルは順次(末尾でループ)
            ok, frame = cap.read()
            if not ok:
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                continue
            yield frame


class _LatestFrame:
    """別スレッドでソースを可能な限り速く読み、常に最新の1枚だけ保持する(drop-to-latest)。"""
    def __init__(self, cap):
        self.cap = cap
        self._frame = None
        self._lock = threading.Lock()
        self.stop = False
        self._t = threading.Thread(target=self._run, daemon=True)
        self._t.start()

    def _run(self):
        while not self.stop:
            ok, f = self.cap.read()
            if not ok:
                time.sleep(0.01)
                continue
            with self._lock:
                self._frame = f

    def read(self):
        with self._lock:
            f, self._frame = self._frame, None   # 取ったら消す=同じ古い絵を再送しない
            return f


def fit(frame, w, h):
    """アスペクトを保って中央に収め、w×h の黒背景に貼る(レターボックス)。"""
    fh, fw = frame.shape[:2]
    s = min(w / fw, h / fh)
    nw, nh = max(1, int(fw * s)), max(1, int(fh * s))
    r = cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_AREA)
    canvas = np.zeros((h, w, 3), np.uint8)
    x, y = (w - nw) // 2, (h - nh) // 2
    canvas[y:y + nh, x:x + nw] = r
    return canvas


def drain_esp(ser, buf):
    """ESP32からの受信を処理。ACK(0x06)を受けたら True。テキスト行は表示。"""
    got_ack = False
    n = ser.in_waiting
    if n:
        data = ser.read(n)
        for byte in data:
            if byte == ACK:
                got_ack = True
            elif byte in (0x0A,):    # \n
                line = bytes(buf).decode("ascii", "ignore").strip()
                if line:
                    print("  [esp]", line)
                    if line == "CTL lang":            # 旧ファーム互換: 全面タップ=言語切替
                        threading.Thread(target=cycle_lang, daemon=True).start()
                    elif line.startswith("TOUCH "):   # 新ファーム: 座標→ボタン/お腹判定
                        try:
                            _, sx, sy = line.split()
                            on_touch(int(sx), int(sy))
                        except ValueError:
                            pass
                buf.clear()
            elif byte != 0x0D:
                buf.append(byte)
    return got_ack


def open_serial(port_arg, baud, first=False):
    """ポートを(再)解決して開く。見つからない/開けない間はリトライし続ける
    = USB切断→再接続に対応。auto なら都度VID/PIDで再解決するので ttyUSB 番号が変わっても追従。"""
    delay = 0.5
    while True:
        try:
            port = resolve_port(port_arg)
            ser = serial.Serial(port, baud, timeout=0, write_timeout=2)  # write_timeout: ESP32ハング時に例外→再接続(DTRリセット)で自動復旧
            time.sleep(2.0)                    # ESP32リセット待ち(開くとDTR/RTSで再起動)
            ser.reset_input_buffer()
            print(f"[usb] {'接続' if first else '再接続'}: {port}")
            return ser
        except Exception as e:                 # 未検出/デバイスビジー/オープン失敗 → 待って再試行
            print(f"[usb] 接続待ち... ({e})")
            time.sleep(delay)
            delay = min(delay * 1.5, 3.0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="auto",
                    help="COM16 / /dev/ttyUSB0、または 'auto'(CH340 1a86:7523 を自動選別)")
    ap.add_argument("--baud", type=int, default=2000000)
    ap.add_argument("--source", default="test")
    ap.add_argument("--width", type=int, default=480)
    ap.add_argument("--height", type=int, default=272)
    ap.add_argument("--quality", type=int, default=60, help="JPEG品質 1-100")
    ap.add_argument("--fps", type=float, default=30, help="送信上限FPS")
    ap.add_argument("--duration", type=float, default=0, help="秒(0=無限)")
    ap.add_argument("--ack-timeout", type=float, default=0.8)
    ap.add_argument("--list", action="store_true", help="シリアルポート一覧を表示して終了")
    ap.add_argument("--rotate-cfg-url", default="",
                    help="回転設定JSONのURL(空ならmjpegソースから /dispcfg を自動導出)")
    ap.add_argument("--no-button", action="store_true",
                    help="言語ボタンを描かない(ESP32-1732S019などタッチ無しパネル用)")
    args = ap.parse_args()

    _UI["btn"] = not args.no_button
    if args.height < 220:                 # 小画面(1732S019=170px高)は帯を細く
        _UI["lh"] = 19

    if args.list:
        list_ports_verbose()
        return

    ser = open_serial(args.port, args.baud, first=True)

    cfg_url = args.rotate_cfg_url
    if not cfg_url and args.source.startswith("mjpeg:"):
        base = args.source.split(":", 1)[1].rsplit("/", 1)[0]   # http://host:port
        cfg_url = base + "/dispcfg"
    if cfg_url:
        threading.Thread(target=rotation_poller, args=(cfg_url,), daemon=True).start()
        print(f"回転設定ポーリング: {cfg_url}")
        # 同じホストの /disptext から認識テキスト+返答を取得して帯表示
        global _FONT
        _FONT = _load_jp_font(19 if args.height >= 220 else 14)
        _ctl["base"] = cfg_url.rsplit("/", 1)[0]
        txt_url = _ctl["base"] + "/disptext"
        threading.Thread(target=text_poller, args=(txt_url,), daemon=True).start()
        print(f"テキストポーリング: {txt_url}  (font={'OK' if _FONT else '無し→帯なし'})")

    w, h, q = args.width, args.height, args.quality
    enc = [int(cv2.IMWRITE_JPEG_QUALITY), q]
    min_dt = 1.0 / args.fps if args.fps > 0 else 0
    buf = bytearray()
    n, acc, t_stat, t_start = 0, 0, time.time(), time.time()
    print(f"送信開始: port={args.port} baud={args.baud} src={args.source} "
          f"{w}x{h} q={q}  (Ctrl+C で停止)")

    try:
        for frame in frames_from_source(args.source, w, h):
            t = time.time()
            cam_r, disp_r = _rot["cam"] % 360, _rot["disp"] % 360
            if cam_r:
                frame = rotate_frame(frame, cam_r)      # カメラ向き補正
            vw, vh = (h, w) if disp_r in (90, 270) else (w, h)
            canvas = fit(frame, vw, vh)                 # viewer空間(回転前)に配置
            canvas = overlay_text(canvas)               # 帯+言語ボタン(正立で描く)
            if disp_r:
                canvas = rotate_frame(canvas, disp_r)   # パネル空間へ回転(帯ごと回る=見た目は正立)
            ok, jpg = cv2.imencode(".jpg", canvas, enc)
            if not ok:
                continue
            data = jpg.tobytes()
            try:
                ser.write(MAGIC + struct.pack("<I", len(data)) + data)
                # ACK待ち(フロー制御)
                t_ack = time.time()
                while not drain_esp(ser, buf):
                    if time.time() - t_ack > args.ack_timeout:
                        break                          # ACK落ちは1枚スキップ(切断とは別)
                    time.sleep(0.001)
            except (serial.SerialException, OSError) as e:
                print(f"[usb] 切断検知 → 再接続します ({e})")
                try:
                    ser.close()
                except Exception:
                    pass
                buf.clear()
                ser = open_serial(args.port, args.baud, first=False)  # 復帰まで待って再開
                continue

            n += 1
            acc += len(data)
            now = time.time()
            if now - t_stat >= 1.0:
                print(f"  send fps={n / (now - t_stat):.1f}  "
                      f"avg={acc / n / 1024:.1f}KB  q={q}")
                n, acc, t_stat = 0, 0, now
            if args.duration and now - t_start > args.duration:
                break
            dt = time.time() - t
            if min_dt and dt < min_dt:
                time.sleep(min_dt - dt)
    except KeyboardInterrupt:
        print("\n停止")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
