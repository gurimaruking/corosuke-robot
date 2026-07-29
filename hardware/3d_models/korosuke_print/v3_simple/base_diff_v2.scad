/*
 * コロ助 差動2輪ドライブベース v2 (精密化) / 2026-07-29
 *
 * v1からの変更:
 *   - サーボ取付を「バルクヘッド(隔壁)ネジ止め」方式に精密化。
 *     FS90RはSG90取付互換(本体23.2×12.5×22.4, タブ穴ピッチ≈28, M2)→ フランジ角穴+タブ下穴。
 *     サーボは内側から挿入しタブを内面にM2×2でネジ止め、スプライン=外向き、タイヤ直結。
 *   - キャスタ穴を長穴(スロット)化: タミヤ70144の穴ピッチ非公開のため8〜24mmをカバー。
 *   - 配線チャネル(サーボ線→中央井戸)・LiPo結束バンド穴を追加。
 *   - SHOW=2 フィット確認クーポン(バルクヘッド+キャスタ台座だけの小片, 印刷30分級)。
 *
 * 部品(全て秋月): FS90R×2(g113206) + FS90R-Wタイヤφ60×8(g113207) + タミヤ70144(g110372)
 * SHOW: 0=プレビュー / 1=ベース単体(印刷) / 2=フィットクーポン(印刷)
 */
$fn = 96;
JBOT_D = 158;  WALL = 3;
GC = 11;  BH = 45;  CABLE_D = 90;

// ---- FS90R (SG90取付互換) ----
SVL=23.2; SVW=12.5;            // 本体 長(Y)×幅(Z)
SV_OFF=5.8;                    // 軸は本体端から5.8
SV_INB=18.4;                   // フランジ面から内側の本体深さ(22.4-上部4.0)
TABP=28; TABD=1.8;             // タブ穴ピッチ/M2下穴
CLR=0.6;                       // 嵌合遊び

WHEEL_D=60; WHEEL_W=8; AXLE_Z=WHEEL_D/2;
WX=65;                          // 車輪中心X(外面69<79)
BF_X=55;                        // バルクヘッド外面X(スプライン+ハブ余裕→タイヤ内面61)
CAST_Y=58;

module ring(od,id,h){ linear_extrude(h) difference(){ circle(d=od); circle(d=id); } }

// ---- サーボ・バルクヘッド(1枚, +X側基準。s=±1) ----
module bulkhead(s){
  difference(){
    union(){
      // 隔壁本体(z14-40, y -14..+26 = 軸y0/遠端18を覆う)
      translate([s*(BF_X-WALL), -14, GC+WALL-0.1])
        cube_x(s, WALL, 40, 26.1);
      // ガセット×2(倒れ防止)
      for(gy=[-14, 23]) translate([s*(BF_X-WALL-10), gy, GC+WALL-0.1]) cube_x(s, 10+WALL, 3, 12);
    }
    // フランジ角穴(本体断面+遊び: y -5.8-CLR..17.4+CLR, z 30±(SVW+2*CLR)/2)
    translate([s*(BF_X-WALL-1), -SV_OFF-CLR, AXLE_Z-SVW/2-CLR])
      cube_x(s, WALL+2, SVL+2*CLR, SVW+2*CLR);
    // タブM2下穴×2(本体中心y=5.8からピッチ28)
    for(hy=[5.8-TABP/2, 5.8+TABP/2])
      translate([s*(BF_X-WALL/2), hy, AXLE_Z]) rotate([0,90,0]) cylinder(d=TABD, h=WALL+4, center=true);
  }
}
// s方向に伸びる箱(mirror不要): 原点から s*dx, dy, dz
module cube_x(s,dx,dy,dz){ translate([min(0,s*dx),0,0]) cube([abs(dx),dy,dz]); }

module base_plate(){
  difference(){
    translate([0,0,GC]) cylinder(d=JBOT_D, h=WALL);
    for(sd=[-1,1]) translate([sd*WX, 0, GC-1]) cube([WHEEL_W+8, WHEEL_D+10, WALL+2], center=true);
    translate([0,0,GC-1]) cylinder(d=40, h=WALL+2);                       // 底の整備穴
    // サーボ配線チャネル(隔壁内側→井戸へ)
    for(sd=[-1,1]) translate([sd*38, 6, GC+WALL/2]) cube([14, 10, WALL+4], center=true);
    // キャスタ長穴(ピッチ8〜24mm対応, 前後)
    for(t=[-1,1]) for(p=[-1,1])
      translate([0, t*CAST_Y, 0]) hull(){
        translate([p*4, 0, GC-3]) cylinder(d=2.7, h=WALL+6);
        translate([p*12, 0, GC-3]) cylinder(d=2.7, h=WALL+6);
      }
    for(t=[-1,1]) translate([0, t*CAST_Y, GC-3]) cylinder(d=5, h=WALL+6); // 中心逃げ
  }
}

module drive_base(){
  difference(){
    union(){
      base_plate();
      translate([0,0,GC]) ring(JBOT_D, JBOT_D-2*WALL, BH-GC);            // 外周スカート
      translate([0,0,BH-WALL]) difference(){                              // 天面デッキ
        cylinder(d=JBOT_D, h=WALL);
        translate([0,0,-1]) cylinder(d=CABLE_D, h=WALL+2);
      }
      difference(){                                                       // 位置決めリム(アーチ部切欠)
        translate([0,0,BH-0.1]) ring(JBOT_D-2*WALL-0.8, JBOT_D-2*WALL-0.8-6, 6);
        for(sd=[-1,1]) translate([sd*WX, 0, BH+3]) cube([WHEEL_W+12, WHEEL_D+14, 16], center=true);
      }
      translate([0,0,GC+WALL-0.1]) ring(CABLE_D+2*WALL, CABLE_D, BH-GC-2*WALL); // 井戸の筒
      for(sd=[-1,1]) bulkhead(sd);
      // ホイールアーチ(胴内径でクリップ)
      for(sd=[-1,1]) translate([sd*WX, 0, 0]) intersection(){
        difference(){
          translate([0,0,(BH-WALL+AXLE_Z+WHEEL_D/2+4)/2])
            cube([WHEEL_W+10, WHEEL_D+12, AXLE_Z+WHEEL_D/2+4-(BH-WALL)], center=true);
          translate([0,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true);
        }
        translate([-sd*WX,0,0]) cylinder(d=JBOT_D-2*WALL-1, h=200);
      }
      for(t=[-1,1]) translate([0, t*CAST_Y, GC-2]) cylinder(d=30, h=2.1); // キャスタ台座
      // LiPo結束バンド穴用リブ(井戸の後ろ)
      translate([-32, 36, GC+WALL-0.1]) cube([64, 2.5, 8]);
      translate([-32, 67, GC+WALL-0.1]) cube([64, 2.5, 8]);
    }
    // 車輪貫通(底板/デッキ/アーチ)
    for(sd=[-1,1]) translate([sd*WX, 0, GC+WALL/2]) cube([WHEEL_W+8, WHEEL_D+10, WALL+4], center=true);
    for(sd=[-1,1]) translate([sd*WX, 0, AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true);
    for(sd=[-1,1]) translate([sd*WX, 0, BH-WALL/2]) cube([WHEEL_W+4, WHEEL_D+4, WALL+4], center=true);
    // キャスタ長穴を台座まで貫通
    for(t=[-1,1]) for(p=[-1,1])
      translate([0, t*CAST_Y, 0]) hull(){
        translate([p*4, 0, GC-3]) cylinder(d=2.7, h=WALL+8);
        translate([p*12, 0, GC-3]) cylinder(d=2.7, h=WALL+8);
      }
  }
}

// ---- フィット確認クーポン(印刷30分級): バルクヘッド+キャスタ台座 ----
module coupon(){
  difference(){
    union(){
      cube([64, 46, 3]);                                        // 台板
      translate([8, 40, 2.9]) cube([48, 3, 26.1]);              // 隔壁(立て)
      for(gx=[8, 53]) translate([gx, 30, 2.9]) cube([3, 10+3, 12]); // ガセット
      translate([18, 14, 2.9]) cylinder(d=30, h=2.1);           // キャスタ台座
    }
    // フランジ角穴+タブ穴(隔壁: 軸z=16相当・角穴中心x=32)
    translate([32-(SVL/2+CLR), 39, 16-(SVW/2+CLR)])
      cube([SVL+2*CLR, 5, SVW+2*CLR]);
    for(hx=[32-TABP/2, 32+TABP/2]) translate([hx, 39, 16]) rotate([-90,0,0]) cylinder(d=TABD, h=6);
    // キャスタ長穴
    for(p=[-1,1]) translate([18,14,0]) hull(){
      translate([p*4,0,-1]) cylinder(d=2.7, h=8); translate([p*12,0,-1]) cylinder(d=2.7, h=8); }
    translate([18,14,-1]) cylinder(d=5, h=8);
  }
}

module ghosts(){
  for(sd=[-1,1]){
    %color("#90caf9") translate([sd*WX,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D,h=WHEEL_W,center=true);
    %color("#1976d2") translate([sd*(BF_X-WALL-SV_INB/2),0,AXLE_Z])
      cube([SV_INB,SVL,SVW],center=true);                       // FS90R本体(隔壁内面x=±52から内側へ)
  }
  for(t=[-1,1]) %color("#9e9e9e") translate([0,t*CAST_Y,GC/2]) cylinder(d1=10,d2=18,h=GC);
  %color("red") translate([0,0,GC]) cylinder(d=CABLE_D-4, h=BH+20);
  %color("#455a64") translate([-30, 39, GC+WALL]) cube([60,28,20]);  // サーボ用LiPo(バンドリブ間)
}

SHOW=0;
if(SHOW==2) coupon();
else { color("#d97706") drive_base(); if(SHOW==0) ghosts(); }
