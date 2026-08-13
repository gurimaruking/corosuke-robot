# 5-minute talk script (EN) — "I am Korosuke!"

> 4 min talk + 1 min demo. ~130 words/min (comfortable pace).
> Slides: [talk_5min.html](talk_5min.html) (open locally, arrow keys; timer starts on first key).
> Numbers in brackets = target clock time when you START the slide.

---

## [0:00] Slide 1 — Title (30 s)

Hello everyone! Thank you for having me tonight.
My name is uecken, from Tokyo, Japan.
This is my first robot — and this is **Korosuke**!
He is a samurai robot from the Japanese anime *Kiteretsu Daihyakka*.
My message today is simple: **an era when anyone can build a robot is coming.**
Let me show you why.

## [0:30] Slide 2 — Background (40 s)

First, the background. I'm a wireless engineer — not a robotics person.
I wanted to join this challenge, but I only had ideas. No robot.
Then **Murata-san**, the owner of **Robostadion** — a robot co-working space in Akihabara —
said to me: **"Why not build Korosuke?"**
So I went to his studio, received the 3D-printed parts, and started building.
The design was inspired by Disney's Olaf robot and Open Duck Mini.

## [1:10] Slide 3 — What is Korosuke? (35 s)

So, what is Korosuke?
His brain is **one D-Robotics RDK X5 board**.
He **sees** you, **listens**, **thinks**, **talks back**, and **shows emotions** with his round eyes.
And everything — vision, speech recognition, a local LLM, text-to-speech —
runs **100% on the board. No cloud. No API keys.**
You can talk to him in Japanese or English.

## [1:45] Slide 4 — Hardware (35 s)

Here is the hardware.
A power bank powers the RDK X5.
A small camera — which is **also the microphone**.
**One ESP32-S3** drives the two LCD eyes and the rope-pull arms.
A tiny I2S amp drives the speaker.
Two power rails, one common ground.
That's all — **no custom PCB, just simple wiring.**

## [2:20] Slide 5 — Software (35 s)

The software is one "brain" program.
Your speech becomes text; a small local LLM — TinySwallow 1.5B — thinks of a reply;
Open JTalk gives him a voice.
Meanwhile the AI chip — the **BPU** — finds people at about 20 FPS, so **his eyes follow you**.
Thinking takes five to ten seconds, so he shows "thinking eyes".
This web monitor shows everything in real time.

## [2:55] Slide 6 — Build: 25 hours with AI (35 s)

How long did it take? **About 25 hours** — 15 for 3D printing, 10 for electronics and software.
The tools are simple: a 3D printer, velcro tape, string, zip ties.
And here is the important part:
I designed the body, the wiring, and the software **together with AI**.
I placed the parts and I debugged. AI wrote the code.
**I was the eyes and the hands of the AI.**

## [3:30] Slide 7 — Message (30 s)

That's my message.
Robots used to need big teams.
Now, one beginner — with AI, a 3D printer, and good friends at a robot space —
can build a talking robot in 25 hours. Someday soon, maybe in one day.
Everything is open source on GitHub.
Now — let's meet him. **Korosuke, say hello!**

## [4:00] Slide 8 — DEMO (60 s)

1. Call him: 「コロすけ！」 → his **eyes find and follow** you. *(5 s)*
2. Ask one short question: 「コロすけ、こんにちは！元気？」 *(5 s)*
3. While he thinks (5–10 s), say to the audience:
   *"He is thinking now — the local LLM is running on the board. These are his thinking eyes."*
4. He answers in his "〜nari!" voice. *(10 s)*
5. Raise your hand → he **waves his arm** back. *(10 s)*
6. Finish: press the power button →
   *"Good night, Korosuke."* → ✕✕ eyes.
   *"When the eyes show ✕✕, it's safe to unplug. That's his good-night sign. Thank you!"* *(15 s)*

**Fallback (if he stays silent):** play the two clips —
[korosuke_demo_10s.mp4](../photo/korosuke_demo_10s.mp4) (conversation) and
[arm_rope_pull.mp4](../photo/arm_rope_pull.mp4) (arm) — then close with the good-night line.

---

### Pre-flight checklist (5 min before)

- Type "こんにちは" in the **Chat box** of the monitor → confirm reply + voice
- Settings: 「話しかけに反応」「LLM会話」ON / language = auto / volume OK
- Do **not** touch language toggles during the demo
- Keep the two fallback video tabs open
- Emergency reset: `http://192.168.128.10:8080/set?react_speech=1&use_llm=1&react_greet=1`
