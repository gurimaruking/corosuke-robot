# コロ助 対話スタック調査（LLM + 音声合成）— 完全オンデバイス版

> 2つの深掘り調査(各3票検証)の結論。大方針: **クラウド禁止・完全オンデバイス**。
> 対象: RDK X5(8x Cortex-A55 aarch64, 10 TOPS BPU, 8GB, 空き約16GB)。2026-07-24。

## 全体結論

「見る→気づく→挨拶」は完成済み。残る「聞く→考える→話す」を完全ローカルで組む構成:

```
マイク → sherpa STT(✅実装済) → dialogue_node(LLM=ローカル化) → voice_node(TTS=要導入) → SP(✅)
```

---

## A. LLM（考える）

### 結論
- **llamaを積むのは正解。** `hobot_llamacpp`(llama.cpp/CPU)が唯一の完全オンデバイス日本語生成の現実解。
- **⚠️ BPUはLLMを加速しない。CPU(8xA55)のみ。** BPU(Bayes-e)が効くのは視覚(YOLO/VLMのViT)だけ。独立レビューも "LLM support is marketing hype — no NPU acceleration"。BPU-LLM変換(.hbm)はRDK **S100専用**でX5非対応。
- **本命モデル: TinySwallow-1.5B-Instruct (Q5_K_M, 1.13GB, Apache-2.0)** — 日本語特化(Sakana AI×東京科学大)。デフォルトのQwen2.5-0.5Bは日本語が弱く(★1/5, 中国語混入)「〜ナリ」人格に不足。

### 速度（重要な但し書き）
| モデル | tok/s | 出典 |
|---|---|---|
| Qwen2.5-0.5B | **19.76** | **A55実機実測** |
| TinySwallow-1.5B | 約6〜8 | ⚠️ 他ARM(A76)からの外挿・**A55実測ではない** |
| sarashina2.2-3B | 約3〜4 | 外挿 |

「1〜2秒で話し始め」は、①system prompt(約400tok)をKVキャッシュ常駐 ②句点単位ストリーミングで最初の一文だけ即TTSへ ③応答1〜2文制限、で1.5Bでも概ね達成見込み。**要実機ベンチ**(`llama-bench -t 8`)。

### 統合（推奨=案A・最小改修）
[dialogue_node.py](../ros2_ws/src/korosuke_nodes/korosuke_nodes/dialogue_node.py) のLLM呼出先を、クラウドClaude([:83-90](../ros2_ws/src/korosuke_nodes/korosuke_nodes/dialogue_node.py#L83-L90))からローカル `llama-server`(OpenAI互換 `/v1/chat/completions`)に差し替えるだけ。人格`COROSUKE_SYSTEM_PROMPT`・履歴・表情・目・VOICEVOX・フォールバックは全て無改造で活きる。不通時は既存`FALLBACK_*`(ナリ)へ。

### RDK Studioの「Local models」(Ollama)について
Ollamaも中身はllama.cpp＝**性能は①と同じ**。ただしRDK StudioのStorage設定が`C:\Users`を指す＝**PC側にインストールされる疑い**(要確認)。PC依存だと自律ロボットにならないので、①(ボード上hobot_llamacpp)か③(Ollamaをボードに直接導入)が本命。

---

## B. 音声合成（話す）

### 結論
- **ずんだもんは実現可能。** 声質・ライセンスとも良好。
- **当面(固定挨拶=canned)**: **PCでVOICEVOX ずんだもん(spk=3)のWAVを事前生成→ボードでaplay**。ボードのストレージ消費ゼロ(WAV数個で数MB)。既存[voice_node.py](../ros2_ws/src/korosuke_nodes/korosuke_nodes/voice_node.py)のspk=3/speed1.2/pitch0.05と完全互換。
- **将来(LLM返答=dynamic)**: ボード上リアルタイム合成。第一候補 **VOICEVOX CORE(約90-170MB)**(ずんだもん声維持)、確実な保険 **Open JTalk(apt, 約100-130MB)**(高速だがずんだもん不可)。

### 比較
| エンジン | aarch64 | ずんだもん | 速度(A55) | サイズ | ライセンス |
|---|---|---|---|---|---|
| VOICEVOX ENGINE | ○公式arm64 | ◎ | △短文2-6秒(推定) | 重 2.5-3GB | 個人無償/クレジット要 |
| **VOICEVOX CORE** | ○wheel | ◎ | △-○ 1-3秒(推定) | **軽 90-170MB** | MIT+音声クレジット要 |
| **Open JTalk** | ○apt | ✕(mei等で甲高化) | ◎実時間の数分の一 | 軽 100-130MB | BSD/CC BY |
| AquesTalk Pi | ○ | ✕(要ピッチ加工) | ◎極速 | 極小5MB | グレー(個人趣味のみ) |
| ピッチシフト(sox/ffmpeg) | ○apt | 加工層 | ◎ | 極小 | GPL/LGPL |

### コロ助の甲高い声
- VOICEVOX: `pitchScale`をさらに上げ+`intonationScale`調整。
- Open JTalk(mei): `-fm +4〜+8`(高く) `-a 0.42`(細く) `-r 1.15`(話速)。
- 汎用ピッチシフト: `ffmpeg -af "asetrate=24000*1.3,aresample=24000,atempo=1/1.3"` or `sox in out pitch 500`。`voice_node.py`の`_play()`前に1コマンド挟むだけ、TTSより桁違いに軽い。

### ライセンス注意
- **ずんだもん**: 商用/非商用無料だが**「VOICEVOX:ずんだもん」クレジット表示必須**(機体に銘板 or 音声前後に挿入で可)。個人コロ助は申請不要。
- Open JTalk mei: CC BY(「名古屋工業大学」表記要)。AquesTalk: 個人趣味のみ無償・組込配布は要問合せ(避けるのが無難)。

---

## 実務ブロッカー（今）
- **ボードが現在インターネット不通**(DNS解決失敗、数日前は可)。TinySwallow(1.1GB)やVOICEVOX CORE/Open JTalkのダウンロードは**このままでは失敗**。
- 対策: ボードのネット復旧、または **PC側でDL→scp転送**。
- ずんだもんWAV(canned)を得るには、**PCにVOICEVOXを導入**する必要がある(PCにもボードにも現状未導入)。

## 次の判断ポイント
1. ずんだもん挨拶を今作るか → PCにVOICEVOX導入が必要
2. LLM対話に進むか → TinySwallow(1.1GB)の入手経路(ネット復旧 or PC経由)を決める
3. 動的TTSは VOICEVOX CORE(ずんだもん) か Open JTalk(高速) か → 実機ベンチで決定
