# RDK X5 の BPU で LLM を加速できるか — 調査結論

多言語（英・中・日）で公式ドキュメント・GitHub・HuggingFace・コミュニティ実測を
横断調査し、主要主張を敵対的に検証（8主張が確定・却下0）した結論。

## 結論: 現時点では **できない（明確に NO）**

RDK X5 の BPU「Bayes-e」(Sunrise5, 10 TOPS) には、自己回帰型 LLM（トランスフォーマの
デコード＝KV-cache アテンション）を **BPU 上で走らせる公式コンパイラ/ランタイム経路が
存在しない**。BPU が YOLO で ~2% しか使われず空いていても、それを LLM デコードに
転用する手段がない。「BPU で LLM を回す」を本気で狙うなら **上位機 RDK S100 (Nash BPU)
への移行が唯一の正攻法**。

したがってコロ助の設計 — **知覚を BPU、対話を 8×A55 CPU** — はこのボードにとって
"正しい" アーキであり、克服し損ねた制約ではない。

## 根拠（検証済み・一次情報）

1. **X5 用の公式 LLM ツールチェーンは存在しない。** 「大模型工具链 / LLM Toolchain」は
   **RDK S100 ツリー配下だけ**に存在（DeepSeek-R1-Distill-Qwen, InternLM2, Qwen2.5 等の
   量子化・対話・PPL評価に対応）。X5 ドキュメント配下には同等ページが皆無。
   <https://d-robotics.github.io/rdk_doc/rdk_s/Advanced_development/toolchain_development/LLM_Toolchain/>

2. **X5 の model zoo は CV 専用**（分類/検出/セグメン/ポーズ/OCR/CLIP）。LLM は別リポの
   **S100 専用 model zoo** にのみ存在。
   <https://github.com/D-Robotics/rdk_model_zoo> / <https://github.com/D-Robotics/rdk_model_zoo_s>

3. **決定的証拠 — D-Robotics 自身の X5 パッケージも LLM は CPU 実行。**
   - `magicbox_qwen_llm`: Qwen2.5-1.5B-Instruct を GGUF(Q5_K_M) で **8×A55 CPU** の
     llama.cpp 実行（`-DPLATFORM_X5=ON` でビルドするがデコーダに BPU 経路なし）。
     ＝コロ助の TinySwallow-1.5B Q5 on llama.cpp と同クラス。
     <https://github.com/D-Robotics/magicbox_qwen_llm>
   - VLM `InternVL2_5-1B-GGUF-BPU` ですら**分業**: 視覚エンコーダ(ViT)だけ BPU 化
     (`vit_model_int16.bin`)、**言語モデル本体は Qwen2.5-0.5B の GGUF を CPU 実行**。
     <https://huggingface.co/D-Robotics/InternVL2_5-1B-GGUF-BPU/tree/main>

4. **技術的理由**: Bayes-e/HB_DNN は固定形状 INT8/INT4 の畳み込み系(CV)に最適化。
   自己回帰デコードはトークン毎に伸びる**可変長KV-cacheアテンション**が本質で、動的形状・
   逐次ステップ・帯域律速。CNN特化BPUと不一致で、10 TOPSのピーク値は効かない。
   S100/Nash は新ランタイム(UCP)＋Transformer最適化BPUを持ち、LLM ツールチェーンは
   その上に成立。X5/Bayes-e 世代にはオンBPU LLM デコードの土台自体が無い。

> 注意: X5 マーケの「Transformer/RWKV 対応」は **ViT 等の知覚用トランスフォーマ構造**を
> BPU にコンパイルできるという意味で、チャット LLM をBPUで回す主張ではない（混同注意）。

## 実務推奨（CPU 側で速くする）

BPU化に挑む価値は無い（公式サポート・実例ともゼロ）。CPU 最適化で詰める:

- **量子化を下げる**: Q5_K_M → **Q4_K_M**（帯域律速なので体感で速くなる）
- **スレッド数**: `-t 4〜6` を実測で最適点探索（全コア割当が最速とは限らない。7前後で頭打ち。
  ※コロ助では推論中の ping ロスを避けるため現状 6 スレッド/現状維持）
- **ストリーミング出力**: トークン逐次表示＆TTS逐次投入で **体感の待ち(TTFT)** が激減
- **プロンプト固定 + KV-cache 活用**、より小さい 0.5B 級への置換も一手
- **どうしても BPU で LLM を加速したいなら → RDK S100 へ移行**（唯一の公式・実証経路）

関連: [[korosuke-dialogue-decisions]] / [dialogue_stack_research.md](dialogue_stack_research.md)
