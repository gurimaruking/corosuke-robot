# I am Korosuke! — An era when anyone can build a robot

<p>
<img src="../photo/D-Robotics_Logo.png" height="72" alt="D-Robotics">
<img src="../photo/event_logo1.png" height="72" alt="Robotics Dream Keeper Challenge">
</p>

> D-Robotics **Robotics Dream Keeper Challenge** participation story (English version).
> 日本語版はこちら → [intro_ja.md](intro_ja.md) · Full technical details → [STAGE3.md](../../STAGE3.md)

## Table of contents

- [Introduction](#introduction)
- [Background](#background)
- [Architecture](#architecture)
  - [Hardware](#hardware)
  - [Software](#software)
- [Build process](#build-process)
  - [Mechanics (3D-printed body)](#mechanics-3d-printed-body)
  - [Wiring](#wiring)
  - [Software, built with AI](#software-built-with-ai)
  - [Operation (Korosuke Monitor)](#operation-korosuke-monitor)
  - [Tools & jigs](#tools--jigs)
- [Afterword](#afterword)
- [Troubleshooting (gotchas)](#troubleshooting-gotchas)

## Introduction

Korosuke is the partner **karakuri robot** built by Kiteretsu, the inventor-boy hero of
***Kiteretsu Daihyakka*** by the great manga artist **Fujiko F. Fujio**. Our Korosuke is a
**fan-made robot** built by members of **Robostadion**, a robot co-working space in Akihabara,
Tokyo — with a **D-Robotics RDK X5** as its brain. We designed the mechanics, electronics and
software **together with AI**, then 3D-printed, wired and programmed it. It **sees, listens,
thinks, talks and emotes — 100 % on the board, no cloud** — and was built for the
[Robotics Dream Keeper Challenge](https://github.com/D-Robotics/Robotics-Dream-Keeper-Challenge).
**An era when anyone can build their own robot is surely coming!**

<p>
<img src="../photo/korosuke_robo.jpg" width="33%" alt="Korosuke robot">
<img src="../photo/20260725_korosuke-robot-revision_0.1.jpg" width="24%" alt="Korosuke rev0.1 — assembled and smiling">
</p>

- Demo video: https://www.youtube.com/watch?v=NJwj6Iazd20

## Background

**Robostadion's owner (Kazuki Murata [@gurimaruking](https://github.com/gurimaruking) /
[@robostadion_sin](https://x.com/robostadion_sin)) once said to me: "Why not build Korosuke?"**

While Murata-san and the staff were busy preparing **REK** (*1 — a robot battle event held in
Akihabara), one day I looked at the Robostadion Discord, remembered that invitation —
went to Robostadion in Akihabara, received the Korosuke parts, and got to build it!

<table>
<tr>
<th align="center">Murata-san</th>
<th align="center">uecken</th>
</tr>
<tr>
<td><img src="../photo/korosuke_murataa_at_robostadion.jpg" width="220" alt="At Robostadion: Murata-san and Korosuke"></td>
<td><img src="../photo/korosuke_uecken_at_robostadion.jpg" width="220" alt="At Robostadion: uecken and Korosuke"></td>
</tr>
</table>

**Inspiration** —

- [Disney's Olaf robot](https://thewaltdisneycompany.com/olaf-robotic-character/) — expressive animatronic eyes & face
- [Open Duck Mini (BDX)](https://github.com/apirrone/Open_Duck_Mini) — compact bipedal droid

<sub>*1 REK — overview: https://robostadion.com/rek-tokyo/ , results: https://robostadion.com/rek-tokyo/report.html</sub>

## Architecture

### Hardware

```mermaid
flowchart LR
  %% All parts are boxes. Colour = category. Pin numbers are on the wires (edge labels).
  PB["🔋 Mobile battery<br/>(power bank) 5V/3A"]:::power
  LIPO["🔋 LiPo<br/>(for servos)"]:::power
  RDK["🧠 RDK X5 (10 TOPS)<br/>(brain — everything on-device)"]:::main
  ESP["ESP32-S3<br/>(eyes/arms MCU)"]:::compute
  AMP["MAX98357A<br/>I2S amp (GAIN=9dB)"]:::module
  EYES["2× GC9A01<br/>round LCD (eyes)"]:::module
  CAM["📷 Camera C270<br/>(built-in mic)"]:::periph
  BTN["⏻ Shutdown button"]:::periph
  SPK["🔊 φ50 speaker"]:::periph
  SRV["💪 2× SG90<br/>servos (arms)"]:::periph

  PB   -->|"USB-C 5V/3A"| RDK
  CAM  -->|"USB (video + audio)"| RDK
  BTN  -->|"pin18(GPIO24) / pin20(GND)"| RDK
  RDK  -->|"USB (power + data · ttyACM0)"| ESP
  RDK  -->|"5V:pin2/4 · GND:pin6<br/>BCLK:pin12 · LRC:pin35 · DIN:pin40"| AMP
  AMP  -->|"analog +/−"| SPK
  ESP  -->|"SPI: SCK12·MOSI11·DC9·RST8<br/>CS_L10·CS_R14 · 3V3·GND"| EYES
  ESP  -->|"PWM: GPIO4(L) / GPIO5(R)"| SRV
  LIPO -->|"LiPo voltage direct (no BEC)"| SRV
  LIPO -.->|"common GND ⚠ (required)"| ESP

  classDef power   fill:#f6b73f,color:#3a2a00,stroke:#c98a12,stroke-width:2px;
  classDef compute fill:#1f6feb,color:#fff,stroke:#58a6ff,stroke-width:2px;
  classDef module  fill:#8957e5,color:#fff,stroke:#bc8cff,stroke-width:2px;
  classDef periph  fill:#2da44e,color:#fff,stroke:#3fb950,stroke-width:2px;
  classDef main    fill:#1f6feb,color:#fff,stroke:#ffffff,stroke-width:4px,font-size:22px;
```

**Legend**: 🟡 Power · 🔵 Compute (board) · 🟣 Module · 🟢 Peripheral — pin numbers are on the wires.
**Two power rails** (power bank → RDK X5 · LiPo → servos) with a **shared common ground**.
Note: the **C270 is camera *and* microphone** (its built-in mic feeds speech recognition).
Full connection table: [docs/wiring.md](../wiring.md) · [docs/hardware_block_diagram.md](../hardware_block_diagram.md).

### Software

Everything runs **on the board only** (no internet). The **brain (korosuke-monitor)** at the
center of the diagram orchestrates ears, head, mouth, eyes and arms:

- 👂 **Listen** — the mic's voice is converted to text (speech recognition, STT) and sent to the brain
- 🧠 **Think** — the brain asks a small on-board AI (local LLM) to compose the reply
- 🗣 **Speak** — the reply is turned into Korosuke's voice (TTS) and played through the amp & speaker
- 👀 **See** — the **BPU (AI chip)** detects people in the camera image; the brain tells the eyes "look there"
- 💪 **Move** — the brain commands the ESP32-S3, which drives the eye expressions (8 kinds) and the arms
- ⏻ **Power button** — Korosuke says "good night", shows ✕✕ eyes, and shuts down safely

```mermaid
flowchart LR
    CAM([UVC Camera]):::s --> YOLO
    MIC([USB Mic]):::s --> STT
    BTN([Shutdown button]):::s --> BRAIN

    subgraph RDK["RDK X5 · fully on-device"]
      direction TB
      subgraph BPU["BPU (10 TOPS) — PERCEPTION"]
        YOLO["YOLO11n-pose (19.5 FPS)"]
      end
      subgraph CPU["CPU 8× A55 — LANGUAGE"]
        STT["STT: sherpa-onnx"]
        LLM["LLM: TinySwallow-1.5B"]
        TTS["TTS: Open JTalk"]
      end
      BRAIN{{"brain (korosuke-monitor)"}}
    end

    YOLO --> BRAIN
    STT --> BRAIN
    BRAIN --> LLM --> BRAIN
    BRAIN --> TTS --> AMP["MAX98357A amp"] --> SPK([φ50 speaker]):::o
    BRAIN -->|USB / UART| ESP32["ESP32-S3 (eyes + arms)"]:::m
    ESP32 --> EYES["2× GC9A01 eyes"]:::m
    ESP32 --> ARMS["2× SG90 arms"]:::m

    classDef s fill:#1f6feb,color:#fff,stroke:#58a6ff;
    classDef m fill:#8957e5,color:#fff,stroke:#bc8cff;
    classDef o fill:#2da44e,color:#fff,stroke:#3fb950;
```

Composing a reply takes 5–10 seconds — the eyes show a "thinking" animation meanwhile.

## Build process

### Mechanics (3D-printed body)

The 3D parts were **co-created by Murata-san and AI**.
The part data lives in [hardware/3d_models/korosuke_print](../../hardware/3d_models/korosuke_print/)
(we used **v1** this time — v2+ folders exist but are untested!).

<p>
<img src="../photo/korosuke_3Dprint_parts.jpg" width="49%" alt="Korosuke parts laid out in the slicer">
<img src="../photo/korosuke_3Dparts_bulding.jpg" width="49%" alt="Assembling the parts">
</p>

The enclosure parts:

- **Head**: two hemispheres; one gets **eye holes**, and the round-LCD eyes are inserted from the inside
- **Torso**: a cylinder that houses the RDK X5, camera, speaker and servos — **open at top & bottom**
  for installing parts, with **side holes for the rope-arms**
- **Arms & hands**: 8 linked rings threaded with a string; one end ties to the hand, the other to a
  servo (= the **rope-pull arm** — the servo pulls the string and the arm rises)
- **Torso base**: there was no cable exit at first, so we **cut the bottom open with an ultrasonic cutter**
- **Feet**: static this time — glued straight onto the base

<p>
<img src="../photo/head_v1.jpg" width="49%" alt="Head part v1">
<img src="../photo/body_ver2.jpg" width="49%" alt="Torso part v2">
</p>

### Wiring

Wired exactly as documented in the repo:

- [docs/wiring.md](../wiring.md) — two power rails (power bank = RDK / LiPo = servos) + **common ground**
- [docs/hardware_block_diagram.md](../hardware_block_diagram.md) — verified pin maps (ESP32-S3 ⇔ eyes)
- [firmware/max98357a](../../firmware/max98357a/) — I2S speaker amp on the 40-pin header (custom kernel driver)

### Software, built with AI

**Let AI write it** — we used Visual Studio Code + Claude Code. (Sorry, we haven't mastered
RDK Studio yet — it can likely do the same, and we'll give it another try!)

### Operation (Korosuke Monitor)

A browser monitor shows speech-recognition results, conversation replies, and **person
presence / skeleton-based motion recognition** in real time.

Open `http://[RDK X5's IP address]:8080/` (the IP depends on your connection and environment).

![Korosuke Monitor — live camera + skeleton + speech recognition + conversation log](../photo/korosuke-monitor.png)

### Tools & jigs

- **Velcro tape** — handy for attaching parts to the 3D-printed body — [Amazon](https://www.amazon.co.jp/dp/B0GJZJM4TG)
- **Ultrasonic cutter** (or an alternative) — handy for post-processing the 3D-printed parts. Look for one on AliExpress — anything that melts plastic works, even a heated metal needle
- **3D printer** — required to print the parts! (we used a **Bambu Lab A1**; parts are within 18 cm, so an **A1 mini** should *just* fit)
- **Double-sided tape** — handy for bonding parts
- **String** — needed to move the hands (rope-pull arms)
- **Zip ties** — needed to tune the rope arms — [Daiso](https://jp.daisonet.com/products/4550480088891)
- **Breadboard (small)** — used for the ESP32-S3 wiring
- **Jumper wires** (M-M / M-F) — used to connect the parts

## Afterword

Robots have become something you can build with just **mechanics + electronics + software**
and a little workshop gear (a bit of soldering, an ultrasonic cutter if needed).

This build took roughly **15 h for the 3D parts + 10 h for electronics & software ≈ 25 hours**.
With the enclosure and parts ready, rebuilding an existing robot is even faster. And for a
somewhat smaller robot — halve the body, print fast (AI designs the enclosure in ~3 h), let AI
write the electronics and software — **a custom robot in one day, maybe ~5 hours, is within reach!**

I am Korosuke!

## Troubleshooting (gotchas)

**① USB-C power is plugged in, but no HDMI output and no USB-C IP link to the PC**
→ Check whether the **green LED next to the USB-C connector is lit**. Perhaps due to
cable/adapter compatibility, the board sometimes silently fails to boot (= green LED off)…

**② No IP connectivity (USB-C / Ethernet)**
→ Configure the network with the [official guide](https://developer.d-robotics.cc/rdk_studio_doc/en/user-guide/network-config/).
RDK Studio may fail to apply the settings, or they may **revert**. Re-run the steps, or open a
terminal over HDMI and check the board's IP with `ip addr`; on Windows check with `ipconfig`
that your interface has an address.

> FYI: this project uses a **static eth0 IP 192.168.0.200** and **192.168.128.10 on the USB-C
> (usb0) gadget link** for maintenance ([docs/network_setup.md](../network_setup.md)).

---
*#RoboticsDreamKeeper #RDKX5 #ROS2 #animatronics*
