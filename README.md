# 🤖 Korosuke Robot / コロ助ロボット

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Brain: RDK X5](https://img.shields.io/badge/Brain-RDK%20X5%20·%2010%20TOPS%20BPU-e8491d.svg)](https://developer.d-robotics.cc/)
[![ROS 2](https://img.shields.io/badge/ROS-2-22314e.svg)](https://docs.ros.org/)
[![Sub-MCU: ESP32-S3](https://img.shields.io/badge/Sub--MCU-ESP32--S3-blue.svg)](https://www.espressif.com/)
[![On-device](https://img.shields.io/badge/AI-100%25%20on--device%20·%20no%20cloud-2da44e.svg)](STAGE3.md)

A ~46 cm open-source animatronic of **Korosuke (コロ助)** from *Kiteretsu Daihyakka* that
**sees, listens, thinks, talks (in Japanese *or* English), emotes, reacts to gestures,
and shuts itself down safely — 100 % on-device** on a **D-Robotics RDK X5**, with an
ESP32-S3 driving the eyes and arms.

> 🏆 **D-Robotics Robotics Dream Keeper Challenge** — **Stage 3 (Launch)**.
> 📄 Full showcase & benchmarks: **[STAGE3.md](STAGE3.md)** · 🧩 Design: [PROPOSAL.md](PROPOSAL.md) · 🗺 [ROADMAP.md](ROADMAP.md)
> 🎥 Demo: **[10 s on-device conversation](docs/photo/20260725_korosuke-robot-v0.1_movie.mp4)** *(full 3–7 min video: link TBA)*

![Korosuke — assembled, smiling](docs/photo/20260725_korosuke-robot-revision_0.1.jpg)

---

## What it does

Power it on and, unattended: **wakes up & greets you** ("おはようナリ！") → **sees & tracks
you** (BPU YOLO11-pose) → **talks with you** (on-device STT → LLM → TTS, with a "thinking"
eye animation while it ponders) → **reacts to gestures** → **waves its arms** →
**shuts down safely** on a button press (goodnight voice → ✕✕ "safe-to-unplug" eyes).
A tabbed **web dashboard** (`http://<board-ip>:8080`) shows the live camera+skeleton and
lets you tune everything.

| Subsystem | Implementation | Measured |
|---|---|---|
| Vision | BPU YOLO11n-pose (Bayes-e `.bin`) | ~19.5 FPS |
| Speech-to-text | sherpa-onnx **SenseVoice** (multilingual JP/EN) + Silero VAD | real-time (CPU) |
| LLM dialogue | llama.cpp + TinySwallow-1.5B *(Qwen2.5-1.5B-based)* (CPU) — **JP & EN** personas | 1.5–3.3 tok/s |
| Text-to-speech | **JP** Open JTalk / **EN** espeak-ng (pitched childlike voice) | instant |
| **Language** | **日本語 / English** — STT · LLM · TTS · Web UI all switchable, on the fly | on-device |
| Audio out | **MAX98357A I2S amp** (custom kernel driver) → φ50 speaker | DSP-tuned |
| Eyes | 2× GC9A01 on ESP32-S3 — 8 emotions incl. smile / thinking / ✕✕ | ≥30 FPS |
| Arms | 2× SG90 rope-pull bellows arms | auto-detach |

> 🌐 **Bilingual & fully on-device.** One button switches the whole robot — speech
> recognition, LLM replies, voice, *and* the dashboard — between **Japanese and English**,
> with **no cloud and no API keys**. The web dashboard shows the live AI stack in use
> (LLM / persona / STT / TTS).
>
> 🔗 The on-device voice stack follows **D-Robotics' own RDK
> [voice-interaction reference](https://developer.d-robotics.cc/magicbox_doc/en/algorithm-development/voice-interaction)**
> — **SenseVoice** ASR (sherpa-onnx) + a **Qwen2.5-1.5B-family** LLM (we run the Japanese-tuned
> **TinySwallow-1.5B**, built on Qwen2.5-1.5B, via llama.cpp on CPU).

## Challenge journey — Stage 1 → 2 → 3

Korosuke was built up across the three challenge stages, each reusing the last:

| Stage | Theme | What was proven | Doc |
|---|---|---|---|
| **1 — Ideation** | On-device perception | YOLO11 vision running **on the RDK X5 BPU** (+ the open-source [RDK X5 case](https://github.com/gurimaruking/rdk-x5-modular-case)) | [STAGE1.md](STAGE1.md) |
| **2 — Build** | System design | Re-wire to the **RDK X5 as the single cognitive core** under a **ROS 2 graph**; ESP32s become actuator sub-controllers | [PROPOSAL.md](PROPOSAL.md) |
| **3 — Launch** | Shipped robot | The full interactive Korosuke — sees/listens/thinks/talks/emotes, **bilingual JP/EN**, 100 % on-device (this repo) | [STAGE3.md](STAGE3.md) |

Stage 1's proven BPU vision is still the perception layer today; Stage 2's ROS 2 design is
shipped as [`ros2_ws/`](ros2_ws/) alongside the low-latency monolith. **Each stage builds
directly on the previous — re-wiring, not re-inventing.**

### Not (yet) implemented — honest scope

These were proposed in the design but are **not in this build** (not claimed as done):

| Planned feature | Status |
|---|---|
| 2-axis mouth / lip-sync | ❌ deferred — no mouth mechanism; expression is via the **eyes + voice** |
| Neck servo (head turn) | ❌ deferred — face tracking is **eyes-only** (no neck actuator) |
| Bipedal "penguin" walking (QDD legs) | ✴️ stretch only — salvaged QDD motors unreliable; MVP is seated/standing |
| Back-mounted sword prop | ❌ not built |

## Quick Start (on the RDK X5)

> All on-device. **No cloud, no API keys.** Perception on the BPU, dialogue on the CPU.

```bash
# 1) Clone
git clone https://github.com/gurimaruking/corosuke-robot.git && cd corosuke-robot

# 2) Flash the eye/arm co-MCU (ESP32-S3) — from the RDK X5 (uses the CH343 UART port)
cd firmware/corosuke_eyes && pio run -t upload && cd ../..

# 3) One-time: MAX98357A I2S amp — build the out-of-tree codec driver + device-tree overlay
#    Follow docs/rdk_x5_40pin_i2s_max98357a.md  (kernel headers are already on the board)

# 4a) Run the INTEGRATED demo (monolithic, low-latency) as a systemd service
sudo cp deploy/*.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now korosuke-monitor korosuke-shutdown-btn
#     → open  http://<board-ip>:8080   (Monitor / Settings tabs)

# 4b) — or — run the MODULAR ROS 2 graph (same on-device stack: TinySwallow + Open JTalk, no cloud)
cd ros2_ws && colcon build && source install/setup.bash
ros2 launch korosuke_nodes korosuke.launch.py         # vision → brain → eyes / dialogue → voice
ros2 launch korosuke_nodes korosuke.launch.py with_web:=true   # + rosbridge :9090 → open web/console.html
#   NB: eye path is HW-verified; full graph is code-complete but not yet run end-to-end (see STAGE3 §5.1)

# Safe shutdown:  hold the GPIO button ~1 s  → goodnight voice → ✕✕ eyes → OS halt → cut power.
```

**Models** (STT / LLM / YOLO `.bin`) are downloaded on the board — see
[docs/stt_research.md](docs/stt_research.md), [docs/dialogue_stack_research.md](docs/dialogue_stack_research.md).
The LLM stays on the CPU **by design** — the X5 BPU cannot accelerate LLMs
([docs/rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md)).

## Repository layout

```
corosuke-robot/
├── STAGE3.md, PROPOSAL.md, ROADMAP.md   # showcase / Stage-2 design / roadmap
├── scripts/            # korosuke_monitor.py (integrated demo) · shutdown_button.py · fix_max98357a.sh
├── ros2_ws/            # ROS 2 graph: korosuke_msgs + korosuke_nodes (vision/brain/dialogue/voice/serial_bridge)
├── firmware/           # ESP32-S3 (PlatformIO): corosuke_eyes (eyes+arms+touch) · max98357a (I2S driver)
├── deploy/             # systemd units + sudoers (auto-start, safe shutdown, audio self-heal)
├── hardware/3d_models/ # OpenSCAD body (color-split) + RDK X5 modular case
└── docs/               # architecture, audio(I2S), BPU-LLM, network, power/USB, research, photos, diary
```

## Documentation

- **[STAGE3.md](STAGE3.md)** — architecture (Mermaid), benchmarks, known issues & failure recovery, requirement coverage
- Audio (I2S amp): [docs/rdk_x5_40pin_i2s_max98357a.md](docs/rdk_x5_40pin_i2s_max98357a.md) · [firmware/max98357a/](firmware/max98357a/)
- Why BPU-LLM is S100-only: [docs/rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md)
- Network / maintenance: [docs/network_setup.md](docs/network_setup.md) · Power/USB brown-out: [docs/power_usb_troubleshooting.md](docs/power_usb_troubleshooting.md)
- Testing: [docs/TESTING.md](docs/TESTING.md) · Build log: [docs/diary/](docs/diary/)

## License & disclaimer

MIT for the code/hardware — see [LICENSE](LICENSE). Fan-made, **non-commercial** tribute:
"Korosuke" (コロ助) is a character from *Kiteretsu Daihyakka* by Fujiko F. Fujio; all
character rights belong to their respective owners.

**「ワガハイはコロ助ナリ！」** 🤖
