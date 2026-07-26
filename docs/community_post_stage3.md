# Community post — Stage 3 (Launch) 告知ドラフト

> そのままDiscord/フォーラムに貼れる下書き。`<YouTube link>` を差し替えてください。
> 短縮版(Discord向け)と長め版(フォーラム/Note向け)の2つを用意。

---

## 短縮版（Discord / X 向け）

🤖✨ **Project Korosuke — Stage 3 (Launch) done!**

コロ助（キテレツ大百科）を **RDK X5** で本物のアニマトロニクスにしました。**100%オンデバイス・クラウド無し**で：

👀 見る（BPU YOLO11-pose ~19.5FPS）→ 👂 聞く（sherpa-onnx STT）→ 🧠 考える（TinySwallow-1.5B on CPU、考え中は目がくるくる）→ 🗣 話す（Open JTalk、「〜ナリ」）→ 😊 笑う → 🙌 手を振る → 🌙 ボタンで安全終了（おやすみ→✕✕の目）

🔧 見どころ：スピーカー小型化のために **MAX98357A I2Sアンプ用のカーネルドライバを自作**（vendorカーネルに無い）。BPUでLLMは回せない（S100専用）ことも公式パッケージから検証。

🎥 デモ： `<YouTube link>`
💻 リポジトリ： https://github.com/gurimaruking/corosuke-robot
📄 ショーケース： https://github.com/gurimaruking/corosuke-robot/blob/main/STAGE3.md

#RDKX5 #DRobotics #ROS2 #EdgeAI

---

## 長め版（フォーラム / Note / Hackster 向け）

### Korosuke, the fully on-device animatronic — Stage 3 launch 🚀

I rebuilt **Korosuke (コロ助)** from *Kiteretsu Daihyakka* as a ~46 cm desktop robot whose
brain is a single **D-Robotics RDK X5**. Everything — vision, speech-to-text, LLM dialogue,
text-to-speech, expression, gesture, touch and actuation — runs **on-device, no cloud, no
dev PC at runtime**.

**What it does:** power it on and it wakes up and greets you ("おはようナリ！"), tracks you
with BPU YOLO11-pose, listens, thinks (the eyes do a "考え中" animation while the on-device
LLM ponders), talks back in a pitched "…ナリ" voice, smiles, reacts to gestures and to being
petted, waves its rope-pulled arms, and shuts itself down safely on a button press
(goodnight voice → ✕✕ "safe-to-unplug" eyes).

**The engineering story I'm proud of:**
- **BPU does perception, CPU does language.** I verified from D-Robotics' *own* X5 packages
  that the X5 BPU can't accelerate an LLM (that's an S100/Nash feature) — so putting
  perception on the BPU and dialogue on the 8× A55 CPU is the *correct* design.
- **Custom kernel work to shrink the speaker.** No MAX98357A codec driver ships in the RDK
  kernel, so I built an **out-of-tree ALSA codec driver + device-tree overlay** and a
  playback DSP so a tiny φ50 speaker is loud without clipping.
- **Ships like a product:** systemd auto-start on power-on, a physical safe-shutdown, a
  self-healing audio card, and a tabbed web dashboard to tune everything live.

Benchmarks (all measured on the board): YOLO11n-pose ~19.5 FPS, STT RTF 0.44, LLM
1.5–3.3 tok/s, and the whole stack runs at ≈50 °C (< 60 °C) even with the LLM pinning
~600 % CPU.

🎥 **Demo video:** https://youtu.be/NJwj6Iazd20
💻 **Repo:** https://github.com/gurimaruking/corosuke-robot
📄 **Full showcase & benchmarks:** https://github.com/gurimaruking/corosuke-robot/blob/main/STAGE3.md
🧩 **Design:** [PROPOSAL.md](https://github.com/gurimaruking/corosuke-robot/blob/main/PROPOSAL.md) · 🗺 [ROADMAP.md](https://github.com/gurimaruking/corosuke-robot/blob/main/ROADMAP.md)

Built for the **D-Robotics Robotics Dream Keeper Challenge**. Fan-made, non-commercial
tribute — character © Fujiko F. Fujio.

*「ワガハイはコロ助ナリ！」* 🤖
