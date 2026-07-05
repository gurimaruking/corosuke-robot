#!/usr/bin/env python3
"""
vision_node — RDK X5 の BPU で YOLO11n を回して「人」を検出し、
一番大きい人の画面内位置を /korosuke/face_pose (FacePose) に publish する。

Stage 1 で実証済みの手順(scripts/cam_yolo.py)をそのままノード化:
  YoloV11.pre_process → forward(BPU) → post_process → boxes/cls/score
人は COCO class 0。names ファイルには依存しない。

パラメータ:
  yolo_dir    BPUサンプルのYOLO11ディレクトリ(モデル.bin/ultralytics_yolo11.py がある)
  camera      /dev/videoN の N (default 0)
  rate        publish 上限 FPS (default 10 — 目標G1に一致)
  score_thres, nms_thres
BPU/モデルのロードに失敗したら OpenCV の顔検出にフォールバックし、
パイプライン自体は動かし続ける(デモが止まらない)。
"""
import os
import sys
import time
import threading
import importlib.util
from types import SimpleNamespace

import cv2
import rclpy
from rclpy.node import Node
from korosuke_msgs.msg import FacePose

DEFAULT_YOLO_DIR = '/app/pydev_demo/02_detection_sample/02_ultralytics_yolo11'
MODEL_BIN = 'yolo11n_detect_bayese_640x640_nv12.bin'


class Vision(Node):
    def __init__(self):
        super().__init__('vision_node')
        self.declare_parameter('yolo_dir', DEFAULT_YOLO_DIR)
        self.declare_parameter('camera', 0)
        self.declare_parameter('rate', 10.0)
        self.declare_parameter('score_thres', 0.35)
        self.declare_parameter('nms_thres', 0.45)
        self.pub = self.create_publisher(FacePose, '/korosuke/face_pose', 10)

        self._yolo = None
        self._haar = None
        self._init_detector()

        self._stop = False
        self._t = threading.Thread(target=self._loop, daemon=True)
        self._t.start()

    # ---- 検出器初期化(BPU YOLO 優先、失敗で Haar) ----
    def _init_detector(self):
        ydir = self.get_parameter('yolo_dir').value
        try:
            os.chdir(ydir)
            sys.path.append(os.path.abspath('../..'))       # utils パッケージ
            spec = importlib.util.spec_from_file_location('uy', 'ultralytics_yolo11.py')
            uy = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(uy)
            opt = SimpleNamespace(
                model_path=MODEL_BIN, priority=0, bpu_cores=[0],
                nms_thres=float(self.get_parameter('nms_thres').value),
                score_thres=float(self.get_parameter('score_thres').value))
            self._yolo = uy.YoloV11(opt)
            self._yolo.set_scheduling_params(priority=0, bpu_cores=[0])
            self.get_logger().info(f'BPU YOLO11n ロード成功 ({ydir})')
        except Exception as e:  # noqa
            self.get_logger().warn(f'BPU YOLO ロード失敗→Haar顔検出にフォールバック: {e}')
            cascade = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
            self._haar = cv2.CascadeClassifier(cascade)

    def _open_cam(self):
        n = int(self.get_parameter('camera').value)
        cap = cv2.VideoCapture(n, cv2.CAP_V4L2)
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        for _ in range(10):
            cap.read()
        return cap

    # ---- 推論ループ(別スレッド) ----
    def _loop(self):
        cap = self._open_cam()
        if not cap or not cap.isOpened():
            self.get_logger().error('カメラを開けない')
            return
        min_dt = 1.0 / max(1.0, float(self.get_parameter('rate').value))
        fps_t0, fps_n = time.time(), 0
        while rclpy.ok() and not self._stop:
            t = time.time()
            ok, frame = cap.read()
            if not ok:
                continue
            h, w = frame.shape[:2]
            box = self._detect_person(frame, w, h)
            self._publish(box, w, h)
            fps_n += 1
            if time.time() - fps_t0 >= 5.0:
                self.get_logger().info(f'vision {fps_n / (time.time() - fps_t0):.1f} FPS '
                                       f'({"BPU" if self._yolo else "Haar"})')
                fps_t0, fps_n = time.time(), 0
            dt = time.time() - t
            if dt < min_dt:
                time.sleep(min_dt - dt)
        cap.release()

    def _detect_person(self, frame, w, h):
        """最大の人/顔の bbox [x1,y1,x2,y2] を返す。無ければ None。"""
        if self._yolo is not None:
            try:
                out = self._yolo.forward(self._yolo.pre_process(frame))
                boxes, cls, sc = self._yolo.post_process(out, w, h)
                best, area = None, 0
                for b, c in zip(boxes, cls):
                    if int(c) != 0:            # 0 = person
                        continue
                    x1, y1, x2, y2 = b[:4]
                    a = (x2 - x1) * (y2 - y1)
                    if a > area:
                        area, best = a, (x1, y1, x2, y2)
                return best
            except Exception as e:  # noqa
                self.get_logger().warn(f'YOLO推論失敗: {e}', throttle_duration_sec=10)
                return None
        # Haar フォールバック
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = self._haar.detectMultiScale(gray, 1.2, 5, minSize=(60, 60))
        if len(faces) == 0:
            return None
        x, y, fw, fh = max(faces, key=lambda r: r[2] * r[3])
        return (x, y, x + fw, y + fh)

    def _publish(self, box, w, h):
        m = FacePose()
        if box is None:
            m.detected = False
        else:
            x1, y1, x2, y2 = box
            cx, cy = (x1 + x2) / 2.0, (y1 + y2) / 2.0
            m.detected = True
            m.x = float(cx / w * 2.0 - 1.0)      # -1..1 (右+)
            m.y = float(cy / h * 2.0 - 1.0)      # -1..1 (下+)
            m.size = float((y2 - y1) / h)        # 高さ比 = 近さの目安
        self.pub.publish(m)

    def destroy_node(self):
        self._stop = True
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = Vision()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
