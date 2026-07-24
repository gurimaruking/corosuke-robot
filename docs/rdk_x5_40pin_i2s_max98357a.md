# RDK X5 40ピン I2S 配線 & MAX98357A 接続

コロ助のスピーカーを小型化するため、I2Sデジタルアンプ **MAX98357A** を
RDK X5 の 40ピンに直結する。既存のオンボード ES8326（内部 i2s0）はそのまま残し、
MAX98357A は **40ピンに出ている I2S1（`dw_i2s1`）** に繋いで独立した再生カードにする。

## 出典（公式ピンアサイン）
- D-Robotics 公式: [RDK X5 40pin define](https://developer.d-robotics.cc/rdk_doc/en/Basic_Application/01_40pin_user_sample/40pin_define)
- 実機の `/usr/local/lib/python3.10/dist-packages/Hobot/GPIO/gpio_pin_data.py` とも突き合わせ済み（一致）。

## 40ピン I2S1 割り当て（Board Pin = 物理ピン番号）

| Board Pin | 信号 (CVM Func) | X5 Pin Index | 用途 | MAX98357A |
|---|---|---|---|---|
| **2**（or 4） | VDD_5V | — | 電源 | **VIN** |
| **6**（or 9/14/20/25/30/34/39） | GND | — | GND | **GND** |
| **7** | I2S1_MCLK | 420 | マスタクロック | 不要（内部PLL） |
| **12** | I2S1_BCLK | 421 | ビットクロック | **BCLK** |
| **35** | I2S1_LRCK (I2S1 WS) | 422 | LR/ワードセレクト | **LRC** |
| **38** | I2S1_SDIN (DI) | 423 | データ入力（→ボード, マイク用） | 不要 |
| **40** | I2S1_SDOUT (DO) | 424 | データ出力（ボード→アンプ） | **DIN** |

> 40ピンは Raspberry Pi 互換の 2×20。**左列=奇数(1,3,…39)／右列=偶数(2,4,…40)**、
> ピン1が基板内側の角。**必須は 5V / GND / DIN / BCLK / LRC の5本のみ**（MCLK・SDINは未使用）。

```
 (1) 3V3        5V   (2)   ← VIN
 (5) ...        GND  (6)   ← GND
(11) ...   I2S1_BCLK (12)  ← BCLK
(35) I2S1_LRCK ...   (36)  ← LRC
(39) GND   I2S1_SDOUT(40)  ← DIN（右下の角）
```

## MAX98357A の GAIN / SD 端子
- **GAIN**: 未接続=9dB（既定）。GNDに落とすと12dB。抵抗で3/6/15dBも可だが小型8Ωなら未接続でよい。
- **SD**（シャットダウン兼 L/R/mono 選択）: 未接続=アンプON・(L+R)/2 mono 相当。
  ソフトからミュート/省電力したい場合のみ空きGPIOへ（HIGH=再生, 0V=停止）。今回は未接続。

## スピーカー
- **採用: 秋月 WYGD50D-8-03**（8Ω・φ50mm・厚18.5mm・定格0.2W/max0.4W・F0 550Hz・防磁）
  = [g109012](https://akizukidenshi.com/catalog/g/g109012/)
- 経緯: 当初 MSI28-12R（φ28・g112587）を採用したが、**音量最大で歪む**（φ28は口径が小さく
  過振幅で割れる）。実機切り分けで**律速はアンプでなくスピーカー**と判明。**φ50に交換したら
  「全然質が良くなった」**（大口径＝同音圧でコーン振幅が小さく歪み激減）。
- **注意: WYGD50Dは0.2W(max0.4W)と耐入力が低い**。MAX98357Aは8Ω/5Vで最大~1.8W出せるため、
  過大入力で破損しないよう **DSPの `peak_ceil_db` を -9dBFS(≈0.2W) に制限**して運用。
  もっと大音量が要るなら高耐入力の φ40〜50 フルレンジ(例: DXYD40-22P-4A 4Ω3W [g116025])へ。
- 接続: MAX98357A の SPK+ / SPK− に接続（無極性で可）。

## ソフト側（i2s1 再生カードの作成）
RDK カーネルには MAX98357A 専用ドライバも in-tree ダミーコーデック（spdif-dit）も無いが、
`hobot-kernel-headers` が導入済みで **out-of-tree ビルド可能**。

1. `snd-soc-max98357a`（`sound/soc/codecs/max98357a.c`, v6.1.83）を out-of-tree ビルド
   （初回のみ `sudo make -C /usr/src/linux-headers-6 modules_prepare` で `fixdep` 等を生成）。
2. DTオーバーレイ `max98357a.dtbo`（`simple-audio-card` で `dw_i2s1`(master) ↔ `maxim,max98357a`、
   `format="i2s"`, `mclk-fs=64`）を `dtc` でコンパイルし `/boot/overlays/` へ配置。
3. `/boot/config.txt` に `dtoverlay=max98357a` を追記（末尾に空行必須）して再起動。
4. `aplay -l` に card "max98357a" が出現 → `aplay -D plughw:max98357a ...` で再生確認。
5. `korosuke_monitor.py` の TTS 出力（Open JTalk → aplay）をこのカードに向ける。

ビルド成果物とオーバーレイソースは `firmware/max98357a/`（本リポジトリ）に保管。

## 音質/音量チューニング（小型SP最適化 DSP）
小型SPは「クリーンに鳴らせるピーク上限」が低く、超えるとコーン底打ちで割れる。
**実測（φ28 MSI28-12R 裸・未固定）: クリーン天井 ≈ −6dBFS**（−6までクリーン、−3から歪む）。
Open JTalk 原音のピークは約 −4.7dBFS で天井を超えるため、特に**発話冒頭が割れる**。

### 出力電力の実際（8Ω・5V・GAIN 9dB）
- **−6dBFS 天井運用時: ピーク ≈ 0.4W / 声の平均 ≈ 0.03–0.05W**
- アンプ上限(8Ω): 約 1.6W（クリップ）/ 1.8W(10%THD)、4Ωなら約 3.2W
- → **律速はアンプでなくスピーカー**（φ28 は約0.4Wで機械的に歪む）。大音量化は
  「SPをバッフル/箱に固定」＋「大口径・高耐入力SPへ交換」が本筋。

### DSP（`korosuke_monitor.py _playback()`、MAX98357A 時のみ）
1. **HPF**（既定250Hz, `hpf`）… 出せない低域を除去しコーン保護
2. **コンプレッサ+速リミッタ**（ffmpeg）… 突発ピーク（冒頭割れ）を均す
3. **ピーク正規化**（audioop）… ピークを `peak_ceil_db`(既定−6dBFS)×音量に固定
   → クリップせず体感音量を最大化。実測で RMS +1〜2dB、冒頭割れ解消。

Web: 「🎛 小型SP最適化」ON/OFF・「クリーン上限」スライダー(`peak_ceil_db`)。
**SPを固定/交換して天井が上がったら `peak_ceil_db` を上げる**と更に大音量化できる。
GAIN 端子のハードゲイン(未接続=9dB / GND=12dB)とは別系統で併用可。
