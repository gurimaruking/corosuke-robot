/*
 * コロ助 印刷用マスター / Korosuke PRINT-READY master  v1.0
 *
 * 目的: 観賞用モデル(exterior/corosuke_exterior.scad, VCD準拠)を
 *       「実際に刷って組んで、電子部品が収まる」外装に再設計する。
 *   - 色ごとにパーツ分割(単色機でもフィラメント交換で原作配色を再現)
 *   - GC9A01目ディスプレイ(モジュールφ37.5/表示φ32.4)を顔に統合
 *   - 胴体にRDK X5モジュラーケース(91.4x62.4x27.1)を縦置き搭載
 *   - 頭にESP32-S3目コプロセッサ、首にケーブル経路
 *   - 全パーツ3mm壁の中空シェル+位置決めジョイント
 *
 * 準拠: Medicom VCD Special No.19 観察 + deep-research検証済みプロファイル
 *   (身長500mm/幅300mm、頭=ゴムまり球、胴=風呂桶→VCDでは羽織、
 *    腕=ジャバラホース縞、腰に刀)
 * 色はVCDパレット(橙頭/赤鼻/黒扇マゲ/紺赤縞腕/青脚)。PALETTE="anime"で黄系。
 *
 * Author: Kazuki Murata / Robostadion   License: CC BY 4.0 (design)
 * Character (C) Fujiko F. Fujio / fan-made, non-commercial tribute.
 *
 * ============ SHOW 一覧(印刷向き=平置き) ============
 *   0  全身プレビュー(色付き, 観賞用)
 *  【橙 ORANGE】 11 head_front  12 head_back  13 hand(x2印刷)  14 collar
 *  【橙 ORANGE】 15 jacket_shell  16 back_panel
 *  【白 WHITE】  21 eye_bezel(x2印刷)
 *  【赤 RED】    31 nose  32 button(x4)  33 topknot_stalk  34 sheath
 *  【黒 BLACK】  41 topknot_fan  42 wheel  43 hilt
 *  【紺 NAVY】   51 arm_ring_A(x8-10)  52 leg(x2)  53 foot(x2)
 *  【赤 RED】    54 arm_ring_B(x8-10)  ← 腕はA/Bリング交互スタック
 * ======================================================
 */

// ============================== パレット ==============================
// Webリサーチ(2026-06-25)反映: アニメ本放送版は「頭=淡黄 / 胴=橙」の2トーン、
// 頬に赤丸2つ、まげは長ネギ形(黒)、目はライト内蔵設定(=ディスプレイ目の公式裏付け)。
// アニメ版の刀は背中(VCDは腰)— 本モデルは腰差し(SWORD_ON_BACK=trueで背負い)。
PALETTE = "vcd";
C_HEAD   = PALETTE=="vcd" ? "#ef7a1a" : "#f7dc6f";  // アニメ=淡黄の頭
C_BODY   = PALETTE=="vcd" ? "#ef7a1a" : "#ef8f1f";  // アニメ=橙の胴(2トーン)
C_RED    = PALETTE=="vcd" ? "#c1121f" : "#c0392b";
C_BLACK  = "#141414";
C_NAVY   = PALETTE=="vcd" ? "#1c4ea0" : "#2a5fad";
C_WHITE  = "#f5f5f0";
C_LEG    = PALETTE=="vcd" ? "#1c4ea0" : "#d49b2c";
SWORD_ON_BACK = false;

// ============================== 基本寸法 ==============================
// (VCD準拠比率。EYE_VIS=50 が「見た目の目」=GC9A01+白ベゼル)
WALL       = 3.0;      // シェル壁厚
TOTAL_H    = 500;
HEAD_D     = 175;      // 頭球径
HEAD_SQ    = 0.95;     // 縦つぶし
EYE_VIS    = 50;       // 見た目の目の直径(白ベゼル外径)
EYE_SPACING= 60;       // 目の中心間隔
EYE_UP     = 2;        // 目の上方オフセット
NOSE_D     = 34;       // 鼻球径(VCD比率で大きめの赤丸鼻)
JACKET_H   = 165; JACKET_TOP_D = 165; JACKET_BOT_D = 158;
ARM_LEN    = 130; ARM_OUT_D = 34; ARM_RINGS = 9;
HAND_D     = 48;
LEG_D      = 36;  LEG_LEN = 70; LEG_SPACING = 78;
FOOT_L     = 75;  FOOT_W = 58; FOOT_H = 24;

// ---- GC9A01 実測(M128-240240-RGB-7-V1.0) ----
LCD_MOD_D   = 37.6;    // モジュール円径(実測37.5+公差)
LCD_MOD_T   = 6.0;     // 基板+部品厚(ピンヘッダ除く)
LCD_VIEW_D  = 33.0;    // 表示窓(アクティブ32.4+縁)
LCD_TAB_W   = 24;      // 下部ピンヘッダ張出し幅
LCD_TAB_L   = 14;      // 同 張出し長

// ---- RDK X5 モジュラーケース実測 ----
CASE_W = 91.4; CASE_D = 62.4; CASE_H = 27.1;  // ケース外形
CASE_CLR = 1.0;                                 // ベイ遊び

// ---- ジョイント ----
PIN_D = 4; PIN_L = 8; PIN_CLR = 0.25;          // 位置決めピン
LIP_H = 6;                                      // 重ね合わせリップ

$fn = $preview ? 48 : 96;

// ============================== 汎用 ==============================
module shell_sphere(d, squash=1, wall=WALL){   // 中空つぶし球
  difference(){
    scale([1,1,squash]) sphere(d=d);
    scale([1,1,squash]) sphere(d=d-2*wall);
  }
}
module locpin(){ cylinder(d=PIN_D, h=PIN_L); }
module locpin_hole(){ translate([0,0,-0.1]) cylinder(d=PIN_D+PIN_CLR*2, h=PIN_L+0.4); }

// =============================================================================
// 頭部: 前後割り。前=顔(目ソケット+鼻穴+口)、後=スカル(基板トレイ)
// 分割面 y=0。合わせはリップ+ピン4本。
// =============================================================================
HEAD_R = HEAD_D/2;
EYE_Y  = -sqrt(max(0, HEAD_R*HEAD_R - (EYE_SPACING/2)*(EYE_SPACING/2) - EYE_UP*EYE_UP)); // 球面上

module eye_socket_cut(){
  // 顔面に開ける: 表示窓(貫通) + モジュールポケット(内側から挿入)
  rotate([90,0,0]){
    cylinder(d=LCD_VIEW_D, h=HEAD_R+10);                 // 窓(外へ貫通)
    translate([0,0,-40]) cylinder(d=LCD_MOD_D, h=40+ WALL+2 - 1.2); // ポケット(外皮1.2mm残し→窓段差でモジュール受け)
    translate([-LCD_TAB_W/2, -LCD_MOD_D/2-LCD_TAB_L+6, -40]) cube([LCD_TAB_W, LCD_TAB_L, 40]); // ピンヘッダ逃げ
  }
}
module head_front(){
  difference(){
    intersection(){ shell_sphere(HEAD_D, HEAD_SQ); translate([-200,-200,-200]) cube([400,200,400]); }
    // 目 x2
    for(s=[-1,1]) translate([s*EYE_SPACING/2, EYE_Y+2, EYE_UP]) eye_socket_cut();
    // 鼻: φ12取付穴(鼻パーツの首を差す)+カメラ用に貫通
    translate([0,-HEAD_R+WALL+2, -6]) rotate([90,0,0]) cylinder(d=12.5, h=WALL+8);
    // 口スリット(への字, アニメ感。不要なら埋める)
    translate([0,-HEAD_R+1.2, -34]) rotate([90,0,0])
      linear_extrude(WALL+4) offset(r=2) polygon([[-20,0],[0,-6],[20,0],[18,-3],[0,-9],[-18,-3]]);
    // ピン穴(分割面)
    for(s=[-1,1], z=[-40,40]) translate([s*55, -PIN_L+0.1, z]) rotate([-90,0,0]) locpin_hole();
  }
}
module head_back(){
  union(){
    difference(){
      intersection(){ shell_sphere(HEAD_D, HEAD_SQ); translate([-200,0,-200]) cube([400,200,400]); }
      // 首穴(ケーブル+固定)
      translate([0,20,-HEAD_R*HEAD_SQ-1]) cylinder(d=46, h=WALL+14);
      // マゲ取付穴(頭頂)
      translate([0,10,HEAD_R*HEAD_SQ-WALL-8]) cylinder(d=8.5, h=WALL+10);
    }
    // 合わせリップ(内側に一段)
    difference(){
      intersection(){ scale([1,1,HEAD_SQ]) sphere(d=HEAD_D-2*WALL+0.4); translate([-200,0,-200]) cube([400,LIP_H,400]); }
      intersection(){ scale([1,1,HEAD_SQ]) sphere(d=HEAD_D-2*WALL-3);   translate([-200,-1,-200]) cube([400,LIP_H+2,400]); }
    }
    // ピン(分割面から前へ)
    for(s=[-1,1], z=[-40,40]) translate([s*55, 0, z]) rotate([-90,0,0]) locpin();
    // ESP32-S3トレイ(内壁に棚)
    translate([-25, 30, -30]) cube([50, 3, 24]);
    translate([-25, 62, -30]) cube([50, 3, 24]);
  }
}
// 白ベゼル(外から嵌める化粧リング: 外φ50 → 窓φ33)
module eye_bezel(){
  difference(){
    union(){
      cylinder(d=EYE_VIS, h=3);                        // 化粧面
      translate([0,0,-2.5]) cylinder(d=LCD_VIEW_D-0.4, h=3); // 窓への差込首
    }
    translate([0,0,-3]) cylinder(d=LCD_VIEW_D-4, h=8); // 表示開口
  }
}
// 赤鼻(首付き球。NOSE_CAM=trueでカメラ穴φ7.5)
NOSE_CAM = true;
module nose(){
  difference(){
    union(){ sphere(d=NOSE_D); translate([0,0,-2]) cylinder(d=12, h=NOSE_D/2+4); }
    if(NOSE_CAM) cylinder(d=7.5, h=NOSE_D, center=true);
  }
}
// マゲ: 黒扇(5枚刃, 一体) + 赤軸
module topknot_fan(){
  for(i=[0:4]) rotate([0, -36+18*i, 0]) translate([0,0,12])
    hull(){ cylinder(d=4,h=1); translate([0,0,24]) scale([1,0.35,1]) cylinder(d=13,h=2); }
}
module topknot_stalk(){ cylinder(d=8, h=26); translate([0,0,26]) sphere(d=10); }
// 頬の赤丸(球面キャップ, 貼り付け) — アニメ版の必須ディテール
module cheek(){ intersection(){ translate([0,0,-11]) sphere(d=32); cylinder(d=24, h=5); } }

// =============================================================================
// 胴体(羽織): 円錐台シェル。内部にRDK X5ケース縦置きベイ。
// 背面ハッチ(ポートアクセス)、前面下部スピーカーグリル、裾から組込み。
// =============================================================================
module jacket_shell(){
  difference(){
    union(){
      difference(){
        cylinder(h=JACKET_H, d1=JACKET_BOT_D, d2=JACKET_TOP_D);
        translate([0,0,-1]) cylinder(h=JACKET_H+2, d1=JACKET_BOT_D-2*WALL, d2=JACKET_TOP_D-2*WALL);
      }
      // 天板(首座)
      translate([0,0,JACKET_H-WALL]) difference(){
        cylinder(h=WALL, d=JACKET_TOP_D-1);
        translate([0,0,-1]) cylinder(h=WALL+2, d=46);   // 首穴
      }
      // ケースベイ: 縦置きレール2本(ケース62.4x27.1断面を保持)
      for(s=[-1,1]) translate([s*(CASE_D/2+CASE_CLR+WALL/2)-WALL/2, -CASE_H/2-CASE_CLR-WALL, WALL])
        cube([WALL, CASE_H+2*CASE_CLR+2*WALL, 96]);
      translate([-CASE_D/2-CASE_CLR-WALL, -CASE_H/2-CASE_CLR-WALL, WALL])
        cube([CASE_D+2*CASE_CLR+2*WALL, WALL, 96]);      // 背側ストッパ
    }
    // 背面ハッチ開口(70x100) — ケーブル/SD/ポートアクセス
    translate([-35, JACKET_BOT_D/2-14, 22]) cube([70, 20, 100]);
    // 前面下部スピーカーグリル(φ4 x 19穴)
    for(i=[-2:2], j=[0:2]) translate([i*9, -JACKET_BOT_D/2+((abs(i)+j)%9)-2, 26+j*9])
      rotate([90,0,0]) cylinder(d=4, h=16);
    // ボタン穴 x4(前面中央縦)
    for(k=[0:3]) translate([0, -JACKET_BOT_D/2+2, JACKET_H-30-k*34]) rotate([90,0,0]) cylinder(d=6.5, h=WALL+6);
    // 腕穴 x2(肩)
    for(s=[-1,1]) translate([s*(JACKET_TOP_D/2-2), 0, JACKET_H-38]) rotate([0,90,0]) cylinder(d=ARM_OUT_D+2, h=20, center=true);
  }
}
module back_panel(){  // ハッチ蓋(はめ込み)
  difference(){
    union(){ cube([69,3,99]); translate([2,-2,2]) cube([65,2,95]); }
    for(i=[0:5]) translate([8+i*10, -3, 8]) cube([4, 8, 82]);   // 通気スリット
  }
}
module collar(){ difference(){ cylinder(d=88,h=10); translate([0,0,-1]) cylinder(d=70,h=12); } }
module button(){ sphere(d=11); translate([0,0,-5]) cylinder(d=6, h=7); }

// =============================================================================
// 腕: ジャバラ=A/B色リングの交互スタック(中心φ12通し穴: ロープ/配線)
// 奇数リング(A=紺) 偶数(B=赤)。両端は手/肩に差し込み。
// =============================================================================
module arm_ring(isA=true){
  difference(){
    union(){
      // 樽形リング
      hull(){ cylinder(d=ARM_OUT_D-6, h=1); translate([0,0,ARM_LEN/ARM_RINGS/2]) cylinder(d=ARM_OUT_D, h=1); translate([0,0,ARM_LEN/ARM_RINGS-1]) cylinder(d=ARM_OUT_D-6, h=1); }
      translate([0,0,ARM_LEN/ARM_RINGS-1]) cylinder(d=16, h=3);      // オス継手
    }
    translate([0,0,-1]) cylinder(d=12, h=ARM_LEN/ARM_RINGS+6);       // 通し穴
    translate([0,0,-0.1]) cylinder(d=16+PIN_CLR*2, h=3.2);           // メス継手
  }
}
module hand(){
  difference(){
    sphere(d=HAND_D);
    rotate([0,90,0]) translate([0,0,HAND_D/2-14]) cylinder(d=16.5, h=16);  // 手首ソケット
    sphere(d=HAND_D-2*WALL);   // 中空
  }
}

// =============================================================================
// 脚・足(紺/青)
// =============================================================================
module leg(){ difference(){ cylinder(d=LEG_D, h=LEG_LEN); translate([0,0,WALL]) cylinder(d=LEG_D-2*WALL, h=LEG_LEN); } }
module foot(){
  difference(){
    hull(){ translate([0,-FOOT_L*0.28,0]) scale([1,1.35,0.55]) sphere(d=FOOT_W); translate([0,FOOT_L*0.15,0]) scale([1,1,0.5]) sphere(d=FOOT_W*0.9); }
    translate([-100,-100,-100]) cube([200,200,100]);            // 底面カット
    translate([0,6,FOOT_H-6]) cylinder(d=LEG_D-2*WALL-1, h=10); // 脚差し込み
  }
}

// =============================================================================
// 刀(腰差し): 鞘=赤 / 柄・鍔・車輪=黒(白菱形は塗装 or シール推奨)
// =============================================================================
module sheath(){ rotate([0,90,0]) difference(){ cylinder(d=20, h=150); translate([0,0,-1]) cylinder(d=15, h=100); } }
module hilt(){ rotate([0,90,0]){ cylinder(d=17, h=46); translate([0,0,46]) cylinder(d=30, h=4); } }
module wheel(){ difference(){ cylinder(d=22, h=6, center=true); cylinder(d=5, h=8, center=true); } }

// =============================================================================
// 全身プレビュー
// =============================================================================
module assembly(){
  FOOT_Z=0; LEG_Z=FOOT_H*0.6; JACK_Z=LEG_Z+LEG_LEN; HEAD_Z=JACK_Z+JACKET_H+HEAD_R*HEAD_SQ-2;
  for(s=[-1,1]) translate([s*LEG_SPACING/2,0,FOOT_Z]) color(C_LEG) foot();
  for(s=[-1,1]) translate([s*LEG_SPACING/2,0,LEG_Z]) color(C_LEG) leg();
  translate([0,0,JACK_Z]){ color(C_BODY) jacket_shell(); color(C_BODY) translate([-34.5, JACKET_BOT_D/2-14, 22]) back_panel();
    for(k=[0:3]) color(C_RED) translate([0,-JACKET_BOT_D/2+0.5, JACKET_H-30-k*34]) rotate([90,0,0]) button();
    color(C_HEAD) translate([0,0,JACKET_H-2]) collar();
    // 刀
    // 腰差し(横差し): 鞘先端+車輪が前左に覗き、柄は胴の陰に隠れる
    translate([-105, -70, 40]) rotate([0,0,20]){ color(C_RED) sheath(); color(C_BLACK) translate([148,0,0]) hilt(); color(C_BLACK) translate([-2,0,0]) rotate([0,90,0]) wheel(); }
    // 腕
    for(s=[-1,1]) translate([s*(JACKET_TOP_D/2+2),0,JACKET_H-38]) rotate([0,s*90,0]){
      for(i=[0:ARM_RINGS-1]) color(i%2==0?C_NAVY:C_RED) translate([0,0,i*ARM_LEN/ARM_RINGS]) arm_ring(i%2==0);
      color(C_HEAD) translate([0,0,ARM_LEN+HAND_D/2-10]) hand();
    }
  }
  translate([0,0,HEAD_Z]){
    color(C_HEAD) head_front(); color(C_HEAD) head_back();
    for(s=[-1,1]) color(C_WHITE) translate([s*EYE_SPACING/2, EYE_Y-HEAD_R*0.02-3.4, EYE_UP]) rotate([90,0,0]) eye_bezel();
    color(C_RED) translate([0,-HEAD_R+6,-6]) rotate([-90,0,0]) nose();
    for(s=[-1,1]) color(C_RED) translate([s*54, -60, -34]) rotate([90,0,0]) cheek();  // 頬の赤丸
    color(C_RED) translate([0,10,HEAD_R*HEAD_SQ-6]) topknot_stalk();
    color(C_BLACK) translate([0,10,HEAD_R*HEAD_SQ+16]) topknot_fan();
  }
}

// =============================================================================
// RENDER SWITCH(印刷パーツは平置き向きで出す)
// =============================================================================
SHOW = 0;
if(SHOW==0) assembly();
// --- 橙 ---
else if(SHOW==11) rotate([90,0,0]) head_front();        // 顔を上に平置き
else if(SHOW==12) rotate([-90,0,0]) head_back();
else if(SHOW==13) hand();
else if(SHOW==14) collar();
else if(SHOW==15) jacket_shell();
else if(SHOW==16) rotate([90,0,0]) back_panel();
// --- 白 ---
else if(SHOW==21) translate([0,0,2.5]) eye_bezel();
// --- 赤 ---
else if(SHOW==31) nose();
else if(SHOW==32) button();
else if(SHOW==33) topknot_stalk();
else if(SHOW==35) cheek();
else if(SHOW==34) sheath();
else if(SHOW==54) arm_ring(false);
// --- 黒 ---
else if(SHOW==41) topknot_fan();
else if(SHOW==42) wheel();
else if(SHOW==43) hilt();
// --- 紺/青 ---
else if(SHOW==51) arm_ring(true);
else if(SHOW==52) leg();
else if(SHOW==53) foot();
