#!/usr/bin/env python3
"""STT比較ハーネス: vosk small-ja vs kotoba-whisper-v2.0-faster
正解テキスト付き評価セット(~/corosuke/eval/*.wav + refs.json)で CER と RTF を比較。
使い方: python3 eval_stt.py [--only vosk|kotoba]
"""
import json
import os
import sys
import time
import unicodedata
import wave

EVAL_DIR = "/home/sunrise/corosuke/eval"


def norm(s):
    s = unicodedata.normalize("NFKC", s)
    return "".join(c for c in s if c.isalnum())   # 記号・空白を除去して文字だけ比較


def cer(ref, hyp):
    r, h = norm(ref), norm(hyp)
    if not r:
        return 0.0
    d = [[0] * (len(h) + 1) for _ in range(len(r) + 1)]
    for i in range(len(r) + 1):
        d[i][0] = i
    for j in range(len(h) + 1):
        d[0][j] = j
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                          d[i - 1][j - 1] + (0 if r[i - 1] == h[j - 1] else 1))
    return d[len(r)][len(h)] / len(r)


def wav_duration(path):
    w = wave.open(path)
    try:
        return w.getnframes() / w.getframerate()
    finally:
        w.close()


def run_vosk(files):
    from vosk import Model, KaldiRecognizer, SetLogLevel
    SetLogLevel(-1)
    t0 = time.time()
    model = Model("/home/sunrise/models/vosk-model-small-ja-0.22")
    load_s = time.time() - t0
    out = {}
    for p in files:
        rec = KaldiRecognizer(model, 16000)
        w = wave.open(p)
        assert w.getframerate() == 16000 and w.getnchannels() == 1
        t1 = time.time()
        text = []
        while True:
            data = w.readframes(4000)
            if not data:
                break
            if rec.AcceptWaveform(data):
                t = json.loads(rec.Result()).get("text", "")
                if t:
                    text.append(t)
        t = json.loads(rec.FinalResult()).get("text", "")
        if t:
            text.append(t)
        out[p] = ("".join(text).replace(" ", ""), time.time() - t1)
        w.close()
    return "vosk small-ja", load_s, out


def run_kotoba(files):
    from faster_whisper import WhisperModel
    t0 = time.time()
    model = WhisperModel("kotoba-tech/kotoba-whisper-v2.0-faster",
                         device="cpu", compute_type="int8", cpu_threads=8)
    load_s = time.time() - t0
    out = {}
    for p in files:
        t1 = time.time()
        segments, info = model.transcribe(p, language="ja", beam_size=1,
                                          without_timestamps=True, vad_filter=False)
        text = "".join(seg.text for seg in segments)
        out[p] = (text.strip(), time.time() - t1)
    return "kotoba-whisper-v2.0-faster(int8)", load_s, out


def run_sherpa(files):
    import array
    import glob as g

    import sherpa_onnx
    d = glob_one("/home/sunrise/models/sherpa-onnx-zipformer-ja-reazonspeech*")
    t0 = time.time()
    rec = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=glob_one(d + "/encoder*int8.onnx"),
        decoder=glob_one(d + "/decoder*[!8].onnx"),   # decoderはfp32推奨
        joiner=glob_one(d + "/joiner*int8.onnx"),
        tokens=d + "/tokens.txt", num_threads=8)
    load_s = time.time() - t0
    out = {}
    for p in files:
        t1 = time.time()
        w = wave.open(p)
        data = w.readframes(w.getnframes())
        rate = w.getframerate()
        w.close()
        samples = array.array("h", data)
        st = rec.create_stream()
        st.accept_waveform(rate, [x / 32768.0 for x in samples])
        rec.decode_stream(st)
        out[p] = (st.result.text.strip(), time.time() - t1)
    return "sherpa-onnx zipformer-ja-reazonspeech(int8)", load_s, out


def run_sherpa_vad(files):
    """本命構成: Silero VADで区間分割→区間ごとにデコード(推奨アーキテクチャの再現)"""
    import array

    import sherpa_onnx
    d = glob_one("/home/sunrise/models/sherpa-onnx-zipformer-ja-reazonspeech*")
    vad_model = "/home/sunrise/models/silero_vad.onnx"
    t0 = time.time()
    rec = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=glob_one(d + "/encoder*int8.onnx"),
        decoder=glob_one(d + "/decoder*[!8].onnx"),
        joiner=glob_one(d + "/joiner*int8.onnx"),
        tokens=d + "/tokens.txt", num_threads=8)
    load_s = time.time() - t0
    out = {}
    for p in files:
        t1 = time.time()
        w = wave.open(p)
        data = w.readframes(w.getnframes())
        w.close()
        samples = [x / 32768.0 for x in array.array("h", data)]
        vcfg = sherpa_onnx.VadModelConfig()
        vcfg.silero_vad.model = vad_model
        vcfg.silero_vad.threshold = 0.25          # 緩め(語頭欠け対策)
        vcfg.silero_vad.min_silence_duration = 0.5  # 文中の短ポーズで切らない
        vcfg.silero_vad.min_speech_duration = 0.2
        vcfg.sample_rate = 16000
        vad = sherpa_onnx.VoiceActivityDetector(vcfg, buffer_size_in_seconds=60)
        win = vcfg.silero_vad.window_size
        PAD = int(0.3 * 16000)                     # 区間の前後に0.3秒パディング

        def decode_segment(seg):
            a = max(0, seg.start - PAD)
            b = min(len(samples), seg.start + len(seg.samples) + PAD)
            st = rec.create_stream()
            st.accept_waveform(16000, samples[a:b])
            rec.decode_stream(st)
            return st.result.text.strip()

        texts = []
        i = 0
        while i < len(samples):
            vad.accept_waveform(samples[i:i + win])
            i += win
            while not vad.empty():
                t = decode_segment(vad.front)
                if t:
                    texts.append(t)
                vad.pop()
        vad.flush()
        while not vad.empty():
            t = decode_segment(vad.front)
            if t:
                texts.append(t)
            vad.pop()
        out[p] = ("".join(texts), time.time() - t1)
    return "sherpa-onnx zipformer-ja + SileroVAD(int8)", load_s, out


def glob_one(pat):
    import glob as g
    m = sorted(g.glob(pat))
    if not m:
        raise SystemExit(f"not found: {pat}")
    return m[0]


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    refs = json.load(open(os.path.join(EVAL_DIR, "refs.json"), encoding="utf-8"))
    files = sorted(os.path.join(EVAL_DIR, k + ".wav") for k in refs)
    runners = {"vosk": run_vosk, "kotoba": run_kotoba, "sherpa": run_sherpa,
               "sherpa_vad": run_sherpa_vad}
    for key, fn in runners.items():
        if only and key != only:
            continue
        name, load_s, out = fn(files)
        print(f"\n===== {name} (ロード {load_s:.1f}s) =====")
        tot_cer, tot_dt, tot_dur = [], 0.0, 0.0
        for p in files:
            k = os.path.basename(p)[:-4]
            hyp, dt = out[p]
            dur = wav_duration(p)
            c = cer(refs[k], hyp)
            tot_cer.append(c)
            tot_dt += dt
            tot_dur += dur
            print(f"  {k}: CER {c*100:5.1f}%  RTF {dt/dur:5.2f}  「{hyp}」")
        print(f"  --- 平均CER {sum(tot_cer)/len(tot_cer)*100:.1f}% / 全体RTF {tot_dt/tot_dur:.2f}")


if __name__ == "__main__":
    main()
