# Project Korosuke — Stage 3 (Launch): Fully On-Device Interactive Robot

D-Robotics **Robotics Dream Keeper Challenge** — Stage 3 showcase.
Korosuke (コロ助), the samurai-robot from *Kiteretsu Daihyakka*, rebuilt as a ~46 cm
desktop animatronic whose brain is an **RDK X5** (10 TOPS BPU, ROS 2 / Ubuntu 22.04).

> **Headline:** Korosuke **sees, tracks, listens, thinks, speaks, emotes, reacts to
> gestures, and moves its arms — 100% on-device. No cloud. No external server.**
> Everything (vision, speech-to-text, LLM dialogue, text-to-speech, expression,
> gesture, actuation) runs on the single RDK X5 board + an ESP32-S3 eye/arm co-MCU.

---

## 1. What Korosuke does (the integrated demo)

Stand in front of Korosuke and it:
1. **Sees you** — BPU YOLO11-pose detects the largest person + 17-point skeleton.
2. **Looks at you** — the eyes (2× GC9A01) track your position.
3. **Greets you** — speaks a "…ナリ" greeting in a high childlike voice + waves both arms.
4. **Emotes** — happy / sad / angry / surprised / sleepy on the round eye displays.
5. **Reacts to gestures** — both hands up → "バンザイ！" + raises both arms; one hand
   up → "はーい、ナリ！"; one-hand wave → waves back with that arm.
6. **Talks with you** — your speech is transcribed on-device (sherpa-onnx JP), answered
   by an **on-device LLM** (TinySwallow-1.5B) in Korosuke's "ワガハイ…ナリ" persona,
   spoken aloud via on-device TTS (Open JTalk).
7. **Misses you** — when you leave frame it droops its arms and says "いっちゃいやナリ〜".

A **web dashboard** (`http://<board-ip>:8080`) shows the live camera + skeleton, mic
level, recognition state, and speech — and lets you tune every parameter (volume, mic
gain, voice pitch, thresholds, reaction toggles, eyes, arms) live.

## 2. Technical achievements (all measured on the real board)

| Capability | Implementation | On-device measurement |
|---|---|---|
| Vision (person + pose) | BPU YOLO11n / YOLO11n-pose (Bayes-e .bin) | live camera ~**19.5 FPS** (Stage-1 was 8.3) |
| Speech-to-text (JP) | **sherpa-onnx** ReazonSpeech Zipformer int8 + Silero VAD | **RTF 0.44** (real-time) |
| **On-device LLM dialogue** | **llama.cpp + TinySwallow-1.5B-Instruct Q5** (CPU) | load 24 s, **1.5–3.3 tok/s**, short reply 5–8 s |
| Text-to-speech (JP) | **Open JTalk** with pitched childlike voice (`-fm 9 -a 0.40`) | dynamic, any text, instant |
| Expression | 2× GC9A01 driven by ESP32-S3 (LovyanGFX), 7 emotions | ≥30 FPS render |
| Gesture recognition | skeleton (wrist-vs-shoulder) both/one raise + wave | in the pose loop, no extra model |
| Arm actuation | 2× SG90 (rope-pull bellows arms) on ESP32-S3 LEDC PWM | GPIO4/5, auto-detach to save current |

**Benchmark — whole stack running at once** (camera+pose+STT+LLM+TTS+eyes+arms, measured
on the board): CPU **49 °C** / BPU **49 °C** / DDR **50 °C** (target < 60 °C ✅, no fan
throttling), RAM **2.2 GiB / 6.9 GiB used** (LLM + all models resident, 4.6 GiB free),
system load ~**0.8**. The full experience fits with headroom on one 8 GB board.

**Key point — the BPU does vision, the CPU does language.** We proved on-device that
the RDK X5's 10 TOPS BPU accelerates YOLO but **cannot** accelerate the LLM (llama.cpp
runs on the 8× Cortex-A55 CPU; BPU-LLM is S100-only) — so the design puts perception on
the BPU and dialogue on the CPU, both on the same board, fully local.

## 3. Architecture (no cloud)

```
                RDK X5 (Ubuntu 22.04, 10 TOPS BPU, 8× A55)
Camera ─► YOLO11-pose (BPU) ─► brain ─┬─► eyes: gaze + emotion  ─┐
                                       ├─► arms (rope-pull)       │ UART/USB
Mic ─► sherpa STT (CPU) ─► dialogue ──┤                          ▼
                                       ├─► TinySwallow LLM (CPU)  ESP32-S3 co-MCU
                                       └─► Open JTalk TTS ─► speaker   2×GC9A01 eyes
                                                                       2×SG90 arms
```
The whole robot runs from the board; the ESP32-S3 is a real-time eye/arm driver it
commands over serial. The board even brings up its own network (eth0 DHCP) — no dev PC
required at runtime. Everything is a systemd service (auto-start on power-on).

## 4. Innovation highlights

- **A complete on-device conversational + expressive robot on a $140-class board** —
  vision, JP-ASR, a real JP LLM, JP-TTS, emotion, gesture and actuation with zero cloud.
- **Character-faithful**: "ワガハイ…ナリ" persona held by a 1.5B model via system-prompt
  + few-shot; a pitched Open JTalk voice; smiling eyes; a rope-pulled bellows arm that
  matches the 3D-printed design's center-bore.
- **Rule/LLM selectable**: greetings, farewells and gesture lines can be canned (instant)
  or LLM-generated (varied, contextual) — a live toggle balances latency vs variety.
- **Engineering rigor**: debugged real hardware limits — ESP32-S3 LEDC is **14-bit max**
  (16-bit silently emits no PWM); the eye's native-USB port resets on host open (use the
  CH343 UART); servo release needs `ledcDetachPin`, not duty-0.

## 5. Build / BOM (summary)

RDK X5 8GB + open-source fan case · 2× GC9A01 + ESP32-S3-N16R8 · UVC USB camera (mic
built-in) · ES8326 audio → speaker · 2× SG90 servos + 1S Li-ion (servo rail) ·
3D-printed color-split body (OpenSCAD, `hardware/3d_models/korosuke_print/`).
Full hardware wiring/route: [docs/hardware_block_diagram.md](docs/hardware_block_diagram.md).

## 6. Reproduce

```bash
# On the RDK X5:
#  Vision demo (BPU):   /app/pydev_demo/02_detection_sample/... (Stage 1)
#  Everything else is the one integrated service:
sudo systemctl start korosuke-monitor        # camera+pose+STT+LLM+TTS+eyes+arms
#  → open http://<board-ip>:8080
```
Component research + decisions: [docs/dialogue_stack_research.md](docs/dialogue_stack_research.md)
(LLM/TTS), [docs/stt_research.md](docs/stt_research.md) (STT),
[docs/mocap_capabilities.md](docs/mocap_capabilities.md) (gesture),
[docs/implementation_plan.md](docs/implementation_plan.md) (roadmap),
[docs/TESTING.md](docs/TESTING.md) (all test commands),
[docs/diary/](docs/diary/) (build log).

---
*"ワガハイはコロ助ナリ！" — fully on-device, powered by RDK X5.*
Character © Fujiko F. Fujio — fan-made, non-commercial tribute.
