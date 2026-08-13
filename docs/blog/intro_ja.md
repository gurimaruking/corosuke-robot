# ワガハイはコロ助ナリ！ — RDK X5でアニメの友を蘇らせる話

> D-Robotics「Robotics Dream Keeper Challenge」参加記(日本語)。
> 英語版のプロジェクト概要は [KazukiMurata-Project-Korosuke.md](../KazukiMurata-Project-Korosuke.md)、技術詳細は [STAGE3.md](../../STAGE3.md) を参照ナリ。

## 概要

コロ助は、日本の漫画家・**藤子・F・不二雄**が描く『**キテレツ大百科**』で、発明好きの主人公キテレツが第1話で作る**からくりロボット**です。本プロジェクトのコロ助ロボは、秋葉原のロボットコワーキングスペース「**ロボスタディオン**」のメンバーによる**ファンメイドロボット**——頭脳に **D-Robotics RDK X5** を載せ、**見る・聞く・考える・話す・表情する**をすべて**ボード上だけ**(クラウドなし)で行います。

<img src="../photo/20260725_korosuke-robot-revision_0.1.jpg" width="33%" alt="コロ助 rev0.1 — 組み上がって笑顔">

- リポジトリ: https://github.com/gurimaruking/corosuke-robot
- デモ動画: https://www.youtube.com/watch?v=NJwj6Iazd20

## 背景

### 店長(村田さん)の背景

東京・秋葉原でアニマトロニクス工房 **Robostadion**([robostadion.com](https://robostadion.com/))を営む村田和樹さん。アニマトロニクスや展示ロボットの製作を生業とし、ESP32/Arduino・Raspberry Pi・Python・OpenSCAD・3Dプリンタの艦隊(!)を日常使いするメイカーです。子どもの頃にロボットを作りたいと思わせてくれたキャラクター——コロ助を、いつかオープンソースのアニマトロニクスとして蘇らせるのが夢でした。

**デザインの元ネタ(inspiration)** — コロ助の設計は次のオープン/アニマトロニクス作品からアイデアを借りています:

- [Disney's Olaf robot](https://thewaltdisneycompany.com/olaf-robotic-character/) — 表情豊かなアニマトロニクスの目と顔
- [Open Duck Mini (BDX)](https://github.com/apirrone/Open_Duck_Mini) — コンパクトな二足歩行ドロイド

### 私(uecken)の背景 — 店長が「コロ助を作らないか！」と声をかけてくれた

私の専門は無線(ワイヤレス)エンジニアリングで、いつか環境に溶け込む「Ambient Robot」を作るのが夢です。ロボット製作は今回が初めて。

店長やスタッフのみなさんが **REK**(秋葉原で開催されるロボットバトル)の準備で大忙しの時期、私も RDK-Challenge に出ようとしていたのですが、仕事の関係で構想だけ描いて手を動かせずにいました。

- REK 概要: https://robostadion.com/rek-tokyo/
- REK 結果: https://robostadion.com/rek-tokyo/report.html

ふとロボスタディオンの Discord を見て、そういえば以前、店長が「コロ助を作らないか！」と声をかけてくれたことを思い出し——**「コロ助を作ろう！」と思い立って近所の秋葉原のロボスタディオンへ**。コロ助の部品を分けてもらい、作らせてもらいました！

<p>
<img src="../photo/korosuke_murataa_at_robostadion.jpg" width="49%" alt="ロボスタディオンにて: 村田さんとコロ助">
<img src="../photo/korosuke_uecken_at_robostadion.jpg" width="49%" alt="ロボスタディオンにて: ueckenとコロ助">
</p>

## 構成

### ソフトウェア構成

全処理オンデバイス(ネット接続なし)。会話の流れは4ステップです:

1. **発話の切り出し** — マイクの音から「人がしゃべっている区間」だけを検出します(この技術をVAD=Voice Activity Detectionと呼びます。テレビの音や無音に反応しないための門番役)
2. **音声認識** — 切り出した声を文字にします(SenseVoice、日本語/英語対応)
3. **返事を考える** — ボードの中の小さなAI(ローカルLLM: TinySwallow-1.5B)が返事の文章を作ります
4. **音声合成** — 文章をコロ助の声に変えてスピーカから話します(Open JTalk)

並行して、RDK X5の**AI専用チップ**(BPU)がカメラ映像から人を見つけ、目線が人を追いかけます。返事を考えるのに5〜10秒かかるので、その間は目が「考え中」のアニメになります。

```mermaid
flowchart LR
  CAM["C270 (カメラ&マイク)"] -->|USB| RDK
  subgraph RDK["RDK X5 — 全処理オンデバイス"]
    direction LR
    VAD["① 発話の切り出し (VAD)"] --> STT["② 音声認識 SenseVoice (日/英)"] --> LLM["③ 返事を考える ローカルLLM TinySwallow-1.5B"] --> TTS["④ 音声合成 Open JTalk"]
    YOLO["人物検出 YOLO11n-pose (AIチップBPU, 約19.5FPS)"]
  end
  RDK -->|"USBシリアル"| S3["ESP32-S3"]
  S3 --> EYES["目 GC9A01×2 (8表情)"]
  S3 --> ARMS["腕 SG90×2 (ロープ牽引)"]
  TTS --> AMP["アンプ MAX98357A"] --> SPK["φ50スピーカ"]
```

### ハードウェア構成

![ハードウェア配線図 — How it all wires together](../slides/img/korosuke_03.jpg)

※図中の **C270 はカメラ&マイク兼用**です(内蔵マイクが音声認識の入力)。詳細な結線・ピン表は [docs/wiring.md](../wiring.md) と [docs/hardware_block_diagram.md](../hardware_block_diagram.md) にあります。

## 過程

### 筐体部品をロボスタディオンの3Dプリンタで印刷

3Dパーツは **店長・村田さんが Claude (Fable 5) を使って設計・製作**！

<p>
<img src="../photo/korosuke_3Dprint_parts.jpg" width="32%" alt="印刷されたコロ助のパーツたち">
<img src="../photo/korosuke_3D_printed.jpg" width="32%" alt="印刷直後のパーツ">
<img src="../photo/korosuke_3Dparts_bulding.jpg" width="32%" alt="パーツの組み立て">
</p>

各部品はこんな構成です:

- **頭**: 半球ふたつ。片方に**目の穴**を開けて、丸型LCDの目を内側から差し込む
- **胴体**: RDK X5・カメラ・スピーカ・サーボモータが収まる円筒。**上下に開口**して部品を出し入れでき、**横には腕を動かすロープアームを通す穴**
- **腕と手**: 輪っかを8個連結して紐を通し、紐の片側を手の先端に、もう一方をサーボモータに接続(＝**ロープアーム**。サーボが紐を引くと腕が持ち上がる)
- **胴体ベース**: 当初ケーブルの出口がなかったので、**超音波カッターで底面をカット**して胴体下から配線を出すように加工
- **足**: 今回は動かさないので、そのまま胴体ベースに接着

<p>
<img src="../photo/Base_UltraCutter_Cutting.jpg" width="49%" alt="超音波カッターでベースをカット(1)">
<img src="../photo/Base_UltraCutter_Cutting_2.jpg" width="49%" alt="超音波カッターでベースをカット(2)">
</p>

### 電子部品の配線

リポジトリの配線資料どおりに接続しました:

- [docs/wiring.md](../wiring.md) — 電源2系統(モバイルバッテリー=RDK / LiPo=サーボ)と**共通GND**の全体図
- [docs/hardware_block_diagram.md](../hardware_block_diagram.md) — ESP32-S3⇔目(GC9A01×2)のピン表・実機検証済みの結線
- [firmware/max98357a](../../firmware/max98357a/) — スピーカ用I2Sアンプ(40ピン直結・カーネルドライバ自作)

### ソフトの製作

**AIに作ってもらいましょう**(今回は Visual Studio Code + Claude Code(Opus 4.8)を利用しています)。RDK Studio はあまり使いこなせていません、ごめんなさい！同じようなことがきっとできると思うので、今度もう一度使ってみます！

## トラブルシューティング(ハマったところ)

**① Type-C電源を挿したのに、HDMI出力もPCとのType-C IP通信もできない**
→ 基板のType-Cコネクタ横の**緑LEDが点いているか**確認しましょう。Type-Cケーブル/アダプタの相性のためか、給電しているつもりでも起動していない(=緑LEDが点かない)ことが何度かありました…。

**② IP通信ができない(Type-C / Ethernet)**
→ ネットワーク設定は[公式手順](https://developer.d-robotics.cc/rdk_studio_doc/en/user-guide/network-config/)で行います。ただ、RDK Studio からうまく設定できていなかったり、**設定が元に戻っていたりする**ことがあります。再度手順を実行するか、HDMIでターミナルを開いて `ip addr` でボード側のIPを確認、Windows側は `ipconfig` で使いたいインターフェースにIPが割り振られているか確認しましょう。

> 参考: このプロジェクトでは保守用に **eth0を固定IP 192.168.0.200**、**USB-C直結(usb0)は192.168.128.10** で運用しています([docs/network_setup.md](../network_setup.md))。

## あとがき — ロボットを作りやすい時代

ロボットは「機構・電子・ソフト」と、ちょっとした工作環境(少しのはんだ付け、必要に応じて超音波カッター等)があれば作れる時代になってきました。

今回の製作時間はだいたい **3Dパーツ15時間＋電子・ソフト10時間＝計25時間**。筐体と電子部品が揃っていれば既存ロボットの再現はもっと速いはずです。もう少し小型のロボットで良ければ——筐体サイズを半分にして高速プリント(外観はAI設計で3時間程度)、電子とソフトもAI(Claude Code等)に任せれば、**きっと5時間くらい、1日でカスタムロボットが作れる…はず！**

ワガハイはコロ助ナリ！一緒に夢を作るナリ！

---
*#RoboticsDreamKeeper #RDKX5 #ROS2 #animatronics*
