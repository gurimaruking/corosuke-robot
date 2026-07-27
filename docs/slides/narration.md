# Korosuke — ナレーション台本 / Narration script

`korosuke_stage3.md` のスライド順。各スライド 15〜25秒 ≒ 全体 4〜5分。
録画しながら読むか、スライドごとに録音して結合してください。JA/ENどちらかを選択。

---

### 1. タイトル / Title
- **JA:** これは「コロ助」。D-RoboticsのRDK X5だけで、見て・聞いて・考えて・日本語でも英語でも話す、完全オンデバイスの対話ロボットです。クラウドは一切使いません。
- **EN:** This is Korosuke — an interactive animatronic that sees, listens, thinks, and talks in Japanese or English, running entirely on a D-Robotics RDK X5. No cloud at all.

### 2. 概要 / What is it
- **JA:** キテレツ大百科のコロ助を、約46センチで作りました。頭脳はRDK X5、目と腕はESP32-S3。知覚も音声もLLMも、すべてこのボード上で動きます。APIキーもPCも不要です。
- **EN:** It's a 46-centimeter Korosuke from Kiteretsu. The brain is the RDK X5, the eyes and arms an ESP32-S3. Perception, speech, and the LLM all run on the board — no API keys, no PC.

### 3. Stage 1→3
- **JA:** ステージ1でBPUの物体認識を実証し、ステージ2でRDK X5を頭脳の中心に据えるROS 2設計をまとめ、ステージ3で対話する実機に仕上げました。作り直しではなく、積み上げです。
- **EN:** Stage 1 proved on-device BPU vision, Stage 2 designed the RDK X5 as the single brain under ROS 2, and Stage 3 shipped the talking robot. Each stage builds on the last.

### 4. アーキテクチャ / Architecture
- **JA:** BPUは人物と骨格の検出を毎秒約19.5フレームで担当。8コアのCPUが音声認識・LLM・音声合成を同時にこなします。X5のBPUはLLMを加速できないので、知覚はBPU・言語はCPU、が正解です。
- **EN:** The BPU runs pose detection at about 19.5 FPS. The 8-core CPU handles speech, LLM, and text-to-speech together. The X5 BPU can't accelerate LLMs, so perception-on-BPU, language-on-CPU is the right split.

### 5. 音声パイプライン / Voice pipeline
- **JA:** マイクから、VAD、音声認識のSenseVoice、対話はTinySwallow、音声合成はOpen JTalkとespeak。全部オンデバイスです。これはD-Robotics公式の音声対話構成とも一致しています。
- **EN:** Mic, VAD, SenseVoice for recognition, TinySwallow for dialogue, Open JTalk and espeak for voice — all on-device. This mirrors D-Robotics' own official voice-interaction stack.

### 6. バイリンガル / Bilingual (キモ / the highlight)
- **JA:** 一番の特徴が、日本語・英語・自動の切り替えです。ボタン一つで、認識も、返答も、声も、画面表示も丸ごと切り替わります。オートなら、話した言語をコロ助が自分で判断して答えます。
- **EN:** The highlight is Japanese / English / Auto switching. One button flips recognition, replies, voice, and the dashboard together. In Auto, Korosuke detects the language you speak and answers in it.

### 7. 表現 / Expressive
- **JA:** 目は8種類の表情。考えている間は「考え中」の目になります。腕は手を振ったりバンザイしたりします。声は高めの「〜ナリ」口調です。
- **EN:** The eyes have eight emotions, including a "thinking" look while the LLM works. The arms wave and cheer, and Korosuke speaks in his high-pitched "…nari" voice.

### 8. カスタムHW / Custom hardware
- **JA:** 小さな体に音を入れるため、ベンダーカーネルに無かったI2Sアンプのドライバとデバイスツリーを自作しました。電源を入れると挨拶し、ボタンで安全に終了、電源を抜いてよい合図まで出します。
- **EN:** To fit sound in a small body, I wrote an out-of-tree driver and device-tree overlay for the I2S amp the kernel didn't support. It greets on power-up and shuts down safely with a clear "safe to unplug" signal.

### 9. 2つの実装 / Two integrations
- **JA:** 同じパイプラインを、低遅延のモノリスと、ROS 2グラフの2通りで実装しています。動画はモノリス版です。
- **EN:** The same pipeline ships two ways — a low-latency monolith and a ROS 2 graph. This demo shows the monolith.

### 10. 正直なスコープ / Honest scope
- **JA:** 未実装も正直に。2軸の口・リップシンク、首サーボ、二足歩行、背中の刀は今回入っていません。動くものだけをお見せします。
- **EN:** And honestly — the 2-axis mouth, neck servo, bipedal walking, and the sword are not in this build. We only show what actually works.

### 11. デモ / Demo
- **JA:** それでは実機のデモです。起きて挨拶し、人を目で追い、日本語と英語で会話し、ジェスチャに反応し、最後は安全に終了します。
- **EN:** Here's the live demo — waking and greeting, following a face, chatting in Japanese and English, reacting to gestures, and shutting down safely.

### 12. 結び / Closing
- **JA:** コロ助は、完全オンデバイス・バイリンガル・オープンソース。RDK X5で作りました。ありがとうナリ！
- **EN:** Korosuke — fully on-device, bilingual, and open-source, built on the RDK X5. Thank you!
