/* コロ助 胸カメラユニット / Korosuke chest stereo-cam module  v0.3
 * ELP USB3D1080P02(80x16.5, レンズ間60, フードφ18)を胴前面に横置き。
 * 【外付けパネル方式】カメラを載せた曲面パネルを胴の窓に外から当てて
 *  四隅M2で胴壁にネジ止め。基板箱は胴内へ潜り、外観はパネル+赤ベゼル2つ。
 *  基板固定(ピン+蓋+ナット)はベンチで完了 → 胴へは外からネジ4本だけ。
 *
 * 座標: +y=胴内(奥) / -y=前(手前). パネル前面/背面ともR82同心曲面(胴に密着)。
 * SHOW 0=組立プレビュー 1=パネル(印刷) 2=赤ベゼルx2 3=蓋 4=プッシュナット
 *      9=胴に開ける差分(箱通し穴+M2下穴, jacket統合用)
 * License: CC BY 4.0 / Kazuki Murata */

// ---- カメラ実測 ----
BOARD_W=80.5; BOARD_H=17.0; BOARD_T=6.0;
LENS_PITCH=60; HOOD_D=18; PIN_X=77; PIN_Z=13;
// ---- 胴/パネル ----
TC=82;                 // 胴前面カーブ半径(=胴軸までの距離)
FT=3.4;                // パネル厚
PW=100; PH=38;         // パネル 幅/高(M2穴を内包する大きさ)
WALL=2.4;
EAR_X=BOARD_W/2+4; EAR_Z=BOARD_H/2+5.5;   // M2穴位置(パネル内)
$fn=72;

// 胴と同心の縦シリンダ(軸z)。front point(min y)= TC-r
module tcyl(r) translate([0,TC,0]) cylinder(r=r, h=PH+60, center=true, $fn=260);
// R82〜R(82+t) の湾曲スラブを x範囲w・z範囲h でクリップ
module curved_slab(t,w,h) intersection(){
  difference(){ tcyl(TC+t); tcyl(TC); }
  translate([-w/2,-40,-h/2]) cube([w,80,h]);
}

module chest_plate(){
  difference(){
    union(){
      curved_slab(FT, PW, PH);                                   // 曲面パネル(M2穴を内包)
      translate([-(BOARD_W/2+WALL), 0, -(BOARD_H/2+WALL)])       // 基板箱(背面→胴内+y)
        cube([BOARD_W+2*WALL, BOARD_T+WALL+2, BOARD_H+2*WALL]);
    }
    translate([-(BOARD_W+0.5)/2, 1.6, -(BOARD_H+0.5)/2]) cube([BOARD_W+0.5, BOARD_T+WALL+3, BOARD_H+0.5]); // 基板室(+y挿入)
    for(s=[-1,1]) translate([s*LENS_PITCH/2, -FT-4, 0]) rotate([-90,0,0]) cylinder(d=HOOD_D+1, h=FT+8);     // レンズ窓x2
    for(s=[-1,1]) translate([s*LENS_PITCH/2, -FT-0.01, 0]) rotate([90,0,0]) cylinder(d=26, h=1.4);          // 赤ベゼル座ぐり
    translate([-7, -FT-4, -(BOARD_H/2+WALL)-1]) cube([14, BOARD_T+WALL+FT+8, WALL+2]);                      // USB下出し
    for(sx=[-1,1],iz=[-1,1]) translate([sx*EAR_X, -FT-4, iz*EAR_Z]) rotate([-90,0,0]) cylinder(d=2.3, h=FT+8); // M2貫通穴x4
  }
  for(sx=[-1,1],iz=[-1,1]) translate([sx*PIN_X/2, 1.5, iz*PIN_Z/2])   // 固定ピンφ1.8 x4
    rotate([-90,0,0]) cylinder(d=1.8, h=BOARD_T+2.4+2.1);
}

module chest_bezel(){   // 赤ベゼル=胸ボタン。座ぐりφ26に嵌りぷっくり
  difference(){
    union(){
      cylinder(d=25.6, h=1.4);
      translate([0,0,1.4]) scale([1,1,0.4]) sphere(d=25.6);
      translate([0,0,-2.4]) cylinder(d=HOOD_D+0.6, h=2.6);
    }
    translate([0,0,-6]) cylinder(d=HOOD_D-0.5, h=16);          // 深く貫通(ドーム底の浮遊片を除去)
  }
}
module chest_lid(){     // 背面蓋(胴内側): 基板を箱前壁へ押さえる
  difference(){
    cube([BOARD_W+0.4, 2.4, BOARD_H+0.4], center=true);
    for(sx=[-1,1],iz=[-1,1]) translate([sx*PIN_X/2, -2, iz*PIN_Z/2]) rotate([-90,0,0]) cylinder(d=2.1, h=6);
    translate([0,-2,-(BOARD_H)/2]) cube([14,6,3]);
  }
}
module pushnut(){ difference(){ cylinder(d=8,h=3,$fn=6); translate([0,0,-1]) cylinder(d=1.4,h=6); } }

// 胴(jacket_shell)へ差分: 箱通し穴 + M2下穴x4
module chest_cut(){
  translate([-(BOARD_W/2+WALL+0.6), -1, -(BOARD_H/2+WALL+0.6)]) cube([BOARD_W+2*WALL+1.2, TC+10, BOARD_H+2*WALL+1.2]);
  for(sx=[-1,1],iz=[-1,1]) translate([sx*EAR_X, -5, iz*EAR_Z]) rotate([-90,0,0]) cylinder(d=1.7, h=TC);
}

SHOW=0;
if(SHOW==0){
  color("#ef8f1f") chest_plate();
  for(s=[-1,1]) color("#c0392b") translate([s*LENS_PITCH/2,-FT-1.3,0]) rotate([90,0,0]) chest_bezel();
  color("#555") translate([0, BOARD_T+WALL+1.4, 0]) rotate([90,0,0]) chest_lid();
}
else if(SHOW==1) translate([0,0,17]) rotate([-90,0,0]) chest_plate();  // 箱背面を下
else if(SHOW==2) translate([0,0,3.72]) chest_bezel();
else if(SHOW==3) translate([0,0,1.2]) rotate([90,0,0]) chest_lid();
else if(SHOW==4) pushnut();
else if(SHOW==9) chest_cut();
