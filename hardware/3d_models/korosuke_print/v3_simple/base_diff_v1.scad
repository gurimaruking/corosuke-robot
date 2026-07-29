/*
 * コロ助 差動2輪ドライブベース v1 (秋月完結部品) / 2026-07-29
 *
 * 部品(全て秋月):
 *   - FS90R 連続回転サーボ ×2 (g113206, ¥600)  … 左右輪
 *   - FS90R対応タイヤ FS90R-W φ60×8 ×2 (g113207, ¥220) … スプライン直結
 *   - タミヤ ボールキャスター 70144 ×2 (g110372, ¥330/2個) … 前後・高さ11〜35mm可変
 *
 * 設計:
 *   - 車輪はφ158スカートの内側(x=±65)に隠す=外から見えないコロコロ。
 *   - 車軸z=30(φ60タイヤ)。底板は地上高GC=11(キャスタ最低高と一致、スペーサで微調整)。
 *   - 中央にφ90ケーブル井戸(RDKのUSB束が胴からまっすぐ落ちる)=差動なので中央ガラ空き。
 *   - ベース内部(高さ~28mm)にLiPo/ESP32/ドライバを収容(LiPoはベース搭載の方針)。
 *   - 天面=胴(φ158裾)を載せるドック面+位置決めリム(bottom_v3と同形式)。
 *
 * SHOW: 0=プレビュー(ゴースト付) / 1=ベース単体(印刷用)
 */
$fn = 96;
JBOT_D = 158;  WALL = 3;
GC   = 11;              // 地上高(=タミヤ70144最低高。スペーサで合わせる)
BH   = 45;              // ベース全高(天面=胴が載る)
CABLE_D = 90;           // 中央ケーブル井戸(bottom_v3のφ90を踏襲)

// FS90R 実寸: 本体23.2(L)×12.5(W)×22.4(H)+ホーン。軸は端から5.8オフセット
SVL=23.2; SVW=12.5; SVH=22.4; SH_OFF=5.8;
WHEEL_D=60; WHEEL_W=8;  // FS90R-W
AXLE_Z = WHEEL_D/2;     // 車軸高さ=30
WX = 65;                // 車輪中心X(外面69 < 79=φ158内・スカートに隠れる)
FACE_X = WX - WHEEL_W/2 - 1;   // サーボ取付面X(タイヤ内面-1mm)

CAST_Y = 58;            // キャスタ位置(前後)

module base_plate(){
  difference(){
    translate([0,0,GC]) cylinder(d=JBOT_D, h=WALL);         // 底板(z11-14)
    // 車輪スリット(底板を貫通: 車輪+余裕)
    for(s=[-1,1]) translate([s*WX, 0, GC-1]) cube([WHEEL_W+8, WHEEL_D+10, WALL+2], center=true);
    translate([0,0,GC-1]) cylinder(d=40, h=WALL+2);          // 底の配線/整備穴(小さめ・任意)
  }
}

module servo_cradle(s){
  // サーボ本体(軸=+X向き, 軸z=AXLE_Z)を抱くU字クレードル(底板上に融着)
  // 本体占有: x[FACE_X-SVH, FACE_X], y[-SH_OFF-…], z[AXLE_Z±SVW/2]
  bx = FACE_X - SVH;                       // 本体内端X
  difference(){
    translate([s*(bx+SVH/2), 0, (GC+WALL+AXLE_Z+SVW/2+2)/2])
      cube([SVH+2*WALL, SVL+2*WALL+8, AXLE_Z+SVW/2+2-(GC+WALL)], center=true);
    // 本体ポケット(実寸+0.6遊び, 上開放)
    translate([s*(bx+SVH/2), SVL/2-SH_OFF-SVL/2 +0, AXLE_Z])
      cube([SVH+0.6, SVL+0.6, SVW+0.6], center=true);
    translate([s*(bx+SVH/2), 0, AXLE_Z+SVW/2+5]) cube([SVH+10, SVL+10, 12], center=true); // 上開放
    // タブ/配線逃げ(内側へ)
    translate([s*(bx-4), 0, AXLE_Z]) cube([10, SVL+0.6, SVW+0.6], center=true);
  }
}

module drive_base(){
  difference(){
    union(){
      base_plate();
      // 外周スカート(ドラム壁 z=GC..BH)
      translate([0,0,GC]) difference(){
        cylinder(d=JBOT_D, h=BH-GC);
        translate([0,0,-1]) cylinder(d=JBOT_D-2*WALL, h=BH-GC+2);
      }
      // 天面デッキ(胴が載る)+中央井戸
      translate([0,0,BH-WALL]) difference(){
        cylinder(d=JBOT_D, h=WALL);
        translate([0,0,-1]) cylinder(d=CABLE_D, h=WALL+2);
      }
      // 位置決めリム(胴裾の内側に入る。アーチ部分は切り欠き)
      difference(){
        translate([0,0,BH-0.1]) difference(){
          cylinder(d=JBOT_D-2*WALL-0.8, h=6);
          translate([0,0,-1]) cylinder(d=JBOT_D-2*WALL-0.8-6, h=8);
        }
        for(s=[-1,1]) translate([s*WX, 0, BH+3]) cube([WHEEL_W+12, WHEEL_D+14, 16], center=true);
      }
      // 井戸の筒(天面→底板: ケーブルを部品から隔離)
      translate([0,0,GC+WALL-0.1]) difference(){
        cylinder(d=CABLE_D+2*WALL, h=BH-GC-2*WALL);
        translate([0,0,-1]) cylinder(d=CABLE_D, h=BH-GC+2);
      }
      for(s=[-1,1]) servo_cradle(s);
      // ★ホイールアーチ(フェンダー): タイヤ上端(z=60)が天面(45)を超えるため、
      //   天面上に箱を立てて胴内側へ逃がす(胴内のRDKはx±31なので非干渉)
      for(s=[-1,1]) translate([s*WX, 0, 0]) intersection(){
        difference(){
          translate([0,0,(BH-WALL+AXLE_Z+WHEEL_D/2+4)/2])
            cube([WHEEL_W+10, WHEEL_D+12, AXLE_Z+WHEEL_D/2+4-(BH-WALL)], center=true);
          translate([0,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true); // 車輪空洞
        }
        translate([-s*WX,0,0]) cylinder(d=JBOT_D-2*WALL-1, h=200);  // 胴内径でクリップ(角のはみ出し防止)
      }
      // キャスタ台座(前後, 底板下面: タミヤ70144をM3×2で固定, 皿は現物合わせ)
      for(t=[-1,1]) translate([0, t*CAST_Y, GC-2]) cylinder(d=24, h=2.1);
    }
    // 車輪の貫通(底板/天面デッキ/アーチ内)
    for(s=[-1,1]) translate([s*WX, 0, GC+WALL/2]) cube([WHEEL_W+8, WHEEL_D+10, WALL+4], center=true);
    for(s=[-1,1]) translate([s*WX, 0, AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true);
    for(s=[-1,1]) translate([s*WX, 0, BH-WALL/2]) cube([WHEEL_W+4, WHEEL_D+4, WALL+4], center=true);
    // キャスタねじ穴(M3下穴, ピッチは70144現物合わせ・仮15mm)
    for(t=[-1,1]) for(p=[-1,1]) translate([p*7.5, t*CAST_Y, GC-3]) cylinder(d=2.6, h=WALL+6);
    // サーボ配線の井戸への通し穴
    for(s=[-1,1]) translate([s*30, 0, GC+WALL/2]) cube([16,10,WALL+4], center=true);
  }
}

module ghosts(){
  for(s=[-1,1]){
    %color("#90caf9") translate([s*WX,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D,h=WHEEL_W,center=true); // タイヤ
    %color("#1976d2") translate([s*(FACE_X-SVH/2),0,AXLE_Z]) cube([SVH,SVL,SVW],center=true);               // FS90R
  }
  for(t=[-1,1]) %color("#9e9e9e") translate([0,t*CAST_Y,GC/2]) cylinder(d1=10,d2=18,h=GC);                   // キャスタ
  %color("red") translate([0,0,GC]) cylinder(d=CABLE_D-4, h=BH+20);                                          // ケーブル束
  %color("#455a64") translate([-30, 38, GC+WALL]) cube([60,28,20]);   // サーボ用LiPo(小型2S級, 井戸の後ろ側の空間)
}

SHOW=0;
color("#d97706") drive_base();
if(SHOW==0) ghosts();
