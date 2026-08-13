# ワガハイはコロ助ナリ！ — RDK X5でアニメの友を蘇らせる話

> D-Robotics「Robotics Dream Keeper Challenge」参加者の自己紹介(日本語版)。
> 英語版のプロジェクト概要は [KazukiMurata-Project-Korosuke.md](../KazukiMurata-Project-Korosuke.md) を参照。

## 自己紹介

はじめまして、uecken です。専門は無線(ワイヤレス)エンジニアリングで、いつか環境に溶け込む「Ambient Robot」を作るのが夢です。

ロボットの製作は今回が初めてです。東京のアニマトロニクス工房**ロボスタディオン**([robostadion.com](https://robostadion.com/))の村田さんに誘われて、このチャレンジに参加しました。

<!-- TODO(uecken): 「店長がREKで…」の続きをここに。参加の経緯・村田さんとの関係・普段の仕事など -->

## コロ助プロジェクトの現在地(Stage 3)

コロ助(『キテレツ大百科』のサムライロボット)を、RDK X5を頭脳にした約50cmのアニマトロニクスとして製作しています。**ネット接続なし・全処理オンデバイス**が信条です。

- **会話が完全オンデバイス**: SenseVoice(音声認識) → TinySwallow-1.5B(ローカルLLM、応答5〜10秒) → Open JTalk(音声合成)。語尾はもちろん「〜ナリ！」
- **BPUで視覚**: YOLO11n-pose 約19.5FPS。人を見つけると丸い目(GC9A01×2)が追いかけ、8種類の表情を切り替え
- **小さな体に全部入り**: SG90ロープ牽引の腕、MAX98357A+φ50スピーカ(カーネルドライバを自作してRDKの40ピンI2S直結)、RDK X5とバッテリーを3Dプリント胴体に収納
- **安全電源ボタン**: おやすみ音声と✕✕目で合図してからシャットダウン

- リポジトリ: https://github.com/gurimaruking/corosuke-robot
- デモ動画: https://www.youtube.com/watch?v=NJwj6Iazd20

<!-- 写真: ../photo/ から選んで貼る。例:
![コロ助 rev0.1](../photo/Korosuke_Eye.jpg)
-->

## これから作るもの

- **走行ベース**: 差動2輪(秋月部品だけで完結: FS90R+専用タイヤ+ボールキャスタ)。サーボ+タイヤを机上で完組みして上から差し込む「ドライブポッド」方式
- **胴体タッチディスプレイ**: ESP32-S3の4.3インチ液晶にRDKのカメラ映像をUSBで表示
- **ミニコロ助**: ESP32-S3単体で動く完全オフラインの弟分

ワガハイはコロ助ナリ！一緒に夢を作るナリ！

---
*#RoboticsDreamKeeper #RDKX5 #ROS2 #animatronics*
