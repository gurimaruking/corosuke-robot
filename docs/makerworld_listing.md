# MakerWorld アップロード記入シート — RDK X5 Modular Case

MakerWorld(https://makerworld.com)の「Upload」フォームに、下記をそのままコピペすればOK。

---

## アップロードするファイル

**3Dモデル(4ファイル、MakerWorldは3MF推奨):**
```
C:\Users\robostadion\OneDrive\claudecode\robot\rdk-x5-modular-case\stl\case_base.3mf
C:\Users\robostadion\OneDrive\claudecode\robot\rdk-x5-modular-case\stl\lid_default.3mf
C:\Users\robostadion\OneDrive\claudecode\robot\rdk-x5-modular-case\stl\lid_open.3mf
C:\Users\robostadion\OneDrive\claudecode\robot\rdk-x5-modular-case\stl\lid_vesa.3mf
```
(STL版も同フォルダにあり。3MFで問題なければそちらを推奨)

**カバー画像(1枚目=サムネイル):**
```
C:\Users\robostadion\OneDrive\claudecode\robot\rdk-x5-modular-case\images\assembly_preview.png
```
**追加画像(5枚):**
```
images\board_fit_verification.png  ← ★実物基板との整合検証(これが信頼の証)
images\case_base.png / lid_default.png / lid_open.png / lid_vesa.png
```

---

## フォーム記入欄

### Design Name(タイトル)
```
RDK X5 Modular Case — Closed / Open / VESA mount (Parametric, CC BY 4.0)
```

### Category(カテゴリ)
`Gadgets` → `Computer` （無ければ `Electronics` / `Tools`）

### Tags(タグ、最大10程度)
```
RDK X5, D-Robotics, ROS2, robotics, SBC, case, enclosure, edge-AI, OpenSCAD, single-board-computer
```

### License(ライセンス)
**Creative Commons - Attribution (CC BY 4.0)**

### Model Origin / Source(モデルの出自)
**Original design**（オリジナル設計）
※基板外形は D-Robotics 公式DXFから採寸したが、ケース設計自体はオリジナル。

### Description(説明文 — マークダウン可、そのままコピペ)
```
The first open-source 3D-printable case for the D-Robotics RDK X5 8GB Dev Kit
(Sunrise X5 SoC, 10 TOPS BPU).

WHY THIS EXISTS
As of mid-2026, RDK X5 had no community 3D-printable case anywhere — not on
MakerWorld, Printables, or Thingiverse. This fills that gap with a modular,
fully parametric OpenSCAD design.

ONE BASE, FOUR LIDS
🔵 Default — closed lid with cooling slits (everyday use)
🟢 Open — honeycomb vent field (heatsink fully exposed, max airflow)
🟡 VESA Mount — 50×50 M4 4-hole bracket pattern (board is too small for full VESA-75)
🟣 Fan — 40 mm fan mount (32 mm M3 pattern) with honeycomb intake grille + finger guard

FAN LID — RECOMMENDED HARDWARE (tested)
• Fan: 40 × 40 × 10 mm (4010), 5 V, 2-wire — the exact one I used
• Screws: 4 × M3 × 15 mm — a perfect fit through the fan into the lid bosses
• Power: 40-pin header, pin 4 = 5V, pin 6 = GND (runs full-speed when powered)
• Measured cooling (assembled, lid on): idle 66 C passive -> 41 C with fan (−25 C)

All lids snap onto a common base (press-fit lip + a full-perimeter snap ridge/groove).
The PCB is held by an outer clamp, so the stock heatsink mounting holes
stay fully accessible.

SPECS — every port cutout is data-accurate
• PCB outline from official D-Robotics V1P0 DXF (85 × 56 mm, C3 chamfered corners)
• Every connector position (USB-A ×2, RJ45, HDMI, audio, USB-C ×2, UART debug,
  40-pin GPIO, microSD, fan) extracted from the official STEP/DXF and VERIFIED by
  overlaying the real board mesh — see the board-fit verification image.
• Case footprint: ~89 × 60 × 30 mm
• Chamfered top edges, support-free, PLA / PETG, 2.2 mm walls

PRINT SETTINGS
• Layer height: 0.20 mm
• Walls / perimeters: 3
• Infill: 20% gyroid
• Supports: none

FILES
• case_base — print once
• lid_default / lid_open / lid_vesa / lid_fan — pick the lid(s) you want
All lids fit the same base.

SOURCE & REMIX
Full parametric OpenSCAD source on GitHub:
https://github.com/gurimaruking/rdk-x5-modular-case

LICENSE
CC BY 4.0 — share / remix / commercial use OK with credit.

DISCLAIMER
Unofficial community design, not affiliated with D-Robotics. PCB geometry
derived from D-Robotics' publicly released mechanical drawings.

Made as a community contribution from Project Korosuke (コロ助) — my entry
in the D-Robotics Robotics Dream Keeper Challenge.

#RDKX5 #DRobotics #ROS2 #edgeAI #robotics
```

### Designer Notes / 補足(任意)
```
Designed in OpenSCAD — every dimension is a parameter, so you can tweak
fit gap, wall thickness, top clearance, and VESA pattern in the source.
Camera-cutout and DIN-rail lids are on the roadmap; PRs welcome on GitHub.
```

---

## 印刷プロファイル(任意だが強く推奨)

MakerWorldは **Bambu Studioでスライスした印刷プロファイル付き**だと「Print Profile」バッジが付き、表示順位・ポイントで有利(Top Creator狙いに効く)。
余裕があれば:
1. Bambu Studioで各3MFを開く
2. PLA/PETG, 0.2mm, 3 walls, 20% infill, サポート無し でスライス
3. プロファイルを保存してMakerWorldにアップロード時に添付

なくてもモデル単体でアップロード可能。

---

## アップロード後にやること
- [ ] 公開URLを控える
- [ ] GitHub README / Discord告知文にMakerWorldリンクを追記
- [ ] Printables / Thingiverse にも同内容で展開(Task #13)
