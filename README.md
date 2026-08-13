# 🤖 Korosuke Robot / コロ助ロボット

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Brain: RDK X5](https://img.shields.io/badge/Brain-RDK%20X5%20·%2010%20TOPS%20BPU-e8491d.svg)](https://developer.d-robotics.cc/)
[![On-device](https://img.shields.io/badge/AI-100%25%20on--device%20·%20no%20cloud-2da44e.svg)](STAGE3.md)
[![ROS 2](https://img.shields.io/badge/ROS-2-22314e.svg)](https://docs.ros.org/)
[![Sub-MCU: ESP32-S3](https://img.shields.io/badge/Sub--MCU-ESP32--S3-blue.svg)](https://www.espressif.com/)

A ~46 cm open-source animatronic of **Korosuke (コロ助)** from *Kiteretsu Daihyakka* — he
sees, listens, thinks, and talks in **Japanese or English**, emotes through his eyes, waves
his arms, and shuts himself down safely. Everything runs **100 % on-device on a D-Robotics
RDK X5**, with an ESP32-S3 driving the eyes and arms.

> 🏆 **D-Robotics Robotics Dream Keeper Challenge — Stage 3 (Launch)**
> 📄 [STAGE3.md](STAGE3.md) — showcase & benchmarks · 🧩 [PROPOSAL.md](PROPOSAL.md) · 🗺 [ROADMAP.md](ROADMAP.md)

![Korosuke revision 0.1 — fully assembled, smiling](docs/photo/20260725_korosuke-robot-revision_0.1.jpg)

## ▶ Watch the demo

<p align="center">
  <a href="https://youtu.be/NJwj6Iazd20">
    <img src="https://img.youtube.com/vi/NJwj6Iazd20/maxresdefault.jpg" alt="Watch the Korosuke demo on YouTube" width="640">
  </a>
  <br>
  <a href="https://youtu.be/NJwj6Iazd20">
    <img src="https://img.shields.io/badge/Watch%20the%20demo-YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch on YouTube">
  </a>
</p>

---

## What it does

Powered on and left alone, Korosuke wakes and greets you, tracks you with BPU pose
detection, holds a conversation (on-device STT → LLM → TTS, with a "thinking" eye animation
while he ponders), reacts to gestures, waves his arms, and shuts down safely on a button
press (goodnight voice → ✕✕ "safe-to-unplug" eyes). A tabbed **web dashboard** at
`http://<board-ip>:8080` streams the live camera + skeleton and tunes every setting.

| Subsystem | Implementation | Measured |
|---|---|---|
| Vision | BPU YOLO11n-pose (Bayes-e `.bin`) | ~19.5 FPS |
| Speech-to-text | sherpa-onnx **SenseVoice** (JP/EN) + Silero VAD | real-time (CPU) |
| LLM dialogue | llama.cpp + TinySwallow-1.5B *(Qwen2.5-1.5B-based)* — JP & EN personas | 1.5–3.3 tok/s · ~5–10 s/reply |
| Text-to-speech | **JP** Open JTalk / **EN** espeak-ng | instant |
| Language | **日本語 / English** — STT · LLM · TTS · Web UI, switchable on the fly | on-device |
| Audio out | **MAX98357A I2S amp** (custom kernel driver) → φ50 speaker | DSP-tuned |
| Eyes | 2× GC9A01 on ESP32-S3 — 8 emotions (smile / thinking / ✕✕) | ≥30 FPS |
| Arms | 2× SG90 rope-pull bellows arms | auto-detach |

> 🌐 **Bilingual & fully on-device.** One switch flips the whole robot — speech recognition,
> LLM replies, voice, *and* the dashboard — between **Japanese and English**, with **no cloud
> and no API keys**. The voice stack follows D-Robotics' own [RDK voice-interaction
> reference](https://developer.d-robotics.cc/magicbox_doc/en/algorithm-development/voice-interaction):
> **SenseVoice** ASR + a **Qwen2.5-1.5B**-family LLM (we run the Japanese-tuned
> **TinySwallow-1.5B** via llama.cpp on CPU).

### Build tools & jigs

To reproduce the body you'll also need:

- **Velcro tape** — handy for attaching parts to the 3D-printed body — [Amazon](https://www.amazon.co.jp/dp/B0GJZJM4TG)
- **Ultrasonic cutter** (or an alternative) — handy for post-processing the 3D-printed parts
- **3D printer** — required to print the parts! (we used a **Bambu Lab A1**; parts are within 18 cm, so an **A1 mini** should *just* fit)
- **Double-sided tape** — handy for fixing parts in place
- **String** — needed to move the hands (rope-pull arms)
- **Zip ties** — needed to tune the rope arms — [Daiso](https://jp.daisonet.com/products/4550480088891)

## Challenge journey — Stage 1 → 2 → 3

| Stage | Theme | What was proven | Doc |
|---|---|---|---|
| **1 — Ideation** | On-device perception | YOLO11 vision on the **RDK X5 BPU** (+ open-source [RDK X5 case](https://github.com/gurimaruking/rdk-x5-modular-case)) | [STAGE1.md](STAGE1.md) |
| **2 — Build** | System design | The **RDK X5 as the single cognitive core** under a **ROS 2 graph**; ESP32s become actuator sub-controllers | [PROPOSAL.md](PROPOSAL.md) |
| **3 — Launch** | Shipped robot | The full interactive Korosuke — sees / listens / thinks / talks / emotes, **bilingual**, 100 % on-device (this repo) | [STAGE3.md](STAGE3.md) |

Stage 1's BPU vision is still today's perception layer, and Stage 2's ROS 2 design ships as
[`ros2_ws/`](ros2_ws/) alongside the low-latency monolith.

## Quick start (on the RDK X5)

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
ros2 launch korosuke_nodes korosuke.launch.py                  # vision → brain → eyes / dialogue → voice
ros2 launch korosuke_nodes korosuke.launch.py with_web:=true   # + rosbridge :9090 → open ros2_ws/src/korosuke_nodes/web/console.html
#   NB: eye path is HW-verified; full graph is code-complete but not yet run end-to-end (see STAGE3 §5.1)

# Safe shutdown:  hold the GPIO button ~1 s  → goodnight voice → ✕✕ eyes → OS halt → cut power.
```

**Models** (STT / LLM / YOLO `.bin`) download on the board — see
[stt_research.md](docs/stt_research.md) and [dialogue_stack_research.md](docs/dialogue_stack_research.md).
The LLM stays on the CPU **by design**: the X5 BPU cannot accelerate LLMs
([rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md)), so replies take ~5–10 s — the "thinking" eyes
cover the wait.

## Repository layout

```
corosuke-robot/
├── STAGE3.md, PROPOSAL.md, ROADMAP.md   # showcase / Stage-2 design / roadmap
├── scripts/            # korosuke_monitor.py (integrated demo) · shutdown_button.py · fix_max98357a.sh
├── ros2_ws/            # ROS 2 graph: korosuke_msgs + korosuke_nodes (vision/brain/dialogue/voice/serial_bridge)
├── firmware/           # ESP32-S3 (PlatformIO): corosuke_eyes (eyes + arms) · max98357a (I2S driver)
├── deploy/             # systemd units + sudoers (auto-start, safe shutdown, audio self-heal)
├── hardware/3d_models/ # OpenSCAD body (color-split) + RDK X5 modular case
└── docs/               # architecture, audio(I2S), BPU-LLM, network, power/USB, research, photos, diary
```

## Documentation

- **[STAGE3.md](STAGE3.md)** — architecture (Mermaid), benchmarks, **known issues & limitations**, requirement coverage
- Audio (I2S amp): [docs/rdk_x5_40pin_i2s_max98357a.md](docs/rdk_x5_40pin_i2s_max98357a.md) · [firmware/max98357a/](firmware/max98357a/)
- Why the LLM stays on CPU: [docs/rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md)
- Network / maintenance: [docs/network_setup.md](docs/network_setup.md) · Power/USB brown-out: [docs/power_usb_troubleshooting.md](docs/power_usb_troubleshooting.md)
- Testing: [docs/TESTING.md](docs/TESTING.md) · Build log: [docs/diary/](docs/diary/)

## Credits & inspiration

Korosuke's design borrows ideas from these open / animatronic robots:

- [Disney's Olaf robot](https://thewaltdisneycompany.com/olaf-robotic-character/) — expressive animatronic eyes & face
- [Open Duck Mini (BDX)](https://github.com/apirrone/Open_Duck_Mini) — compact bipedal droid
- [3D-printed animatronic dual-eye mechanism](https://www.instructables.com/Simplified-3D-Printed-Animatronic-Dual-Eye-Mechani/) — the eye-rig approach

## License & disclaimer

MIT for the code/hardware — see [LICENSE](LICENSE). Fan-made, **non-commercial** tribute:
"Korosuke" (コロ助) is a character from *Kiteretsu Daihyakka* by Fujiko F. Fujio; all
character rights belong to their respective owners.

**「ワガハイはコロ助ナリ！」** 🤖
