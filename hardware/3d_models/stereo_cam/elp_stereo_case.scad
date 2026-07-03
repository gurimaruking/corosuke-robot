/* ELP USB3D1080P02-H120 双眼カメラケース v0.1
 * 基板: 80x16.5mm(ELP公称)。★印刷前にノギスで3つ実測して更新すること:
 *   LENS_PITCH(レンズ中心間隔) / LENS_D(レンズ鏡筒外径) / BOARD_T(基板+裏面部品厚)
 * SHOW: 1=テストケース本体 2=スライド蓋 3=コロ助胸マウント(曲面アダプタ)
 * License: CC BY 4.0 / Kazuki Murata */
BOARD_W=80.5; BOARD_H=17.0;     // 基板ポケット(公称+遊び)
BOARD_T=6.0;                    // ★実測: 基板1.6+裏面部品
LENS_PITCH=60;                  // ★実測: レンズ中心間隔
LENS_D=18.0;                    // 実測(2026-07-03)
WALL=2.4; USB_W=11;
W=BOARD_W+2*WALL+1; H=BOARD_H+2*WALL+1; D=BOARD_T+WALL+2.2;
$fn=64;
module body(){
  difference(){
    cube([W,D,H]);
    translate([WALL,WALL,WALL]) cube([BOARD_W+1,D,BOARD_H+1]);          // 基板室(背面開放=蓋)
    for(s=[-1,1]) translate([W/2+s*LENS_PITCH/2,-1,H/2]) rotate([-90,0,0]) cylinder(d=LENS_D,h=WALL+2); // レンズ穴
    // USB-C出口(実機確認2026-07-03): 基板中央・下向き。底壁を背面まで開放
    translate([W/2-7,WALL,-1]) cube([14,D,WALL+2]);
    for(s=[-1,1]) translate([W/2+s*(W/2+5),0,0]) ;                       // (ears below)
  }
  for(s=[0,1]) translate([s==0 ? -4 : W-0.1, 0, 0]) difference(){        // M3耳x2
    cube([4.1,D,10]); translate([-1,D/2,5]) rotate([0,90,0]) cylinder(d=3.4,h=7);
  }
  // 基板四隅M2固定ポスト(★M2X/M2Zは穴中心間の実測で要確認)
  M2X=75; M2Z=11.5;
  for(ix=[-1,1],iz=[-1,1]) translate([W/2+ix*M2X/2, WALL-0.1, WALL+(BOARD_H+1)/2+iz*M2Z/2])
    rotate([-90,0,0]) difference(){ cylinder(d=5,h=2.1); cylinder(d=1.8,h=8,center=true); }
}
module lid(){ cube([BOARD_W+0.6,1.8,BOARD_H+0.6]); }                    // 背面スライド蓋(簡易)
module chest_mount(){                                                    // 胸マウント: 胴の円錐面(R~80)に沿う受け
  difference(){
    cube([W+16,10,H+6]);
    translate([(W+16)/2,88,-1]) cylinder(r=80,h=H+8);                   // 胴カーブ
    for(s=[0,1]) translate([s*(W+8)+4,-1,(H+6)/2]) rotate([-90,0,0]) cylinder(d=3.4,h=12); // ケース耳と共締め
  }
}
SHOW=1;
if(SHOW==1) body(); else if(SHOW==2) lid(); else if(SHOW==3) chest_mount();
