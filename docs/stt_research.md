# RDK X5 音声認識(STT)調査 — コロ助の「耳」をどう作るか

> 調査日: 2026-07-19 / 調査者: 引き継ぎ技師 + Claude
> 一次情報: 実機のaptリポジトリ(直接確認)、[hobot_audio README](https://github.com/D-Robotics/hobot_audio/blob/main/README.md)、[最新ドキュメントセンター](https://d-robotics.github.io/rdk_doc_center/en/)
> 現状: vosk-model-small-ja-0.22 (48MB) で日本語STT動作実証済み(2026-07-19、Web監視モニタで確認可)

## 結論(先に要点)

| 問い | 答え |
|---|---|
| D-Robotics純正のASRはあるか | **ある**(hobot_audio, BPU実行)。ただし**中国語のみ・専用マイクHAT前提** |
| コロ助(日本語)に純正ASRは使えるか | **そのままでは使えない**。日本語STTはサードパーティ(vosk/sherpa-onnx/whisper系)継続が正解 |
| 純正スタックに利用価値はあるか | **ある**。マイクアレイHAT+VoIPモードで「BPUノイズ除去済み音声」だけもらい、日本語STTに食わせるハイブリッドが有望 |

## 1. D-Robotics純正音声スタック(Sunrise SoC特化部分)

実機のaptリポジトリに以下が**インストール可能な状態で存在**する(2026-07-19実機確認):

| パッケージ | 内容 |
|---|---|
| `tros-humble-hobot-audio` | 音声処理本体。**BPUで実行**: ウェイクワード / コマンド語 / **ASR** / DOA(音源方向) / エコーキャンセル / 遠距離(3-5m)ノイズ除去 |
| `tros-humble-hobot-tts` | 純正TTS(発話) |
| `tros-humble-chatbot` | 純正チャットボット(音声対話の見本) |
| `tros-humble-audio-control` | 音声コマンドでロボット制御 |
| `tros-humble-audio-tracking` | 音源方向へ体を向ける(DOA利用) |
| `hobot-audio-config` | マイクHAT用の設定/dtboファイル |

### hobot_audio の重要な制約([README](https://github.com/D-Robotics/hobot_audio/blob/main/README.md)より)

1. **対応言語は中国語のみ。** 既定ウェイクワードは「地平线你好」。カスタムウェイクワード可(`config/hrsc/cmd_word.json`)だが「中国語推奨・3〜5文字」と明記。**日本語ASRは非対応**
2. **専用マイクアレイHATが前提。** Waveshare製の円形4マイク or 2マイクアレイ。USBマイクは公式サポート外(デバイス番号変更で動く可能性はあるが未保証)
3. README(main)の対応ボード記載は**RDK X3**。X5対応は要追加確認(コミュニティではX5の遠距離ASR言及あり — ブランチ/新版の可能性)
4. 出力: `/audio_smart`(ウェイク・コマンド・DOA) と `/audio_asr`(認識文字列)。**ノイズ除去(VoIP)モードとASRモードは排他**

### コロ助にとっての意味

- 「コロ助！」というウェイクワードを純正スタックでやるのは**不可**(中国語前提)
- ただし**VoIPモード**なら「BPUでエコキャン・ノイズ除去した綺麗な音声ストリーム」だけを出せる
  → これを日本語STT(vosk等)の入力にする**ハイブリッド構成**は、スピーカーで自分が喋りながら聞き取る(barge-in)場面で効く
  → ただしマイクアレイHAT(Waveshare 2/4mic)の購入が必要
- `audio_tracking`(音の方に振り向く)はDOAが取れれば言語非依存 → **「呼ぶと振り向くコロ助」**に流用できる可能性

## 2. 日本語STTの選択肢(サードパーティ)

> ✅ **深掘り調査完了(2026-07-19)**: 103エージェント・全主張3票の敵対的検証済み。要点:
>
> - **本命 = sherpa-onnx + ReazonSpeech Zipformer** (`sherpa-onnx-zipformer-ja-reazonspeech-2024-08-01`)
>   日本語35,000時間学習・159Mパラメータ。**CER 6.45%(JSUT)でWhisper Large-v3(7.18%)を上回り**、
>   int8エンコーダは148MB。aarch64 Linux公式対応。[sherpa-onnx公式](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/index.html) / [ReazonSpeechブログ](https://hilab.jp/blog/reazonspeech-v21-setting-a-new-standard-in-japanese-asr)
> - **制約**: このモデルは**非ストリーミング専用**(sherpa-onnxに日本語ストリーミングモデルは存在しない、公式カタログ検証済)。
>   実運用は **Silero VADで発話区間を切って区間ごとにデコードする疑似ストリーミング**(公式バイナリあり)。
>   voskのような逐次部分認識は失われる — 代わりにVAD必須構成が「えーっと」幻聴対策を兼ねる
> - **Whisper系のARM実測**(文献): tinyのみ実時間(RTF 0.24-0.46 @RPi4/5)、base以上はRTF≥1.0 →
>   当方のkotoba実測RTF 7.03と整合。A55でのWhisper系対話利用は全滅
> - **ウェイクワード「コロ助!」の既製品はゼロ**(検証済): sherpa-onnx KWSはzh/enのみ(メンテナが日本語なしと明言、
>   [issue #1250](https://github.com/k2-fsa/sherpa-onnx/issues/1250))、openWakeWordは英語専用。現実解は
>   (a) VAD+ASRテキストマッチ(誤聴パターン「コロスケ/殺す気」も辞書に含める) → 即実装可
>   (b) icefallレシピで日本語KWS自作(中期)

| 候補 | 方式 | 期待 | 懸念 |
|---|---|---|---|
| vosk small-ja (現行) | Kaldi系・ストリーミング | 動作実証済/軽量48MB | 精度低め。ノイズから「えーっと」を幻聴(実測) → VAD必須 |
| vosk 大型ja | 同上 | 精度向上、導入10分 | メモリ/CPU増、幻聴傾向は残る可能性 |
| sherpa-onnx + 日本語Zipformer(ReazonSpeech系) | ONNX・ストリーミング | 日本語コーパス由来で精度期待大、ARM実績あり、KWS(ウェイクワード)機能もある | A55でのRTF要実測 |
| whisper.cpp (tiny/base) | バッチ(非ストリーミング) | 認識品質は高い | A55では遅い可能性大。リアルタイム対話向きでない |
| **Kotoba-Whisper v2.0-faster** | バッチ | **【実測済2026-07-19】精度ほぼ完璧**(「私はコロスケです」表記差のみ) | **【実測】RTF 7.20**(5.6s音声に40.5s, int8/8スレッド)・ロード238s → **対話用途は不採用**。バッチ字幕起こし等なら可 |
| クラウドAPI | - | 最高精度 | オフライン不可・遅延・従量課金(LLMは既にクラウドなので一考の余地はある) |

## 2.5 実機比較(2026-07-19実測・RDK X5)

評価セット: SAPI Haruka合成の日本語5文(正解テキスト付き, `~/corosuke/eval/`)。ハーネス: `scripts/eval_stt.py`(CER+RTF自動計測、モデル追加可能な構造)。

| | vosk small-ja | kotoba-whisper-v2.0-faster(int8) |
|---|---|---|
| 平均CER | 14.1% | 12.3% |
| 自然文3本 | 全て0.0% | 全て0.0% |
| 「こんにちは、私はコロ助です」 | 18.2%(こんにちは→今日は) | 9.1%(コロ助→コロスケ) |
| 「ワガハイはコロ助ナリ」 | **52.4%「我輩は殺す気なり」** | 52.4%(該当節が脱落) |
| RTF(全体) | **1.79** | 7.03 |
| モデルロード | 2.9s | 12.7s(DL済キャッシュ時) |

**三つ巴・最終表(2026-07-19深夜 sherpa-onnx実測追加):**

| | vosk small-ja | kotoba-whisper(int8) | **sherpa-onnx zipformer-ja+VAD(int8)** |
|---|---|---|---|
| 平均CER(本評価セット) | 14.1% | 12.3% | 20.4% |
| **RTF** | 1.79 ❌ | 7.03 ❌ | **0.44 ✅** |
| ストリーミング | 逐次部分認識あり | なし | 疑似(VAD区間ごと) |
| ロード | 2.9s | 12.7s | 11.6s |

**CERの数字は要解釈。** sherpaの誤りの内訳は (a)表記差「明日→あした」「挨拶→あいさつ」(意味は完全一致、e05はCER 0.0%達成) (b)「コロ助」固有語(全モデル共通で失敗) (c)ファイル先頭の「こんにちは」脱落(VAD始端の課題) — であり、**LLM対話の入力品質としては実質ほぼ問題ない**。一方voskのCER優位は参照テキストと同じ漢字表記を出す語彙特性によるもので、速度は実時間割れ。文献値(JSUT: sherpa 6.45% vs Whisper-L 7.18%)からも**肉声ではsherpaが上回る公算が大きい**。

**結論:**
1. **sherpa-onnx + Silero VAD構成を採用**(RTF 0.44で唯一実時間内、精度は表記差を除けば最良水準)。VADパラメータ(threshold 0.25 / min_silence 0.5 / 前後0.3sパディング)は`eval_stt.py`の`run_sherpa_vad`に実装済み — 残課題は**発話始端の取りこぼし**のみ
2. kotoba: 4倍遅で不採用確定。vosk: 逐次字幕用途(Web監視モニタ)に残す
3. 「コロ助」は**3モデル全てが「殺す気/殺す系/コロスケ」と誤聴**(評価音源のTTS発音要因も含む) → ウェイク判定は誤聴辞書込みのテキストマッチが必須、中期はKWS自作
4. 注意: 単一TTS音声の小規模セット。肉声・雑音条件は次フェーズで実測

## 3. 推奨構成(確定版 2026-07-19)

```
マイク → Silero VAD(発話区間検出+幻聴対策) → sherpa-onnx Zipformer-ja int8(区間デコード)
        → テキストマッチでウェイク判定(「コロ助」+誤聴辞書「コロスケ/殺す気」等) → LLM対話へ
```

1. **採用**: sherpa-onnx + `zipformer-ja-reazonspeech-2024-08-01` int8 — **実機RTF計測で最終判定**(目安RTF<0.5)
2. **ウェイク**: 当面はASRテキストマッチ(実測で得た誤聴パターンを辞書化)。中期でicefall日本語KWS自作を検討
3. **vosk**: 逐次字幕が欲しい用途(Web監視モニタ)では併用可。対話本線からは引退方向
4. **BPU**: 日本語ASRのBPU変換の検証済み事例なし。hobot_audio(中国語専用)はDOA(振り向き)+マイクアレイHATのAEC用途に限定価値
5. **不採用確定**: Whisper系全般(A55で実時間不可、kotoba実測RTF 7.03)・クラウドSTT(現方針では保留)

---
*深掘り調査(モデル別CER/RTF実測値・BPU変換事例・ウェイクワード比較)の結果は完了次第この下に追記。*
