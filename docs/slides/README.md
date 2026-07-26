# Korosuke プレゼン & 動画の作り方

`korosuke_stage3.md` = **Marp** スライド、`narration.md` = ナレーション台本（日/英）。
GitHubでそのまま読めます。スライド表示・動画化は以下。

---

## 1. スライドを表示 / 書き出す（Marp）

**一番簡単**: VS Code に拡張 **「Marp for VS Code」** を入れて `korosuke_stage3.md` を開く → 右上のプレビュー。

**CLIで書き出し**（Node必要）:
```bash
npm i -g @marp-team/marp-cli
cd docs/slides
marp korosuke_stage3.md --html        # → korosuke_stage3.html（全画面プレゼン）
marp korosuke_stage3.md --pdf         # → PDF
marp korosuke_stage3.md --pptx        # → PowerPoint
marp korosuke_stage3.md --images png  # → スライドPNG（動画結合用）
```

---

## 2. あなたのナレーションを付けて動画化

### 方法A（最も簡単）: 画面録画しながら生ナレーション
1. `--html` で書き出したスライドをブラウザ全画面表示（Fキー）。
2. **OBS Studio**（無料）or Windowsの「Xbox Game Bar」(Win+G) で画面＋マイクを録画。
3. `narration.md` を読みながらスライドを送る。→ そのまま mp4 完成。
4. デモ実機の映像は、別撮りしてから編集で差し込む（下の構成参照）。

### 方法B: スライドPNG + 録音音声を ffmpeg で結合
スライドごとに音声を録音（`s01.mp3`, `s02.mp3`…）し、PNG（`korosuke_stage3.001.png`…）と結合:
```bash
# 例: 1枚を対応音声の長さで表示して連結（各スライド分作って concat）
for i in 001 002 003 ...; do
  ffmpeg -loop 1 -i korosuke_stage3.$i.png -i s$i.mp3 \
    -c:v libx264 -tune stillimage -c:a aac -b:a 192k -pix_fmt yuv420p -shortest slide_$i.mp4
done
printf "file '%s'\n" slide_*.mp4 > list.txt
ffmpeg -f concat -safe 0 -i list.txt -c copy korosuke_talk.mp4
```

---

## 3. 3〜7分デモ動画の構成（推奨・実機映像＋スライド）

| 区間 | 内容 | 尺 |
|---|---|---|
| 0:00 | タイトルスライド + 一言 | 10s |
| 0:10 | 実機: 電源ON→「おはよう」挨拶（自動起動） | 20s |
| 0:30 | 実機: 人を目で追う / カメラ+骨格（Web画面も） | 20s |
| 0:50 | 実機: **日本語**で会話（話しかけ→考え中の目→返答） | 40s |
| 1:30 | 実機: **英語に切替**→英語で会話（バイリンガルの山場） | 40s |
| 2:10 | 実機: ジェスチャ反応 / 頭なでなで / 腕を振る | 30s |
| 2:40 | スライド: アーキテクチャ（BPU/CPU分担・完全オンデバイス） | 30s |
| 3:10 | スライド: SenseVoice+TinySwallow（D-Robotics構成と一致） | 20s |
| 3:30 | 実機: 安全シャットダウン（おやすみ→✕✕→電源OK） | 20s |
| 3:50 | 正直なスコープ + まとめ + リンク | 20s |

※ Web ダッシュボード（`http://<board-ip>:8080`）の画面も収録すると、AI構成（LLM/STT/TTS）や言語切替が伝わりやすい。

---

## 4. 撮影のコツ
- 明るい場所・静かな環境（STTの誤認識を減らす）。三脚 or 固定。
- 会話は**近く・はっきり**。言語切替は画面の「🌐一括」ボタンを見せながら。
- 1080p / 横向き。YouTubeにアップして限定公開URLを提出物へ。
