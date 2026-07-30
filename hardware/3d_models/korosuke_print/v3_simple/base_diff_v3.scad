/*
 * コロ助 差動2輪ドライブベース v3 (ドライブポッド方式) / 2026-07-30
 *
 * v2の組立欠陥(ユーザー指摘)を修正:
 *   「サーボを固定した後にタイヤを付けるスペースが無い/タイヤ中心ネジに工具が届かない」
 *   → アーチ+隔壁を『ドライブポッド』としてベースから分離。
 *     机上で サーボ→隔壁M2止め→タイヤ装着(中心ネジ) まで完組みし、
 *     ポッドごと上からデッキ開口へ落とし込み → M3×3を上からネジ止め。
 *     ホイール交換/サーボ交換はポッドを外すだけ。
 *
 * キャスタ(タミヤ70144×前後2): 差動2輪の前後転倒を支える第3/第4の接地点。
 *
 * 部品(全て秋月): FS90R×2(g113206) + FS90R-Wタイヤφ60×8(g113207) + 70144(g110372)
 * SHOW: 0=プレビュー / 1=ベース(印刷×1) / 2=フィットクーポン / 3=ドライブポッド(印刷×2)
 */
$fn = 96;
JBOT_D = 158;  WALL = 3;
GC = 11;  BH = 45;  CABLE_D = 90;

// ---- FS90R (SG90取付互換) ----
SVL=23.2; SVW=12.5; SV_OFF=5.8; SV_INB=18.4;
TABP=28; TABD=1.8; CLR=0.6;

WHEEL_D=60; WHEEL_W=8; AXLE_Z=WHEEL_D/2;
WX=65; BF_X=55;                 // 車輪中心X / バルクヘッド外面X
CAST_Y=58;

// ポッド開口(デッキ): タイヤ+隔壁が上から通る矩形(外周の胴座面r76-79は温存)
POD_XA=51; POD_XB=72; POD_YH=32;      // x51..72, y±32
// ポッドフランジ: 開口を覆う縁(デッキに載る)。クリップはd=151(リム内=胴座面に届かない)
FLG_XA=44; FLG_XB=80; FLG_YH=36; FLG_T=3;
// ポッド固定M3×4(全て開口の縁の上=デッキ実体上)
function pod_screws() = [[47,30],[47,-30],[62,34],[62,-34]];

module ring(od,id,h){ linear_extrude(h) difference(){ circle(d=od); circle(d=id); } }
module cube_x(s,dx,dy,dz){ translate([min(0,s*dx),0,0]) cube([abs(dx),dy,dz]); }

// ============================ ドライブポッド(+X側。印刷は2個) ============================
module drive_pod(){
  difference(){
    union(){
      // フランジ(デッキに載る縁, リム内径d151でクリップ=胴座面r76-79に載せない)
      intersection(){
        translate([FLG_XA, -FLG_YH, BH]) cube([FLG_XB-FLG_XA, 2*FLG_YH, FLG_T]);
        cylinder(d=JBOT_D-2*WALL-1, h=200);
      }
      // アーチ(タイヤ覆い, 同じくd151でクリップ=胴壁と非干渉)
      translate([WX, 0, 0]) intersection(){
        difference(){
          translate([0,0,(BH+FLG_T+AXLE_Z+WHEEL_D/2+4)/2])
            cube([WHEEL_W+10, WHEEL_D+12, AXLE_Z+WHEEL_D/2+4-BH-FLG_T], center=true);
          translate([0,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true);
        }
        translate([-WX,0,0]) cylinder(d=JBOT_D-2*WALL-1, h=200);
      }
      // 隔壁(フランジ下面からz16まで垂下, y -14..26)
      translate([BF_X-WALL, -14, 16]) cube([WALL, 40, BH-16+0.1]);
      // ガセット(隔壁内面とフランジ下面をつなぐ)
      for(gy=[-14, 23]) translate([BF_X-WALL-10, gy, BH-8]) cube([10, 3, 8.1]);
    }
    // フランジのタイヤ通し穴(デッキ開口と同位置)
    translate([WX-6, -32, BH-1]) cube([12, 64, FLG_T+2]);
    // サーボ フランジ角穴(遊び0.6)+タブM2下穴(ピッチ28)
    translate([BF_X-WALL-1, -SV_OFF-CLR, AXLE_Z-SVW/2-CLR]) cube([WALL+2, SVL+2*CLR, SVW+2*CLR]);
    for(hy=[5.8-TABP/2, 5.8+TABP/2])
      translate([BF_X-WALL/2, hy, AXLE_Z]) rotate([0,90,0]) cylinder(d=TABD, h=WALL+4, center=true);
    // ポッド固定M3通し穴(φ3.4)
    for(p=pod_screws()) translate([p[0], p[1], BH-1]) cylinder(d=3.4, h=FLG_T+2);
    // アーチ内のタイヤ空洞を念押しで貫通
    translate([WX,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D+5, h=WHEEL_W+4, center=true);
  }
}

// ============================ ベース本体 ============================
module base_plate(){
  difference(){
    translate([0,0,GC]) cylinder(d=JBOT_D, h=WALL);
    for(sd=[-1,1]) translate([sd*WX, 0, GC-1]) cube([WHEEL_W+8, WHEEL_D+8, WALL+2], center=true); // 車輪スリット
    translate([0,0,GC-1]) cylinder(d=40, h=WALL+2);                        // 底の整備穴
    for(sd=[-1,1]) translate([sd*38, 6, GC+WALL/2]) cube([14, 10, WALL+4], center=true); // 配線チャネル
    // キャスタ長穴(ピッチ8〜24mm対応)
    for(t=[-1,1]) for(p=[-1,1])
      translate([0, t*CAST_Y, 0]) hull(){
        translate([p*4, 0, GC-3]) cylinder(d=2.7, h=WALL+6);
        translate([p*12, 0, GC-3]) cylinder(d=2.7, h=WALL+6);
      }
    for(t=[-1,1]) translate([0, t*CAST_Y, GC-3]) cylinder(d=5, h=WALL+6);
  }
}

module drive_base(){
  difference(){
    union(){
      base_plate();
      translate([0,0,GC]) ring(JBOT_D, JBOT_D-2*WALL, BH-GC);              // スカート
      translate([0,0,BH-WALL]) difference(){                                // 天面デッキ
        cylinder(d=JBOT_D, h=WALL);
        translate([0,0,-1]) cylinder(d=CABLE_D, h=WALL+2);
      }
      difference(){                                                         // 位置決めリム(ポッド部切欠)
        translate([0,0,BH-0.1]) ring(JBOT_D-2*WALL-0.8, JBOT_D-2*WALL-0.8-6, 6);
        for(sd=[-1,1]) translate([sd*WX, 0, BH+3]) cube([2*(FLG_XB-FLG_XA)/1.5, 2*FLG_YH+2, 16], center=true);
      }
      translate([0,0,GC+WALL-0.1]) ring(CABLE_D+2*WALL, CABLE_D, BH-GC-2*WALL); // 井戸の筒
      for(t=[-1,1]) translate([0, t*CAST_Y, GC-2]) cylinder(d=30, h=2.1);   // キャスタ台座
      translate([-32, 36, GC+WALL-0.1]) cube([64, 2.5, 8]);                 // LiPoバンドリブ
      translate([-32, 67, GC+WALL-0.1]) cube([64, 2.5, 8]);
    }
    // ★ポッド開口(デッキ貫通: タイヤ+隔壁が上から入る)
    for(sd=[-1,1]) translate([sd*(POD_XA+POD_XB)/2, 0, BH-WALL-1])
      cube([POD_XB-POD_XA, 2*POD_YH, WALL+3], center=true);
    // サーボ配線ノッチ(隔壁の内側でデッキを小さく欠く→井戸へ)
    for(sd=[-1,1]) translate([sd*48.5, 1, BH-WALL-1]) cube([7, 14, WALL+3], center=true);
    // ポッド固定M3下穴(φ2.6, セルフタップ)
    for(sd=[-1,1]) for(p=pod_screws())
      translate([sd*p[0], p[1], BH-WALL-2]) cylinder(d=2.6, h=WALL+4);
    // キャスタ長穴を台座まで貫通
    for(t=[-1,1]) for(p=[-1,1])
      translate([0, t*CAST_Y, 0]) hull(){
        translate([p*4, 0, GC-3]) cylinder(d=2.7, h=WALL+8);
        translate([p*12, 0, GC-3]) cylinder(d=2.7, h=WALL+8);
      }
  }
}

// ---- フィット確認クーポン(v2と同一: 隔壁嵌合+キャスタ長穴) ----
module coupon(){
  difference(){
    union(){
      cube([64, 46, 3]);
      translate([8, 40, 2.9]) cube([48, 3, 26.1]);
      for(gx=[8, 53]) translate([gx, 30, 2.9]) cube([3, 13, 12]);
      translate([18, 14, 2.9]) cylinder(d=30, h=2.1);
    }
    translate([32-(SVL/2+CLR), 39, 16-(SVW/2+CLR)]) cube([SVL+2*CLR, 5, SVW+2*CLR]);
    for(hx=[32-TABP/2, 32+TABP/2]) translate([hx, 39, 16]) rotate([-90,0,0]) cylinder(d=TABD, h=6);
    for(p=[-1,1]) translate([18,14,0]) hull(){
      translate([p*4,0,-1]) cylinder(d=2.7, h=8); translate([p*12,0,-1]) cylinder(d=2.7, h=8); }
    translate([18,14,-1]) cylinder(d=5, h=8);
  }
}

module ghosts(){
  for(sd=[-1,1]){
    %color("#90caf9") translate([sd*WX,0,AXLE_Z]) rotate([0,90,0]) cylinder(d=WHEEL_D,h=WHEEL_W,center=true);
    %color("#1976d2") translate([sd*(BF_X-WALL-SV_INB/2),0,AXLE_Z]) cube([SV_INB,SVL,SVW],center=true);
  }
  for(t=[-1,1]) %color("#9e9e9e") translate([0,t*CAST_Y,GC/2]) cylinder(d1=10,d2=18,h=GC);
  %color("red") translate([0,0,GC]) cylinder(d=CABLE_D-4, h=BH+20);
  %color("#455a64") translate([-30, 39, GC+WALL]) cube([60,28,20]);
}

SHOW=0;
if(SHOW==1)      color("#d97706") drive_base();
else if(SHOW==2) coupon();
else if(SHOW==3) drive_pod();
else { // プレビュー: ベース+ポッド左右+ゴースト
  color("#d97706") drive_base();
  color("#ef8f1f") drive_pod();
  color("#ef8f1f") rotate([0,0,180]) drive_pod();   // 左=同一部品を180°回転(ミラー不要・印刷2個)
  ghosts();
}
