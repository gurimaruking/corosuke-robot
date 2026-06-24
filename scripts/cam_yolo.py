import os, sys, time, cv2, numpy as np
from types import SimpleNamespace
import importlib.util
sys.path.append(os.path.abspath("../.."))           # utils package
spec = importlib.util.spec_from_file_location("uy", "ultralytics_yolo11.py")
uy = importlib.util.module_from_spec(spec); spec.loader.exec_module(uy)
import utils.common_utils as common
import utils.draw_utils as draw

opt = SimpleNamespace(model_path="yolo11n_detect_bayese_640x640_nv12.bin",
                      priority=0, bpu_cores=[0], nms_thres=0.45, score_thres=0.25)
y = uy.YoloV11(opt)
y.set_scheduling_params(priority=0, bpu_cores=[0])
names = common.load_class_names("coco_classes.names")

cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640); cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
for _ in range(10): cap.read()

N=30; last=None; t0=time.time()
for i in range(N):
    ok, frame = cap.read()
    if not ok: continue
    h,w = frame.shape[:2]
    out = y.forward(y.pre_process(frame))
    boxes, cls, sc = y.post_process(out, w, h)
    last = draw.draw_boxes(frame, boxes, cls, sc, names, common.rdk_colors)
dt=time.time()-t0
print("LIVE FPS (cap+BPU+draw): %.1f  over %d frames" % (N/dt, N))
print("last-frame detections:", len(boxes))
for b,c,s in zip(boxes, cls, sc): print("  %-12s %.2f" % (names[int(c)], s))
cv2.imwrite("/tmp/cam_yolo.jpg", last)
cap.release()
