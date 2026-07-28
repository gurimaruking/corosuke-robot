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
 *   3 lid_v3       (天面リッド: 首穴)
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
SG_SX=58; SG_SZ=127;             // 軸(x=±58, z=127=腕穴高さ)。掃引円は壁/床とクリア
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
  cx=(SG_SX-5.55)*sg;                       // 本体中心X
  difference(){
    intersection(){                         // 壁に融着(浮き防止)
      union(){
        xbox(sg*37, sg*70, -25, 26, 106, 28);   // クレードル(z106-134, 内端x37=RDKと5mm隙間)
        xbox(sg*50, sg*80, -14, 15, 88, 42);     // 壁下ペデスタル(z88-130, 壁へ)
      }
      cylinder(h=JH, d1=JBOT_D, d2=JTOP_D); // 外壁でクリップ
    }
    xbox(cx-SG_BW/2-0.5, cx+SG_BW/2+0.5, -22, 42, SG_SZ-11.6, 44);          // 本体ポケット(幅13.64+遊び)
    translate([sg*JTOP_D/2,0,ARM_Z]) rotate([0,90,0]) cylinder(d=ARM_D,h=30,center=true); // 腕穴再くり抜き
    translate([cx-sg*14.3, -1, SG_SZ]) rotate([-90,0,0]) cylinder(d=SG_SCREW, h=12);       // 内側タブM2
  }
}

// =============================================================================
// 胴シェル v3
// =============================================================================
module shell_v3(){
  difference(){
    union(){
      // 中空テーパー壁(cone差分のみ)
      difference(){
        cylinder(h=JH, d1=JBOT_D, d2=JTOP_D);
        translate([0,0,WALL]) cylinder(h=JH, d1=JBOT_D-2*WALL, d2=JTOP_D-2*WALL);
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
    }
    // --- 開口(すべて単純な差分) ---
    translate([0,0,JH-WALL-0.5]) cylinder(h=WALL+2, d=TOP_OPEN_D);                        // 天面開口(念のため貫通)
    for(s=[-1,1]) translate([s*JTOP_D/2,0,ARM_Z]) rotate([0,90,0]) cylinder(d=ARM_D,h=26,center=true); // 腕穴
    translate([-HATCH_W/2, JBOT_D/2-14, 20]) cube([HATCH_W, 20, HATCH_H]);                // 背面ハッチ
    translate([0,-JTOP_D/2,CAM_Z]) rotate([90,0,0]) cylinder(d=CAM_WIN,h=40,center=true); // 胸カメラ レンズ窓
    for(i=[-3:3]) translate([i*8,-JBOT_D/2,SPK_Z]) rotate([90,0,0]) cylinder(d=4,h=26,center=true); // スピーカーグリル(1列)
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
module bottom_v3(){
  GH=45;                                       // 位置決めガイド高さ
  YSOLID=22;                                   // これより後ろ(y>22)は半円オープン
  difference(){
    union(){
      // 前側だけ残す(後ろ側は半円オープン=上から出し入れ・ケーブル下出し)
      intersection(){
        cylinder(d=JBOT_D-2*WALL-0.6, h=WALL);
        translate([-100,-200,0]) cube([200, 200+YSOLID, WALL]);
      }
      for(s=[-1,1]) translate([s*LEG_SP/2,0,WALL-0.1]) cylinder(d=LEG_D-2*WALL-1, h=6);   // 脚ボス
      // RDK X5 位置決めガイド(前+側面・緩め5mm・後ろは開けて両面テープ)
      translate([-CASE_D/2-CASE_CLR_XY-2, -CASE_H/2-CASE_CLR_XY-2, WALL-0.1]) cube([CASE_D+2*CASE_CLR_XY+4, 2, GH]); // 前壁
      for(s=[-1,1]) translate([s*(CASE_D/2+CASE_CLR_XY)-(s<0?2:0), -CASE_H/2-CASE_CLR_XY-2, WALL-0.1]) cube([2, CASE_H+2*CASE_CLR_XY+4, GH]); // 側壁
      // バッテリー 前+側面ガイド(緩め)
      translate([-PB_W/2-CASE_CLR_XY-2, 20-CASE_CLR_XY-2, WALL-0.1]) cube([PB_W+2*CASE_CLR_XY+4, 2, 40]);            // 前壁
      for(s=[-1,1]) translate([s*(PB_W/2+CASE_CLR_XY)-(s<0?2:0), 20-CASE_CLR_XY-2, WALL-0.1]) cube([2, YSOLID-(20-CASE_CLR_XY-2), 40]); // 側壁(短)
    }
    translate([-30,-14,-1]) cube([60,28,WALL+2]);          // RDK下ケーブル窓
    for(i=[0:2]) rotate([0,0,60+i*60]) translate([JBOT_D/2-8,0,-1]) cylinder(d=5, h=WALL+2); // 前縁通気
  }
}

// =============================================================================
// 頭側プレート(天面リッド) v3: 開口に落とし込み + 首穴 + USBケーブル穴。
//   RDK/ESP32等のUSBケーブルを頭側へ出せるよう穴を追加。
// =============================================================================
module lid_v3(){
  difference(){
    union(){
      cylinder(d=TOP_OPEN_D+2*WALL-1.2, h=2);
      translate([0,0,2]) cylinder(d=TOP_OPEN_D-1, h=2);
    }
    translate([0,0,-1]) cylinder(d=NECK_D, h=6);                               // 首穴
    for(a=[35,90,145]) rotate([0,0,a]) translate([TOP_OPEN_D/2-18,0,-1]) cylinder(d=9, h=6); // USBケーブル穴×3
    translate([-9, -TOP_OPEN_D/2+10, -1]) cube([18,7,6]);                      // 平ケーブル用スロット
    for(s=[-1,1]) translate([s*(TOP_OPEN_D/2-6),0,-1]) cylinder(d=12,h=1.6);   // 指掛かり
  }
}

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
    part("#1976d2") xbox(sg*41.1,sg*63.8,-21.5,22.5,120.95,12.1);        // SG90本体
    part("#1565c0"){ xbox(sg*44,sg*72,3,2.5,125.5,3); xbox(sg*56.5,sg*59.5,3,2.5,113,28); } // 十字ホーン
  }
}
module preview(){
  difference(){
    union(){ color("#ef8f1f") shell_v3(); color("#d97706") bottom_v3(); color("#f7dc6f") translate([0,0,JH-2]) lid_v3(); }
    if(CUT) translate([-200,-400,-10]) cube([400,400,400]);
  }
  ghosts();
}

// ============================== RENDER ==============================
SHOW=0;
if(SHOW==0)      preview();
else if(SHOW==1) shell_v3();
else if(SHOW==2) bottom_v3();
else if(SHOW==3) lid_v3();
else if(SHOW==10) { %shell_v3(); ghosts(); }   // FreeCAD確認: 部品配置(MOCKUP不要で見るなら preview)
