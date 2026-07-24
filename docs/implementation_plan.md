# コロ助 実装計画 / ロードマップ(引き継ぎ版)

> 引き継ぎ技師による現状整理 + 実装計画。2026-07-24更新。
> **凡例**: ✅実機動作確認済 / 🟡コード有・実機未テスト / 🔧設計のみ / 📋未着手
> 大方針(2026-07-24ユーザー確定): **対話は完全オンデバイス、クラウド禁止**。

## 全体像 — コロ助の認知ループ

```
         ┌─────────────── 見る ───────────────┐
カメラ→ vision_node(BPU YOLO11n) →/face_pose→ brain_node ─┬─/eye_cmd→ 目(追従+表情) ✅
                                                          └─/greet──┐
マイク→ STT(sherpa) ─────────────────/user_text──────────────────┴→ dialogue_node
                                                                       │(LLM=要ローカル化)
                                                    ┌──/say_text→ voice_node → VOICEVOX → SP
                                                    └──/eye_cmd→ 目(セリフに合う表情)
```
設計思想: 疎結合なROS2トピック連携。各ノードは相手が居なくても単独で立ち上がる(フォールバック内蔵)。

## サブシステム別ステータス

| 層 | 機能 | ノード/実体 | 状態 | 根拠 |
|---|---|---|---|---|
| 見る | 人物検出(BPU) | vision_node | 🟡 | YOLO単体は✅19.5FPS。ノートしての実機起動は未 |
| 見る | 目で追う+気づき挨拶 | brain_node | 🟡 | コード有([brain_node.py](../ros2_ws/src/korosuke_nodes/korosuke_nodes/brain_node.py))・実機未 |
| 表情 | 目(2×GC9A01) | corosuke_eyes(ESP32-S3) | ✅ | M2達成。8表情巡回確認済 |
| 聞く | 日本語STT | sherpa-onnx+VAD | ✅ | RTF0.44実測。[stt_research.md](stt_research.md) |
| 考える | 対話(人格「〜ナリ」) | dialogue_node | 🟡→🔧 | コード有だが**LLMがクラウドClaude**。ローカル化が必要 |
| 話す | TTS | voice_node(VOICEVOX) | 🟡 | コード有(ローカル)。VOICEVOX本体の導入は未確認 |
| 話す | スピーカー | ES8326→3.5mm | ✅ | 動作確認済 |

## マイルストーン計画

### M-A: 「人が来たら気づいて挨拶」ループ 🟡→次の目標
> **ユーザー要望(2026-07-24)で明文化。実は既に全コードが存在する。**

- 設計: vision_node が人を検出→ /face_pose → brain_node が「新規出現」をヒステリシス判定し **1回だけ** /greet を発行([brain_node.py:39-43](../ros2_ws/src/korosuke_nodes/korosuke_nodes/brain_node.py#L39-L43))。同時に目が人を追い(視線=顔位置反転)、happy表情になり、気づいた合図に1回まばたき。
- 挨拶文の既定は `'だれか来たナリ！'`([brain_node.py:21](../ros2_ws/src/korosuke_nodes/korosuke_nodes/brain_node.py#L21))。
- **今日テスト可能**: カメラ+目は両方✅。`vision_node`+`brain_node`+`serial_bridge`を起動すれば、LLM/音声抜きで「人を見る→目で追う→気づいてまばたき」まで確認できる。
- 手順(要実機確認):
  ```
  source /opt/ros/humble/setup.bash && source ~/corosuke/ros2_ws/install/setup.bash
  ros2 run korosuke_nodes serial_bridge &   # 目
  ros2 run korosuke_nodes vision &          # BPU人物検出(カメラ占有=モニタ停止要)
  ros2 run korosuke_nodes brain             # 追従+挨拶トリガ
  ```
- 注意: vision_nodeはカメラを占有するので、先に `pkill -f korosuke_monitor`。

### M-B: 声を出す(TTSローカル確認) 📋
- voice_nodeはVOICEVOX(localhost:50021)前提。**VOICEVOXがRDK X5(aarch64)で動くか未確認**。動かない場合の代替(sherpa-onnx TTS/piper日本語等)は要調査。
- スピーカー✅なので、TTSエンジンさえ決まれば「喋る」は完成。

### M-C: 対話をローカルLLM化 🔧【調査中】
- 現状 dialogue_node は **クラウドClaude**([dialogue_node.py:83-90](../ros2_ws/src/korosuke_nodes/korosuke_nodes/dialogue_node.py#L83-L90))。クラウド禁止方針により**ローカルLLMへ差し替え必須**。
- 受け皿: 実機に `hobot_llamacpp`(llama.cpp)導入済み。GGUFモデル未配置。
- **判断待ち**: どのモデル(0.5B/1.5B/3B)が日本語×A55速度で実用か → 専用調査Workflow走行中。
- 統合方針(案): dialogue_nodeのHTTP呼出先をローカルllama.cppに変更、「〜ナリ」system prompt([personality.py](../server/corosuke_personality.py))はそのまま流用。

### M-D: 音声対話フルループ 📋
- STT(✅sherpa) → dialogue(M-C) → TTS(M-B) → SP(✅) を接続。マイク発話→ /user_text 配線が要実装(sherpa出力をトピック化)。
- 完成で「話しかけると〜ナリで返す」。

### M-E: モーションキャプチャ/ジェスチャ(体を動かす) 📋【調査完了】
> 詳細: [mocap_capabilities.md](mocap_capabilities.md)。D-Robotics公式スタックが実機導入済み。
- 一次ソースは2つ: **mono2d_body_detection**(全身骨格・BPU・X5対応)/ **hand_lmk_detection**(手21点)。
- 有望アイデア(優先順):
  1. 骨格→腕サーボへ**動作模倣**(2D mocap)。肩肘手首の角度をマッピング。難易度中
  2. **手ジェスチャに反応**(hand_gesture_detection、8+3種)。難易度低
  3. **人追従**(body_tracking)で首/目を向ける。難易度低〜中
- 前提: コロ助に腕サーボ/可動機構が**まだ無い**(現行は静的)。まず表情+音声を固め、可動化は別フェーズ。

### M-F: 運用整備 📋
- Web監視モニタ(v2: YOLO検知+sherpa) の **systemdサービス化**(再起動で自動起動)。
- 各ノードの自動起動(launch/systemd)。

## 依存関係(何から着手すべきか)

```
M-A(見る→挨拶) ── 今日テスト可能。LLM不要の部分から検証を推奨
M-B(TTS) ─┐
M-C(LLM) ─┴→ M-D(音声対話フルループ)
M-E(mocap) ── 可動機構の追加が前提。当面は調査結果を寝かせる
M-F(運用) ── いつでも。モニタ常駐化は先に済ませると楽
```

## 未確定事項

- VOICEVOXがaarch64で動くか(M-B)
- ローカルLLMのモデル選定と応答速度(M-C、調査中)
- 腕/首の可動機構(M-E、現行ハードには無い)
- vision_nodeとモニタのカメラ排他(1台のカメラを取り合う。将来は映像を1プロセスで取得しトピック配信に一本化)
