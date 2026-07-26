---
marp: true
theme: default
paginate: true
size: 16:9
title: Korosuke — On-device Interactive Animatronic (RDK X5)
---

<!-- _class: lead -->
# 🤖 Korosuke / コロ助

### An on-device interactive animatronic on the **D-Robotics RDK X5**

Sees · Listens · Thinks · Talks (JP / EN) · Emotes — **100 % on-device, no cloud**

<small>D-Robotics **Robotics Dream Keeper Challenge** — Stage 3 (Launch)</small>

---

## What is Korosuke?

- A ~46 cm open-source animatronic of **Korosuke (コロ助)** from *Kiteretsu Daihyakka*
- Brain = **RDK X5** (10 TOPS BPU "Bayes-e", 8× Cortex-A55, 8 GB) + an **ESP32-S3** for eyes & arms
- **Everything runs on the board** — perception, speech, LLM, voice, expression
- **No cloud, no API keys, no dev-PC at runtime**

> 「ワガハイはコロ助ナリ！」

---

## The journey — Stage 1 → 2 → 3

| Stage | Proved |
|---|---|
| **1 · Ideation** | On-device **YOLO11 vision on the BPU** (+ open-source RDK X5 case) |
| **2 · Build** | System design: RDK X5 as the **single cognitive core** under a **ROS 2 graph** |
| **3 · Launch** | The full interactive robot — **bilingual, on-device** (this) |

*Each stage builds on the last — re-wiring, not re-inventing.*

---

## Architecture — BPU perception / CPU language

- **BPU** → YOLO11n-pose (person + skeleton) **~19.5 FPS**
- **CPU (8× A55)** → STT · LLM · TTS, all concurrent
- **ESP32-S3** → 2× round eye displays + rope-pull arms + touch, over UART

> The BPU *cannot* accelerate LLM/ASR on the X5 (that's S100-class) — so
> **perception on the BPU, language on the CPU** is the correct split, not a shortfall.

---

## Voice pipeline (fully on-device)

**Mic → VAD → STT → LLM → TTS → speaker**, no network:

- **STT** — sherpa-onnx **SenseVoice** (multilingual)
- **LLM** — **TinySwallow-1.5B** (Qwen2.5-1.5B-based) on llama.cpp
- **TTS** — **Open JTalk** (JP) / **espeak-ng** (EN)

> Mirrors **D-Robotics' own RDK voice-interaction reference** (SenseVoice + Qwen2.5-1.5B).

---

<!-- _class: lead -->
## 🌐 Bilingual — 日本語 / English / Auto

One switch flips the **whole robot**: speech recognition, the LLM's persona & replies,
the voice, **and** the web dashboard — instantly, **on-device**.

**Auto** = SenseVoice detects the spoken language and Korosuke answers in kind.

---

## Expressive & alive

- **Eyes**: 2× GC9A01 round LCDs, **8 emotions** — smile, "thinking" (during LLM think-time), ✕✕ shutdown
- **Arms**: rope-pull bellows arms that wave / cheer, auto-detach for safety
- **Touch**: pet the head → happy reaction
- Character-faithful pitched "…ナリ" voice

---

## Custom hardware & product polish

- **MAX98357A I2S amp** — I built an **out-of-tree ALSA codec driver + device-tree overlay**
  the vendor kernel didn't ship, turning a $2 amp into a body-fit speaker
- **Ships like a product**: power-on auto-greeting, **safe-shutdown button** with a clear
  "safe to unplug" ✕✕ signal, self-healing audio, static maintenance IP
- **Web dashboard** shows the live AI stack (LLM / persona / STT / TTS)

---

## Two integrations of one pipeline

- **Monolith** (`korosuke_monitor.py`) — low-latency demo + web dashboard *(what the video shows)*
- **ROS 2 graph** (`ros2_ws/`) — 6 nodes + custom messages, `ros2 launch …`,
  optional web console via rosbridge

*Same on-device stack, two deployments.*

---

## Honest scope — not in this build

- ❌ 2-axis mouth / lip-sync (expression is via the eyes + voice)
- ❌ Neck servo (face tracking is eyes-only)
- ✴️ Bipedal "penguin" walking (salvaged QDD motors unreliable — decoupled stretch)
- ❌ Back-mounted sword prop

*We show what actually ships — nothing faked.*

---

<!-- _class: lead -->
## Demo

**Wake & greet → see & follow → talk (JP↔EN) → gesture → pet → safe shutdown**

🎥 *[insert demo video here]*

🔗 github.com/gurimaruking/corosuke-robot · STAGE3.md

---

<!-- _class: lead -->
# ありがとうナリ！ / Thank you!

**Korosuke — 100 % on-device, bilingual, open-source.**

Built on the **D-Robotics RDK X5**.
