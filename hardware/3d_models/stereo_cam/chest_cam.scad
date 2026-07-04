/* コロ助 胸カメラユニット / Korosuke chest stereo-cam module  v0.1
 * ELP USB3D1080P02(80x16.5, レンズ間60, フードφ18)を胴前面に横置きし、
 * 左右レンズを「赤い胸ボタン2つ」に擬態させる。胴カーブR82に沿う。
 * 印刷: 正面(レンズ面)を下=ピン真上、サポート不要。
 * SHOW 1=胸プレート(橙) 2=赤ベゼルリングx2 3=背面クリップ蓋 4=プッシュナットx4
 *      9=胴に開ける窓(jacket統合用の差分体) 0=組立プレビュー
 * License: CC BY 4.0 / Kazuki Murata */

// ---- カメラ実測(elp_stereo_case.scadと一致) ----
BOARD_W=80.5; BOARD_H=17.0; BOARD_T=6.0;
LENS_PITCH=60; HOOD_D=18; PIN_X=76+1; PIN_Z=13;   // ピン穴ピッチ(横77/縦13)
// ---- 胴 ----
CHEST_R=82;                    // 胴前面カーブ半径(JACKET中腹)
// ---- プレート ----
PW=92; PH=30; FT=3.2;          // 面板 幅/高/厚
FLANGE=3; FL_T=2.4;            // 裏フランジ(胴内側に当たる)
WALL=2.4;
$fn=72;

// 胴カーブを与える差分シリンダ(前面をR82に凹ませ、胴表面と面一に)
module curve_sub(){ translate([0,-CHEST_R,0]) rotate([0,0,0]) cylinder(r=CHEST_R,h=PH+20,center=true,$fn=160); }

module chest_plate(){
  difference(){
    union(){
      // 面板(前面カーブ)
      difference(){
        translate([-PW/2,-FT,-PH/2]) cube([PW,FT+8,PH]);
        translate([0,8,0]) curve_sub();                 // 前面をR82に
      }
      // 基板ケース箱(裏側へ深さBOARD_T+WALL)
      translate([-(BOARD_W/2+WALL),0,-(BOARD_H/2+WALL)])
        cube([BOARD_W+2*WALL, BOARD_T+WALL+1, BOARD_H+2*WALL]);
      // 裏フランジ(胴の窓内側に引っかかる)
      translate([-(PW+2*FLANGE)/2, BOARD_T+WALL-FL_T, -(PH+2*FLANGE)/2])
        difference(){
          cube([PW+2*FLANGE, FL_T, PH+2*FLANGE]);
          translate([FLANGE,-1,FLANGE]) cube([PW,FL_T+2,PH]);
        }
    }
    // 基板室(裏から挿入)
    translate([-(BOARD_W+0.5)/2,0.1,-(BOARD_H+0.5)/2]) cube([BOARD_W+0.5, BOARD_T+WALL+2, BOARD_H+0.5]);
    // レンズ窓 x2(フードφ18ごと通す→φ19)
    for(s=[-1,1]) translate([s*LENS_PITCH/2,-FT-2,0]) rotate([-90,0,0]) cylinder(d=HOOD_D+1, h=FT+10);
    // 赤ベゼルの座ぐり(前面に外径φ26x深1.6の円座)
    for(s=[-1,1]) translate([s*LENS_PITCH/2,0,0]){
      hull() for(a=[0:5:359]) translate([0.001*cos(a),0,0.001*sin(a)]) ; // noop
    }
    // USB-C 下出し(前後貫通)
    translate([-7, -FT-2, -(BOARD_H/2+WALL)-1]) cube([14, BOARD_T+WALL+FT+4, WALL+2]);
  }
  // 固定ピンφ1.5 x4(基板穴→クリップ蓋を貫通し2mm突出)
  for(sx=[-1,1],iz=[-1,1]) translate([sx*PIN_X/2, 0.1, iz*PIN_Z/2])
    rotate([-90,0,0]) cylinder(d=1.8, h=BOARD_T+WALL+2.1);   // φ2(φ1.5は折れた)
}

// 赤ベゼル: 前面に嵌める化粧リング(=胸の赤ボタン)。外φ26/窓φ19、球面キャップ風
module chest_bezel(){
  difference(){
    union(){
      cylinder(d=26,h=2.0);
      translate([0,0,2.0]) scale([1,1,0.35]) sphere(d=26);   // ぷっくり
      translate([0,0,-2.3]) cylinder(d=HOOD_D+0.6,h=2.6);     // 窓への差込首
    }
    translate([0,0,-3]) cylinder(d=HOOD_D-0.5,h=12);          // レンズ通し
  }
}

// 背面クリップ蓋: 基板を前壁に押し付ける。ピン穴φ1.8 x4
module chest_lid(){
  difference(){
    cube([BOARD_W+0.4, 2.4, BOARD_H+0.4], center=true);
    for(sx=[-1,1],iz=[-1,1]) translate([sx*PIN_X/2, -2, iz*PIN_Z/2]) rotate([-90,0,0]) cylinder(d=2.1,h=6);
    translate([0,-2,-(BOARD_H)/2]) cube([14,6,3]);            // USB逃げ
  }
}
module pushnut(){ difference(){ cylinder(d=7,h=2.5,$fn=48); translate([0,0,-1]) cylinder(d=1.85,h=5); } }

// 胴に開ける窓(jacket_shell統合用の差分。プレート面板+フランジ用)
module chest_window(){
  translate([0,0,0]) rotate([90,0,0]){
    cube([PW+0.6, PH+0.6, 30], center=true);                 // 面板が通る角穴
    translate([0,0,-8]) cube([PW+2*FLANGE+0.6, PH+2*FLANGE+0.6, 6], center=true); // フランジ座ぐり(内側)
  }
}

SHOW=0;
if(SHOW==0){
  color("#ef8f1f") chest_plate();
  for(s=[-1,1]) color("#c0392b") translate([s*LENS_PITCH/2,-FT-0.3,0]) rotate([-90,0,0]) chest_bezel();
  color("#5a5a5a") translate([0,BOARD_T+WALL+1.4,0]) rotate([90,0,0]) chest_lid();
}
else if(SHOW==1) translate([0,0,11]) rotate([-90,0,0]) chest_plate(); // 面板下=ピン上
else if(SHOW==2) translate([0,0,2.3]) chest_bezel();
else if(SHOW==3) translate([0,0,1.2]) rotate([90,0,0]) chest_lid();
else if(SHOW==4) pushnut();
else if(SHOW==9) chest_window();
