/*
 * コロ助 胴体 v3 (simple) — 作り直したシンプル版 / 2026-07-28
 *
 * 方針: 部品4種だけ。mirror()/offset()/円錐との交差 を一切使わない
 *        → FreeCADでCSGがそのまま開ける。印刷もサポート不要。
 *
 * 要件(維持): RDK X5が入る / モバイルバッテリー置場 / SG90×2でロープ牽引(十字ホーン) /
 *             上から物を入れる / ケーブル下出し / スピーカーφ50 / 胸カメラ。
 *   ※ESP32-S3+ブレッドボードは頭部へ。RDK/バッテリーはベルクロ固定(レール等の複雑物は廃止)。
 *
 * ============ SHOW ============
 *   0 プレビュー(部品ゴースト付き, -D CUT=true で断面)
 *   1 shell_v3     (胴シェル+サーボ台一体)
 *   2 bottom_v3    (底板: ケーブル窓+脚ボス+支柱ノッチ)
 *   (3 lid は廃止)
 *   ※サーボ台はシェル一体なので別パーツなし
 *
 * Author: Kazuki Murata / Robostadion   License: CC BY 4.0 (design)
 * Character (C) Fujiko F. Fujio / fan-made, non-commercial tribute.
 */

// ---- 基本寸法 ----
WALL   = 3;
JH     = 165;              // 高さ
JBOT_D = 158;             // 裾径
JTOP_D = 165;             // 上径
$fn = 64;

// ---- 搭載部品(実測) ----
CASE_W=91.4; CASE_D=62.4; CASE_H=27.1; CASE_VCLR=5;   // RDK X5ケース(縦置き, 上下+5mm)
PB_W=62; PB_T=24; PB_H=95;                            // モバイルバッテリー(可変)
SPK_D=50; SPK_T=18.5;                                  // スピーカー(秋月WYGD50D-8)

// ---- 開口・特徴 ----
TOP_OPEN_D=120;  NECK_D=46;      // 天面開口 / 首穴
ARM_Z=127; ARM_D=36;             // 腕穴(高さ/径)
SPK_Z=35;                        // スピーカー中心
HATCH_W=70; HATCH_H=95;          // 背面ハッチ
// ---- 胸カメラ HBV-W202012HD (OV9726 1MP, 50°, USB) ----
CAM_BW=30; CAM_BH=25; CAM_BT=14; // 基板 W×H×厚(実測公称)
CAM_Z=118;                       // 前面・上側(腕穴の少し下)
CAM_WIN=9;                       // レンズ窓(ツイストレンズ径+遊び)
// ---- RDK/バッテリー 位置決め(緩め: 5mm隙間・両面テープ固定前提) ----
CASE_CLR_XY=5;

// ---- SG90 (十字ホーン: 軸まわり半径≈16で掃引) ----
SG_SX=56; SG_SZ=127;             // 軸(x=±56, z=127)。実物ホーン半径18でも内壁と≈4mmクリア(freecadcmd検証済)
SG_SCREW=2.2;

function rin(z)=(JBOT_D+(JTOP_D-JBOT_D)*z/JH)/2-WALL;   // 内半径(テーパー)
// X範囲[xa,xb]の箱(符号反転OK=mirror不要)
module xbox(xa,xb,y,dy,z,dz){ translate([min(xa,xb),y,z]) cube([abs(xb-xa),dy,dz]); }

// =============================================================================
// サーボ台(左右, sg=+1/-1): 支柱(床→z108)+クレードル(z108-134)。すべて壁内に収まり
//   円錐との交差不要。十字ホーンは軸(±58,127)の後ろ(y≈3)で回りクレードルと不干渉。
//   支柱は脚ボス(x±39)の前(y[-26,-15])に立て脚と干渉しない。
// =============================================================================
// 実物SG90(13.64幅 x 22.7長 x 22.5高, 軸は端から5.8)。台は壁に融着=浮かない。
//   ※intersection(cone)を使うがFreeCADは.FCStd/STLで見るので問題なし。印刷もOK。
SG_BW=13.64; SG_BL=22.7;
module servo_mount(sg){
  cx=SG_SX*sg;                              // 軸=本体中心X
  difference(){
    intersection(){                         // 壁に融着(浮き防止)
      union(){
        xbox(sg*40, sg*72, -28, 30, 108, 34);   // クレードル(z108-142, y[-28,2], 内端x40=RDKと5mm+)
        xbox(sg*52, sg*80, -14, 15, 88, 42);     // 壁下ペデスタル(z88-130, 壁へ)
      }
      cylinder(h=JH, d1=JBOT_D, d2=JTOP_D); // 外壁でクリップ
    }
    // 本体ポケット(前・上開放。実寸13.64幅・本体は前(-Y)へ。z110-150で本体全高を収容=床と非干渉)
    //   ※SG90タブはホーン側でネジ止め不可 → ポケット捕捉+リッドで上から押さえる方式
    xbox(cx-SG_BW/2-0.6, cx+SG_BW/2+0.6, -29, 33, 110, 40);
    // ★十字ホーン旋回クリア(軸まわり半径19.5をy≧-2で除去=ホーンがクレードルに当たらない)
    translate([cx, 10, SG_SZ]) rotate([90,0,0]) cylinder(d=39, h=12);
    translate([sg*JTOP_D/2,0,ARM_Z]) rotate([0,90,0]) cylinder(d=ARM_D,h=30,center=true); // 腕穴再くり抜き
  }
}

// =============================================================================
// 胴シェル v3
// =============================================================================
module shell_v3(){
  difference(){
    union(){
      // 中空テーパー壁(上下とも貫通=底面も開放。Baseを裾に嵌める)
      difference(){
        cylinder(h=JH, d1=JBOT_D, d2=JTOP_D);
        translate([0,0,-1]) cylinder(h=JH+2, d1=JBOT_D-2*WALL-0.1, d2=JTOP_D-2*WALL+0.1);
      }
      // 天面リング(開口φ120 + リッド落とし込み段)
      translate([0,0,JH-WALL]) difference(){
        cylinder(h=WALL, d=JTOP_D-1);
        translate([0,0,-1]) cylinder(h=WALL+2, d=TOP_OPEN_D);
        translate([0,0,WALL-2]) cylinder(h=2.1, d=TOP_OPEN_D+2*WALL);
      }
      // サーボ台 ×2(壁内・一体)
      for(sg=[-1,1]) servo_mount(sg);
      cam_mount();                          // 前面上側 カメラ台
      case_cage();                          // RDK/バッテリー 固定(全て胴体側・両面テープ)
    }
    // --- 開口(すべて単純な差分) ---
    translate([0,0,JH-WALL-0.5]) cylinder(h=WALL+2, d=TOP_OPEN_D);                        // 天面開口(念のため貫通)
    for(s=[-1,1]) translate([s*JTOP_D/2,0,ARM_Z]) rotate([0,90,0]) cylinder(d=ARM_D,h=26,center=true); // 腕穴
    translate([-HATCH_W/2, JBOT_D/2-14, 20]) cube([HATCH_W, 20, HATCH_H]);                // 背面ハッチ
    translate([0,-JTOP_D/2,CAM_Z]) rotate([90,0,0]) cylinder(d=CAM_WIN,h=40,center=true); // 胸カメラ レンズ窓
    for(i=[-3:3]) translate([i*8,-JBOT_D/2,SPK_Z]) rotate([90,0,0]) cylinder(d=4,h=26,center=true); // スピーカーグリル(1列)
    // case_cage の仕切りにケーブル穴(前後方向に配線を通す)
    for(y=[-CASE_H/2-CASE_CLR_XY-4, CASE_H/2+CASE_CLR_XY-4]) translate([-15, y, 22]) cube([30, 12, 34]);
  }
}

// RDK/バッテリーを胴体側に固定する内部フレーム(緩め・両面テープ。両端を壁へ融着)。
//   前ストッパ(RDK前) / 仕切り(RDK後=電池前) / 後ストッパ(電池後) の3枚。全高低め。
module case_cage(){
  intersection(){
    union(){
      translate([-80, -CASE_H/2-CASE_CLR_XY-2, WALL]) cube([160, 3, 55]);        // RDK前ストッパ
      translate([-80,  CASE_H/2+CASE_CLR_XY-1, WALL]) cube([160, 3, 60]);        // 仕切り(RDK後/電池前)
      translate([-80,  20+PB_T+CASE_CLR_XY-1, WALL]) cube([160, 3, 50]);         // 電池後ストッパ
    }
    cylinder(h=JH, d1=JBOT_D, d2=JTOP_D);   // 壁でクリップ=両端を壁へ融着
  }
}

// 胸カメラ台(前面内壁・上側): 30x25x14基板を上から落とし込み、レンズは窓へ。
module cam_mount(){
  yb = -(JBOT_D + (JTOP_D-JBOT_D)*CAM_Z/JH)/2 + WALL;      // 前壁内面Y
  translate([0, yb, CAM_Z]) difference(){
    translate([-CAM_BW/2-2.5, 0, -CAM_BH/2-2.5]) cube([CAM_BW+5, CAM_BT+3, CAM_BH+5]);       // 外形
    translate([-CAM_BW/2-0.4, -1, -CAM_BH/2-0.4]) cube([CAM_BW+0.8, CAM_BT+1.5, CAM_BH+22]); // 基板ポケット(上開放)
    translate([0, -1, 0]) rotate([-90,0,0]) cylinder(d=CAM_WIN+3, h=CAM_BT+5);               // レンズ/配線逃げ
  }
}

// =============================================================================
// 足側プレート(底板) v3: 上から出し入れしやすい「開放トレイ」。
//   大きな中央開口(RDK/バッテリーを裾から差し込み・ケーブルを下へ)＋外周に載せ代の縁。
//   脚ボス＋サーボ支柱ノッチ＋通気。裾に圧入。
// =============================================================================
LEG_D=36; LEG_SP=78;
// Base v3: Shellを載せる丸板。中心に大きな円(ケーブル出し) + 脚をのせる場所。
//   丸板(φ158, 胴裾が載る) + 位置決めリム(裾内側) + 中心の大穴 + それを跨ぐ脚バー(脚ボス)。
BASE_HOLE_D=90;                                   // 中心の大きな円
module bottom_v3(){
  Rin = JBOT_D/2-WALL-0.4;
  difference(){
    union(){
      cylinder(d=JBOT_D, h=WALL);                              // 丸板(胴裾が載る φ158)
      translate([0,0,WALL-0.1]) difference(){                  // 位置決めリム(裾内側へ立つ)
        cylinder(d=2*Rin, h=6); translate([0,0,-1]) cylinder(d=2*Rin-2*3, h=8);
      }
      translate([-JBOT_D/2, -11, 0]) cube([JBOT_D, 22, WALL]); // 脚バー(中心穴を跨ぎ脚をのせる)
      for(s=[-1,1]) translate([s*LEG_SP/2,0,WALL-0.1]) cylinder(d=LEG_D-2*WALL-1, h=8);  // 脚ボス(=足をのせる場所)
    }
    // 中心の大きな円(ケーブル出し) — 脚バー(y[-11,11])は残す
    difference(){
      translate([0,0,-1]) cylinder(d=BASE_HOLE_D, h=WALL+2);
      translate([-JBOT_D/2, -11, -2]) cube([JBOT_D, 22, WALL+4]);
    }
    for(s=[-1,1]) translate([s*LEG_SP/2,0,-1]) cylinder(d=2.8, h=WALL+12);  // 脚固定ネジ下穴(M3タップ)
    translate([-26,-11,-1]) cube([52,22,WALL+2]);                          // バー中央にもケーブル穴
  }
}

// (Lidは廃止 — 天面は開口のまま。頭/首は襟リングで受ける)

// =============================================================================
// プレビュー(部品ゴースト)
// =============================================================================
CUT=false; MOCKUP=false;
module part(col) if(MOCKUP) color(col) children(); else %children();
module ghosts(){
  part("#4caf50") translate([-CASE_D/2,-CASE_H/2,WALL+CASE_VCLR]) cube([CASE_D,CASE_H,CASE_W]); // RDK
  part("#455a64") translate([-PB_W/2,20,WALL]) cube([PB_W,PB_T,PB_H]);                          // battery
  part("#e0e0e0") translate([0,-rin(SPK_Z)+1,SPK_Z]) rotate([90,0,0]) cylinder(d=SPK_D,h=SPK_T);// speaker
  part("#333333") translate([-CAM_BW/2, -rin(CAM_Z), CAM_Z-CAM_BH/2]) cube([CAM_BW,CAM_BT,CAM_BH]); // camera基板
  for(sg=[-1,1]){
    part("#1976d2") xbox(sg*49.2, sg*62.8, -25, 30.4, 110.8, 32.4);      // SG90本体(実寸)
    part("#1565c0") translate([sg*SG_SX,3,SG_SZ]) rotate([90,0,0]) cylinder(d=37,h=4); // 十字ホーン旋回envelope(半径18)
  }
}
module preview(){
  difference(){
    union(){ color("#ef8f1f") shell_v3(); color("#d97706") bottom_v3(); }
    if(CUT) translate([-200,-400,-10]) cube([400,400,400]);
  }
  ghosts();
}

// ============================== RENDER ==============================
SHOW=0;
if(SHOW==0)      preview();
else if(SHOW==1) shell_v3();
else if(SHOW==2) bottom_v3();
// (SHOW==3 lid は廃止)
else if(SHOW==10) { %shell_v3(); ghosts(); }   // FreeCAD確認: 部品配置(MOCKUP不要で見るなら preview)
