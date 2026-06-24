# Project Korosuke — Stage 1 (Ignite): "Power On Your AI Robot's Brain"

Stage 1 write-up for the **D-Robotics Robotics Dream Keeper Challenge**.
Goal: go from first powering an **RDK X5 (8GB)** to running an on-device AI task.

**Board:** D-Robotics RDK X5 8GB · Sunrise X5 SoC · 10 TOPS BPU · Ubuntu 22.04 (RDK OS 3.5.0) · aarch64
**Hostname:** `korosuke`

---

## Challenge 1 — Wake the board

### 1. Flash the OS
- Image: **RDK OS 3.5.0** (Ubuntu 22.04 Desktop, RDK X5), written to a microSD card.
- Tool: **Raspberry Pi Imager** (Etcher failed mid-write on this machine; Imager succeeded).
- Verified the download integrity by MD5 before flashing (`b39cd58ab65e838929063e4f1e184d0b`).

### 2. Network
- Connected over **Wi-Fi**; board obtained `192.168.0.138` on the LAN.
- Connectivity check:
  ```bash
  ping -c3 8.8.8.8
  curl -sI https://archive.d-robotics.cc | head -1
  ```

### 3. SSH login
```bash
# password login (default user/pass: sunrise / sunrise)
ssh sunrise@192.168.0.138

# key-based login (after copying a public key)
ssh-copy-id -i ~/.ssh/id_ed25519_robosta.pub sunrise@192.168.0.138
ssh -i ~/.ssh/id_ed25519_robosta sunrise@192.168.0.138
uname -a    # Linux korosuke 6.1.83 ... aarch64
```

### 4. Board bring-up / optimization
- Timezone → `Asia/Tokyo`, hostname → `korosuke`.
- Connected the board to the **RDK Studio** desktop app (device shows *online · SSH verified*).
- Verified the BPU is healthy: `/dev/bpu`, `/dev/bpu_core0`, `/dev/ion` present; `sudo hrut_somstatus` reports BPU/CPU/DDR temps and frequencies.

### 5. Community
- Joined the official Discord and posted an introduction / Stage 1 thread.

---

## Challenge 2 — Sensor Explorer (USB camera)

A generic **UVC USB camera** (`USB Composite Device: DV20 USB`, USB ID `4c4a:4a55`) is
recognized out of the box by the `uvcvideo` driver as `/dev/video0`.

```bash
# enumerate
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext   # MJPG/YUYV 640x480@30fps

# capture a single preview frame (discard warm-up frames first)
python3 - <<'PY'
import cv2, time
cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640); cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
for _ in range(12): ok, f = cap.read(); time.sleep(0.04)   # UVC warm-up
cv2.imwrite("/tmp/cam_preview.jpg", f)
PY
```

**Interface:** USB / V4L2 (`uvcvideo`) · **Evidence:** [`docs/stage1_evidence/B_camera_preview.jpg`](docs/stage1_evidence/B_camera_preview.jpg)

---

## Challenge 3 — First AI Task (YOLO11 object detection on the BPU)

The board ships with the D-Robotics demo suite at `/app/pydev_demo/` including
pre-compiled BPU models (`.bin`) for YOLO11 / v8 / v10 / v5.

### Static image (sanity check)
```bash
cd /app/pydev_demo/02_detection_sample/02_ultralytics_yolo11
python3 ultralytics_yolo11.py --img-save-path /tmp/yolo_result.jpg
# -> draws person/kite boxes on kite.jpg, ~3 s including model load
```

### Live USB camera → BPU → detection
A small script reuses the sample's `YoloV11` runtime wrapper
(`hbm_runtime.HB_HBMRuntime`) and feeds it live camera frames:

```bash
cd /app/pydev_demo/02_detection_sample/02_ultralytics_yolo11
python3 cam_yolo.py   # see scripts/cam_yolo.py in this repo
```

- Model: `yolo11n_detect_bayese_640x640_nv12.bin` (YOLO11-nano, Bayes-e quantized for RDK X5).
- Pipeline: `pre_process()` → NV12 → `forward()` on **BPU core 0** → `post_process()` (dequant + NMS).
- Measured **~8.3 FPS** end-to-end (USB capture + MJPG decode + BPU inference + draw);
  capture/decode is the bottleneck, BPU inference alone is faster.
- Live detections in the workspace: `person 0.94`, `laptop 0.50`, `backpack 0.56`, `chair`, `suitcase`.

**On-device (not on a PC).** **Evidence:** [`docs/stage1_evidence/C_yolo_live_detection.jpg`](docs/stage1_evidence/C_yolo_live_detection.jpg)

---

## Thermals (why this matters for a robot)

Passive (no case lid, no fan) the board idled at **~66 °C** (DDR/BPU/CPU).
Adding a 5 V 40 mm fan powered from the **40-pin header (pin 4 = 5V, pin 6 = GND)**
dropped it to **~45–49 °C** — important headroom before running YOLO under load.
A purpose-built fan lid is part of the open-source case below.

---

## Dependencies

All pre-installed on RDK OS 3.5.0 — nothing extra to `pip install` for this stage:

| Component | Notes |
|-----------|-------|
| `hobot_dnn` / `hbm_runtime` | D-Robotics BPU runtime (Python) |
| `python3` (3.10) + `opencv-python` (`cv2`) | capture + drawing |
| `v4l2-utils` (`v4l2-ctl`) | camera enumeration |
| `hrut_somstatus` | board temp / freq telemetry |
| Demo suite | `/app/pydev_demo/` (ships with the OS image) |

---

## Related open-source output

As a by-product of this stage I designed and published the **first open-source
3D-printable case for the RDK X5** (one base + closed / open / VESA / **fan** lids),
fully parametric OpenSCAD: **https://github.com/gurimaruking/rdk-x5-modular-case** (CC BY 4.0).
