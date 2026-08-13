# 5-minute talk script (EN) — "I am Korosuke!"

> 4 min talk + 1 min demo · ~130 words/min. Follows [intro_en.md](../blog/intro_en.md).
> Slides: [talk_5min.html](talk_5min.html) (open locally; ←/→ keys; timer starts on first key, R resets).
> Numbers in brackets = clock time when you START the slide.

---

## [0:00] Slide 1 — Title (30 s)

Hello everyone! Thank you for having me tonight.
My name is uecken, from Tokyo, Japan.
This is my first robot — and this is **Korosuke**,
the karakuri robot from the Japanese anime *Kiteretsu Daihyakka*.
My message today is simple: **an era when anyone can build a robot is coming.**
Let me show you why.

## [0:30] Slide 2 — Introduction (35 s)

Korosuke is the partner robot that Kiteretsu builds in the story by Fujiko F. Fujio.
Our Korosuke is a **fan-made robot, built by Robostadion** —
a robot co-working space in Akihabara.
His brain is **one D-Robotics RDK X5 board**.
We designed the mechanics, electronics and software **together with AI**.
He **sees, listens, thinks, talks and emotes** — **100% on the board. No cloud.**
And he speaks Japanese and English.

## [1:05] Slide 3 — Background (35 s)

A little background. I'm a **wireless engineer** — this is my first robot.
One day **Murata-san**, the owner of Robostadion, said to me:
**"Why not build Korosuke?"**
Later I saw the Robostadion Discord, remembered that invitation,
went to his studio, received the 3D-printed parts — and got to build it!
The design was inspired by **Disney's Olaf robot** and **Open Duck Mini**.

## [1:40] Slide 4 — Hardware (35 s)

Here is the hardware.
At the center is the **RDK X5** — it runs all the main functions:
vision, speech recognition, dialogue, and voice.
The camera is **also the microphone**.
The eyes and the arms are controlled **through one ESP32-S3**, connected by USB.
Only the servo power is special: the servos can draw **more than one amp**,
so they run from a **separate LiPo battery**.
And for the speaker, we use a tiny **I2S amp module** to keep everything small.
**No custom PCB — just simple wiring.**

## [2:15] Slide 5 — Software (35 s)

The software is one "brain" program — korosuke-monitor.
It **listens** — your voice becomes text.
It **thinks** — a small local LLM, TinySwallow 1.5B, writes a reply.
It **speaks** — with Open JTalk.
It **sees** — the **BPU**, the AI chip, finds people at about 20 FPS,
so **his eyes follow you**.
And it **moves** — the brain sends commands to the ESP32-S3,
which switches the **eight eye emotions** and waves the **arms**.
Thinking takes 5 to 10 seconds — so he shows **"thinking eyes"**.
This web monitor shows everything in real time.

## [2:50] Slide 6 — Build process (40 s)

The build. The 3D parts were **co-created by Murata-san and AI** —
all the files are in the repo.
The head is two hemispheres. The torso holds everything.
The arms are rings on a string — the servo pulls the string, and the arm rises.
**You can see it moving right here** *(point at the looping video)*.
Wiring followed the repo documents exactly.
And the software? **We created it together with AI.**
I placed the parts, and I debugged — **I was the eyes and hands of the AI.**
The tools are simple: a 3D printer, velcro, tape, string, zip ties.

## [3:30] Slide 7 — Afterword (30 s)

It took about **30 hours** — 15 for printing, 15 for electronics and software.
With AI, a smaller robot could take maybe **five hours** —
**a custom robot in one day is within reach.**
Everything is **open source** on GitHub.
That is my message: **anyone can build a robot.**
Now — let's meet him. **Korosuke, say hello!**

## [4:00] Slide 8 — DEMO (60 s)

1. Call him: 「コロすけ！」 → his **eyes find and follow** you *(5 s)*
2. Ask: 「こんにちは！元気？」 *(5 s)*
3. While he thinks (5–10 s):
   *"He is thinking now — the local LLM is running on the board. These are his thinking eyes."*
4. He answers in his "〜nari!" voice *(10 s)*
5. Raise your hand → he **waves back** *(10 s)*
6. Press the power button → *"Good night, Korosuke."* → ✕✕ eyes.
   *"When the eyes show ✕✕, it's safe to unplug. That's his good-night sign. Thank you!"* *(15 s)*

**Fallback (if he stays silent):** play
[korosuke_demo_10s.mp4](../photo/korosuke_demo_10s.mp4) and
[arm_rope_pull.mp4](../photo/arm_rope_pull.mp4), then close with the good-night line.

---

### Pre-flight checklist (5 min before)

- Type "こんにちは" in the monitor **Chat box** → confirm reply + voice
- Settings: 「話しかけに反応」「LLM会話」ON / language = auto / volume OK
- Do **not** touch language toggles during the demo
- Keep the two fallback video tabs open
- Emergency reset: `http://192.168.128.10:8080/set?react_speech=1&use_llm=1&react_greet=1`
