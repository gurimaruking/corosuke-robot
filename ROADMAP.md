# Project Korosuke — Roadmap

**Version 1.0 · 2026-07-05** · D-Robotics Robotics Dream Keeper Challenge
Brain: **RDK X5** (10 TOPS BPU, ROS 2). Full design rationale in [PROPOSAL.md](PROPOSAL.md).

Final submission check: **2026-07-26 14:30 GMT**. Stage 3 showcase: [STAGE3.md](STAGE3.md).

---

## Status legend
✅ done · 🔄 in progress · ⬜ planned · ✴️ stretch (decoupled, never on critical path)

## Milestones

| # | Window | Milestone | Exit criterion | State |
|---|--------|-----------|----------------|-------|
| M0 | –6/24 | **Stage 1 — Ignite** | RDK X5 boots, on-device YOLO11 on BPU, thermal solved, open-source case shipped | ✅ |
| M1 | 6/25–7/5 | **Stage 2 — Build** design | Concept + AI architecture + ROS 2 graph + BOM + roadmap + risks, submitted as showcase PR | ✅ |
| M1b | (parallel) | **Hardware / 3D body** | Full body redesigned for color-split printing; eye + chest-camera mounts | ✅ |
| M1c | (parallel) | **Eye coprocessor bring-up** | 2× GC9A01 driven by ESP32-S3 (LovyanGFX), emotions/gaze/blink over UART | ✅ |
| M2 | 7/5–7/7 | **ROS 2 skeleton** | ROS 2 Humble on RDK X5; `korosuke_msgs`; `serial_bridge` moves the eyes from a topic | ✅ (eye_demo→bridge→eyes verified) |
| M3 | 7/8–7/11 | **Perception + dialogue** | vision (BPU)→gaze tracking; **on-device** STT(sherpa)+LLM(TinySwallow)+TTS(OpenJTalk) "…ナリ"; expression | ✅ (VOICEVOX→OpenJTalk; on-device LLM added) |
| M4 | 7/12–7/13 | **Integrated demo** | see → turn → greet → emote → gesture, fully on-device; benchmark table | ✅ (the `korosuke-monitor` service; +arm actuation, gestures) |
| M5 | 7/14– | **Stage 3 — Launch** | demo video; benchmark; Stage 3 showcase | 🔄 [STAGE3.md](STAGE3.md) + README Quick Start + benchmarks + ROS 2 graph + failure-recovery docs all done; **demo video done ([youtu.be/NJwj6Iazd20](https://youtu.be/NJwj6Iazd20)); showcase PR pending** |
| S1 | if time | **Bipedal gait** | quasi-static "penguin" gait, 3+ steps, no fall — *only if* the junk QDD motors revive | ✴️ |

## Acceptance criteria (measurable goals)

Mapped from [PROPOSAL.md §1.3](PROPOSAL.md):

- **G1 Vision:** ≥10 FPS sustained on BPU; detection→action latency <150 ms.
- **G2 Gaze:** eyes + neck follow a face, error <5° after 300 ms. — *as-built: **eyes-only** (no neck servo fitted); neck-follow deferred.*
- **G3 Voice:** wake → LLM → speech start <3.0 s; "…nari" style. — *on-device STT→LLM→TTS built; LLM reply is 5–10 s on CPU (BPU can't accelerate LLM on X5), covered by the "thinking" eyes.*
- **G4 Lip-sync:** mouth follows audio envelope within 100 ms. — ***not implemented*** *(no 2-axis mouth mechanism); expression is via the eyes + voice instead.*
- **G5 Eye emotion:** ≥30 FPS on 2× GC9A01, 7 emotions.
- **G6 Thermal:** sustained BPU+CPU+vision <60 °C (fan lid validated at Stage 1).
- **G7 Bipedal ✴️:** quasi-static gait, 3+ steps (stretch only).

## Top risks (see [PROPOSAL.md §3.4](PROPOSAL.md) for the full table + triggers)

1. **QDD motors are junk** → bipedal is a decoupled stretch; MVP passes seated/standing.
2. **LLM/VOICEVOX latency** → async off the perception loop + canned "…nari" fallbacks.
3. **2× GC9A01 @30 FPS load** → dedicated ESP32-S3 coprocessor, not the RDK.
4. **Thermal throttling** → fan lid (−17 °C) validated; monitor `hrut_somstatus`.
5. **Timeline (7/15 is tight)** → MVP-first; reuse existing firmware/server; integration front-loaded.
