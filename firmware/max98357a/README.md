# MAX98357A I2S アンプ (RDK X5 40ピン)

コロ助のスピーカー小型化用。I2Sデジタルアンプ **MAX98357A** を RDK X5 の
40ピン **I2S1 (`dw_i2s1`)** に接続し、独立した ALSA 再生カード `max98357a` を作る。
オンボード ES8326 (i2s0) はそのまま残る。配線・ピン定義は
[../../docs/rdk_x5_40pin_i2s_max98357a.md](../../docs/rdk_x5_40pin_i2s_max98357a.md)。

## なぜカスタムビルドが要るか
RDK カーネル(6.1.83)には MAX98357A 専用ドライバも in-tree ダミーコーデック
(spdif-dit)も無い（`CONFIG_SND_SOC_MAX98357A is not set`）。ただし
`hobot-kernel-headers` が導入済みなので、単一ファイルの codec ドライバを
out-of-tree ビルドできる。カードは汎用 `snd-soc-simple-card` で組む
（RDK 標準の音声は独自 `hobot-sound-machine` ドライバで、汎用 simple-card は
既定では未ロードなので明示ロードが要る）。

## 収録ファイル
- `max98357a.c` … Linux v6.1.83 の `sound/soc/codecs/max98357a.c`（無改変）
- `Makefile` … out-of-tree ビルド用
- `max98357a.dts` … DTオーバーレイ（`dw_i2s1`(master) ↔ `maxim,max98357a`、`format="i2s"`）

## ボードでの導入手順（再現）
```sh
# 0) 初回のみ: ヘッダツリーのホストツール(fixdep等)を生成
sudo make -C /usr/src/linux-headers-6 modules_prepare

# 1) codec ドライバをビルド＆インストール
cd max98357a && make
sudo cp max98357a.ko /lib/modules/6.1.83/kernel/sound/soc/codecs/
sudo depmod -a

# 2) オーバーレイをコンパイル＆設置（外部phandle解決のため -@ 必須）
dtc -@ -I dts -O dtb -o max98357a.dtbo max98357a.dts
sudo cp max98357a.dtbo /boot/overlays/

# 3) 起動時に有効化（config.txt は末尾に空行必須）
printf 'dtoverlay=max98357a\n\n' | sudo tee -a /boot/config.txt
# 4) 両モジュールを起動時に自動ロード
printf 'max98357a\nsnd-soc-simple-card\n' | sudo tee /etc/modules-load.d/max98357a.conf

sudo reboot
```

## 確認
```sh
aplay -l | grep max98357a         # card "max98357a" が出れば成功
# ※カード番号は起動毎に変わる。名前で指定: plughw:CARD=max98357a
speaker-test -D plughw:CARD=max98357a -c 2 -t sine -f 440 -l 1
```
対応フォーマット: `S16_LE/S24_LE/S32_LE`, **stereo(2ch固定)**, 8–96kHz。
モノラルWAVは `plughw`（plugプラグイン）でステレオ/レート自動変換される。

## コロ助モニタ連携
`scripts/korosuke_monitor.py` の Web「🔈 出力先」で `ES8326 ⇄ MAX98357A` を切替。
MAX98357A はハード音量が無いため、音量スライダーはソフトスケール(audioop)で効く。
GAIN 端子でハードゲイン(未接続=9dB / GND=12dB)も併用可。
