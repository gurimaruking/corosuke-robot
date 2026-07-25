# Project Korosuke — Stage 3 (Launch): Fully On-Device Interactive Robot

D-Robotics **Robotics Dream Keeper Challenge** — Stage 3 showcase.
Korosuke (コロ助), the karakuri-robot from *Kiteretsu Daihyakka*, rebuilt as a ~46 cm
desktop animatronic whose brain is an **RDK X5** (10 TOPS BPU "Bayes-e", 8× Cortex-A55,
Ubuntu 22.04). A fan-made, non-commercial tribute.

![Korosuke revision 0.1 — fully assembled, smiling](docs/photo/20260725_korosuke-robot-revision_0.1.jpg)

> **Headline:** Korosuke **wakes up and greets you, sees and tracks you, listens,
> thinks, talks back, smiles, ponders, reacts to gestures and to being petted, waves
> its arms, and shuts itself down safely — 100 % on-device. No cloud. No dev PC at
> runtime.** Vision, speech-to-text, LLM dialogue, text-to-speech, expression, gesture
> and actuation all run on a single RDK X5 + an ESP32-S3 eye/arm co-MCU.

🎥 **[▶ Watch the 10-second on-device conversation demo →](docs/photo/20260725_korosuke-robot-v0.1_movie.mp4)**

---

## 1. What Korosuke does (the integrated experience)

Power it on and, unattended:

0. **Wakes up** — on boot it auto-starts, self-checks its audio, blinks its eyes into a
   smile and says *"おはようナリ！コロ助、起きたナリ！"* while waving.
1. **Sees you** — BPU YOLO11-pose finds the largest person + 17-point skeleton.
2. **Looks at you** — the round eyes (2× GC9A01) track your position.
3. **Greets you** — a "…ナリ" greeting in a high childlike voice + waves both arms.
4. **Emotes** — smile / sad / angry / surprised / sleepy on the round displays.
5. **Reacts to gestures** — both hands up → *"バンザイ！"* + raises both arms; one hand
   up → *"はーい、ナリ！"*; one-hand wave → waves back with that arm.
6. **Talks with you** — your speech is transcribed on-device (sherpa-onnx JP); while the
   **on-device LLM** (TinySwallow-1.5B) thinks, the eyes show a **"考え中" pondering
   animation**; the reply is spoken via on-device TTS (Open JTalk) in Korosuke's
   "ワガハイ…ナリ" persona, and the eyes break into a smile.
7. **Likes being petted** — a capacitive touch sensor triggers "なでなで" reactions.
8. **Misses you** — when you leave frame it droops, says a farewell, then settles back
   to a calm awake face.
9. **Sleeps safely** — a physical button runs a graceful shutdown: sleepy eyes →
   *"おやすみナリ…また会おうナリ！"* → **✕✕ "power-off-OK" eyes** that stay lit after the
   OS halts, so you know when it's safe to cut power.

A **web dashboard** (`http://<board-ip>:8080`, tabbed **Monitor / Settings**) shows the
live camera + skeleton, mic level, recognition state and speech — and lets you tune every
parameter (volume, mic gain, voice pitch, thresholds, reaction toggles, eyes, arms, and a
**one-click audio self-test**) live from any PC on the LAN.

## 2. Stage-3 technical achievements (all measured on the real board)

| Capability | Implementation | On-device measurement |
|---|---|---|
| Vision (person + pose) | BPU YOLO11n-pose (Bayes-e `.bin`) | live camera ~**19.5 FPS** |
| Speech-to-text (JP) | **sherpa-onnx** ReazonSpeech Zipformer int8 + Silero VAD | **RTF 0.44** (real-time) |
| **On-device LLM dialogue** | **llama.cpp + TinySwallow-1.5B-Instruct Q5** (CPU) | load 24 s, **1.5–3.3 tok/s**, reply 5–10 s |
| Text-to-speech (JP) | **Open JTalk** pitched childlike voice (`-fm 9 -a 0.40`) | dynamic, any text, instant |
| **Audio out (miniaturized)** | **MAX98357A** I2S Class-D amp on 40-pin **i2s1** + φ50 8Ω speaker | custom-built card, DSP-tuned |
| Expression | 2× GC9A01 on ESP32-S3 (LovyanGFX): 8 states incl. smile / pondering / ✕✕ | ≥30 FPS render |
| Gesture recognition | skeleton (wrist-vs-shoulder): both/one raise + wave | in the pose loop, no extra model |
| Arm actuation | 2× SG90 rope-pull bellows arms on ESP32-S3 LEDC PWM | GPIO4/5, auto-detach to save current |
| Touch reaction | capacitive touch → "petting" responses | ESP32-S3 `EVENT touch` over serial |
| Safe power | GPIO shutdown button + boot auto-start (systemd) | goodnight voice + ✕✕-eyes signal |
| Maintenance net | eth0 **static 192.168.0.200** + usb0 gadget lifeline | auto-assigned on boot |

**Whole-stack thermal benchmark** (camera + pose + STT + LLM + TTS + eyes + arms all at
once, LLM pinning ~**600 % CPU**): CPU **≈50 °C** / BPU **≈50 °C** / DDR **≈51 °C**
(target < 60 °C ✅, no fan throttling), RAM ~2.2 GiB / 6.9 GiB used. The full experience
fits with headroom on one 8 GB board.

## 3. Hardware, miniaturized and packed into the body

The Stage-3 build moved the whole brain **inside the 3-D-printed body** (OpenSCAD,
color-split printing). Two size problems were solved this stage:

- **Speaker → MAX98357A.** The oversized 5 cm enclosed speakers were replaced by a small
  **φ50 mm 8 Ω driver** driven by a **MAX98357A I2S digital amp** off the RDK X5 40-pin
  I2S1. Because the RDK kernel ships **no** MAX98357A codec driver (and no in-tree dummy
  codec), we **built `snd-soc-max98357a` out-of-tree** against the on-board
  `hobot-kernel-headers`, authored a **device-tree overlay** (`simple-audio-card`,
  `dw_i2s1` ↔ `maxim,max98357a`), and made it auto-load. See
  [docs/rdk_x5_40pin_i2s_max98357a.md](docs/rdk_x5_40pin_i2s_max98357a.md).
- **Camera → bare UVC webcam** in the chest, behind the nose/chest port (see the lens in
  the chest cut-out of the hero photo). It is auto-detected (USB-preference, so RDK
  internal video nodes are never mistaken for the camera) and its built-in mic feeds STT.

![Korosuke's head — 2× GC9A01 round eyes + red camera-nose, driven by the ESP32-S3 co-MCU](docs/photo/Korosuke_Eye.jpg)

*The head carries the two round GC9A01 eye displays (here in the wide "awake" look) and
the camera-in-nose port; the ESP32-S3 co-MCU on the bench drives the eyes and arms. The
orange body hides the RDK X5 + fan + MAX98357A amp + φ50 speaker.*

🎥 **Watch:** [**10-second on-device conversation demo**](docs/photo/20260725_korosuke-robot-v0.1_movie.mp4) ·
[rope-pull arm driven by the SG90 servo](docs/photo/Arm-pulling-by-surve-motor.mp4)

## 4. Engineering deep-dives (what made this hard, and how we proved it)

- **The BPU does vision; the CPU does language — and we proved the BPU *cannot* do the
  LLM on X5.** A multi-language, source-verified investigation
  ([docs/rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md)) concludes: the RDK X5 Bayes-e BPU has
  **no official LLM toolchain** — the "large-model toolchain" is **RDK S100 (Nash)
  only**. Decisive evidence: D-Robotics' *own* X5 packages (`magicbox_qwen_llm`,
  `InternVL2_5-1B-GGUF-BPU`) run the language model on **llama.cpp/CPU**; the BPU only
  accelerates the vision (ViT) tower. So Korosuke's design — perception on the BPU,
  dialogue on the 8× A55 CPU — is the *correct* architecture for this board, not a
  limitation we failed to overcome.
- **"Loud but clean" on a tiny speaker.** We measured the small driver's clean ceiling at
  **≈ −6 dBFS** and built a playback DSP (high-pass to protect the cone + compressor +
  brick-wall limiter + peak-normalize to the ceiling) so the childlike voice is loud
  without the onset clipping we first heard. Output is a modest ~0.1–0.4 W — deliberately
  speaker-limited, not amp-limited.
- **Self-healing audio.** A cold-boot module load-order race can leave the I2S card in an
  un-openable state. A boot-time root service **and** a web **"🔈 audio self-test"**
  button verify the card and, if needed, re-bind it automatically.
- **Robust to hardware reality.** Debugged live: ESP32-S3 LEDC is **14-bit max** (16-bit
  silently emits no PWM); the eye's native-USB port resets on host open (use the CH343
  UART); servo release needs `ledcDetachPin`, not duty-0; a half-inserted USB power cable
  and a bad USB cable were diagnosed straight from `dmesg` (`Cannot enable. Maybe the USB
  cable is bad?`); camera/mic device names and indices are auto-detected so swapping the
  webcam "just works."

## 5. Architecture (no cloud)

```
                 RDK X5 (Ubuntu 22.04, 10 TOPS BPU, 8× A55)
Camera(UVC) ─► YOLO11-pose (BPU) ─► brain ─┬─► eyes: gaze + 8 emotions ─┐
                                            ├─► arms (rope-pull)         │ USB/UART
Mic(UVC) ─► sherpa STT (CPU) ─► dialogue ──┤                            ▼
                                            ├─► TinySwallow LLM (CPU)    ESP32-S3 co-MCU
                                            └─► Open JTalk TTS ─► MAX98357A ─► φ50 speaker
Touch(cap) ─► petting reactions                              2×GC9A01 eyes · 2×SG90 arms
GPIO button ─► graceful shutdown (goodnight voice + ✕✕ eyes)
```
The board brings up its own network (eth0 static + usb0) and every component is a systemd
service that auto-starts on power-on. No dev PC is required at runtime.

## 6. Innovation highlights

- **A complete on-device conversational + expressive robot on a $140-class board** —
  JP-ASR, a real JP LLM, JP-TTS, 8-state emotion, gesture, touch and actuation, zero cloud.
- **Character-faithful & alive**: pitched "ワガハイ…ナリ" voice; hand-tuned **smile** and a
  **"thinking" eye animation** during the LLM's think time so the wait feels intentional;
  a rope-pulled bellows arm matching the 3-D-printed center-bore.
- **Custom kernel work**: an out-of-tree ALSA codec driver + device-tree overlay to add a
  digital I2S amp the vendor kernel didn't support — turning a $2 amp into a body-fit speaker.
- **Ships like a product**: power-on-to-greeting auto-start, a physical safe-shutdown with
  a clear "safe to unplug" signal, a static maintenance IP, and a web self-test.

## 7. Build / BOM (summary)

RDK X5 8 GB + open-source fan case · 2× GC9A01 + ESP32-S3-N16R8 · UVC USB webcam
(mic built-in) · **MAX98357A + φ50 8 Ω speaker** (I2S) · 2× SG90 servos (rope-pull arms)
+ 1S Li-ion servo rail · capacitive touch sensor · GPIO shutdown button ·
3-D-printed color-split body (OpenSCAD, `hardware/3d_models/korosuke_print/`).
Wiring/routes: [docs/hardware_block_diagram.md](docs/hardware_block_diagram.md),
[docs/rdk_x5_40pin_i2s_max98357a.md](docs/rdk_x5_40pin_i2s_max98357a.md),
[docs/network_setup.md](docs/network_setup.md),
[docs/power_usb_troubleshooting.md](docs/power_usb_troubleshooting.md) (power/USB brown-out diagnosis).

## 8. Reproduce

```bash
# On the RDK X5 — everything is one integrated service, auto-starting on boot:
sudo systemctl status korosuke-monitor   # camera+pose+STT+LLM+TTS+eyes+arms+touch
#   → open http://<board-ip>:8080  (Monitor / Settings tabs)
# Safe shutdown: hold the GPIO button ~1 s (goodnight voice → ✕✕ eyes → halt).
```
Component research + decisions:
[docs/dialogue_stack_research.md](docs/dialogue_stack_research.md) (LLM/TTS),
[docs/stt_research.md](docs/stt_research.md) (STT),
[docs/rdk_x5_bpu_llm.md](docs/rdk_x5_bpu_llm.md) (why BPU-LLM is S100-only),
[docs/mocap_capabilities.md](docs/mocap_capabilities.md) (gesture),
[docs/implementation_plan.md](docs/implementation_plan.md) (roadmap),
[docs/TESTING.md](docs/TESTING.md) (test commands),
[docs/diary/](docs/diary/) (build log).

---
*"ワガハイはコロ助ナリ！" — fully on-device, powered by RDK X5.*
Character © Fujiko F. Fujio — fan-made, non-commercial tribute.
