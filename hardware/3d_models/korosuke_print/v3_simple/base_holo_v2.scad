/*
 * コロ助 φ158 ホロノミック・ドライブベース v2 (実設計・第1版) / 2026-07-29
 *
 * 確定仕様: STS3215×3 を120°放射配置(車輪軸R=69) + 48mmオムニ輪。
 *   中央にφ48ケーブル井戸(RDK X5のUSBをまっすぐ下へ、コネクタは胴内)。
 *   天面=胴(φ158裾)を載せるドック面+位置決めリム。サーボ間ギャップは予備配線路。
 *   胴の臓物は無改造、増設はこのベース(底板の下)に閉じる。
 *
 * SHOW: 0=プレビュー(部品ゴースト) / 1=ベース単体(印刷用)
 */
$fn = 96;
JBOT_D = 158;            // 胴裾径=ベース外径
WALL   = 3;
BH     = 45;             // ベース高さ(サーボ+オムニを収める)
RW     = 69;             // 車輪軸の半径位置(φ158に収まる上限付近)
CABLE_D = 48;            // 中央ケーブル井戸
// STS3215 [W(接線), L(放射), H]
SGW=24.7; SGL=45.2; SGH=35;
OMNI_D=48; OMNI_W=20;
AXLE_Z = 3 + OMNI_D/2;   // 車輪軸高さ(接地させる: 底からOMNI半径)
PAD=0.6;                 // サーボ嵌合クリア

module ring(od,id,h){ linear_extrude(h) difference(){ circle(d=od); circle(d=id); } }

// 1個ぶんの駆動モジュール(サーボ架台+車輪ウェル)を +Y 側に作る
module drive_unit(){
  // サーボ架台: 上開放の箱(放射方向に本体、外端が車輪側)
  translate([0, RW-SGL/2-OMNI_W/2, AXLE_Z])
    difference(){
      cube([SGW+2*WALL, SGL+2*WALL, SGH+WALL], center=true);           // 外形
      translate([0,0,WALL]) cube([SGW+2*PAD, SGL+2*PAD, SGH+2], center=true); // 本体ポケット
      // 配線・ホーン抜き(内側=中心向き)
      translate([0,-SGL/2,0]) cube([SGW+2*PAD, 10, SGH], center=true);
    }
  // 車輪ウェル: ドラム壁の外周に、オムニがはみ出す縦スリット(接線方向)
  // (massing: 車輪ゴーストはプレビューで表示。ここでは壁を薄く欠く)
}

// ドラム本体
module drive_base(){
  difference(){
    union(){
      ring(JBOT_D, JBOT_D-2*WALL, BH);                     // 外周ドラム壁
      translate([0,0,BH-WALL]) linear_extrude(WALL)        // 天面デッキ(胴が載る)
        difference(){ circle(d=JBOT_D); circle(d=CABLE_D); }
      translate([0,0,BH-WALL-6]) ring(JBOT_D-2*WALL, JBOT_D-2*WALL-6, 6); // 位置決めリム(胴裾内側へ)
      // 中央ケーブル井戸の筒(天面から底近くまで)
      translate([0,0,0]) ring(CABLE_D+2*WALL, CABLE_D, BH-WALL);
      for(a=[0,120,240]) rotate([0,0,a]) drive_unit();     // サーボ架台×3
    }
    // 車輪スリット(外周壁を接線方向に欠く: オムニが外&下へ出る)
    for(a=[0,120,240]) rotate([0,0,a])
      translate([0, RW, AXLE_Z]) rotate([90,0,0])
        cylinder(d=OMNI_D+4, h=OMNI_W+6, center=true);
    // 底の車輪開口(下へ接地)
    for(a=[0,120,240]) rotate([0,0,a])
      translate([0, RW, -1]) cube([OMNI_W+4, OMNI_D+8, 8], center=true);
  }
}

// ゴースト部品(プレビュー)
module ghosts(){
  for(a=[0,120,240]) rotate([0,0,a]){
    %color("#90caf9") translate([0,RW,AXLE_Z]) rotate([90,0,0]) cylinder(d=OMNI_D,h=OMNI_W,center=true); // オムニ
    %color("#1976d2") translate([0,RW-SGL/2-OMNI_W/2,AXLE_Z]) cube([SGW,SGL,SGH],center=true);            // STS3215
  }
  %color("red") translate([0,0,-2]) cylinder(d=CABLE_D, h=BH+30);  // ケーブル束
}

SHOW=0;
color("#d97706") drive_base();
if(SHOW==0) ghosts();
