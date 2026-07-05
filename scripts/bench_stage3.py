#!/usr/bin/env python3
"""
Stage 3 ベンチマーク計測 — RDK X5 上で実行。
  1) BPU単体の推論レート (YOLO11n, カメラ非依存)
  2) ライブ (capture+BPU+post) の end-to-end FPS と 1フレーム遅延
  3) 実行前後の温度 (hrut_somstatus)
出力を Stage 3 のベンチ表にそのまま貼れる形で表示する。

  python3 bench_stage3.py            # 既定 200 推論 / 100 フレーム
"""
import os
import sys
import time
import subprocess
import importlib.util
from types import SimpleNamespace

import cv2
import numpy as np

YOLO_DIR = '/app/pydev_demo/02_detection_sample/02_ultralytics_yolo11'
MODEL = 'yolo11n_detect_bayese_640x640_nv12.bin'


def thermal():
    try:
        out = subprocess.run(['hrut_somstatus'], capture_output=True, text=True, timeout=5).stdout
        temps = {}
        for line in out.splitlines():
            l = line.strip()
            for key in ('CPU', 'BPU', 'DDR'):
                if l.startswith(key) and ':' in l:
                    try:
                        temps[key] = float(l.split(':')[1].split()[0])
                    except (ValueError, IndexError):
                        pass
        return temps
    except Exception as e:  # noqa
        return {'err': str(e)}


def main():
    n_inf = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    n_live = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    os.chdir(YOLO_DIR)
    sys.path.append(os.path.abspath('../..'))
    spec = importlib.util.spec_from_file_location('uy', 'ultralytics_yolo11.py')
    uy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(uy)
    opt = SimpleNamespace(model_path=MODEL, priority=0, bpu_cores=[0],
                          nms_thres=0.45, score_thres=0.35)
    y = uy.YoloV11(opt)
    y.set_scheduling_params(priority=0, bpu_cores=[0])

    t_before = thermal()

    # 1) BPU単体レート — 同一フレームを繰り返し推論(cap/decode除外)
    dummy = np.zeros((480, 640, 3), dtype=np.uint8)
    pre = y.pre_process(dummy)
    y.forward(pre)  # warmup
    t0 = time.time()
    for _ in range(n_inf):
        y.forward(pre)
    bpu_fps = n_inf / (time.time() - t0)

    # 2) ライブ end-to-end
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    for _ in range(10):
        cap.read()
    lat = []
    t0 = time.time()
    got = 0
    for _ in range(n_live):
        ok, frame = cap.read()
        if not ok:
            continue
        h, w = frame.shape[:2]
        ts = time.time()
        out = y.forward(y.pre_process(frame))
        y.post_process(out, w, h)
        lat.append((time.time() - ts) * 1000.0)
        got += 1
    live_fps = got / (time.time() - t0)
    cap.release()
    t_after = thermal()

    lat = sorted(lat)
    p50 = lat[len(lat) // 2] if lat else 0
    p95 = lat[int(len(lat) * 0.95)] if lat else 0

    print('\n========== Korosuke Stage 3 Benchmark (RDK X5) ==========')
    print(f'| Metric                         | Value            |')
    print(f'|--------------------------------|------------------|')
    print(f'| BPU YOLO11n inference rate     | {bpu_fps:6.1f} inf/s    |')
    print(f'| Live end-to-end (cap+BPU+post) | {live_fps:6.1f} FPS      |')
    print(f'| Inference latency p50 / p95    | {p50:4.1f} / {p95:4.1f} ms |')
    print(f'| Thermal before (CPU/BPU/DDR)   | {t_before} |')
    print(f'| Thermal after  (CPU/BPU/DDR)   | {t_after} |')
    print('=========================================================')


if __name__ == '__main__':
    main()
