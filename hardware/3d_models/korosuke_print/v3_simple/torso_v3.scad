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
CAM_Z=100; CAM_D=12;             // 胸カメラ窓
SPK_Z=35;                        // スピーカー中心
HATCH_W=70; HATCH_H=95;          // 背面ハッチ

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
module servo_mount(sg){
  cx=(SG_SX-5.55)*sg;                       // 本体中心X
  union(){
    xbox(sg*40, sg*66, -26, 11, 0, 108);    // 支柱(脚の前・床から)
    difference(){
      xbox(sg*34, sg*68, -25, 26, 108, 26); // クレードルブロック(z108-134)
      xbox(cx-11.85, cx+11.85, -22, 42, SG_SZ-6.35, 40);                    // 本体ポケット(上/背面開放)
      translate([cx-sg*14.3, -1, SG_SZ]) rotate([-90,0,0]) cylinder(d=SG_SCREW, h=10);  // 内側タブM2
      xbox(sg*37, sg*47, -23, 22, 110, 20); // 軽量化窓
    }
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
    }
    // --- 開口(すべて単純な差分) ---
    translate([0,0,JH-WALL-0.5]) cylinder(h=WALL+2, d=TOP_OPEN_D);                        // 天面開口(念のため貫通)
    for(s=[-1,1]) translate([s*JTOP_D/2,0,ARM_Z]) rotate([0,90,0]) cylinder(d=ARM_D,h=26,center=true); // 腕穴
    translate([-HATCH_W/2, JBOT_D/2-14, 20]) cube([HATCH_W, 20, HATCH_H]);                // 背面ハッチ
    translate([0,-JTOP_D/2,CAM_Z]) rotate([90,0,0]) cylinder(d=CAM_D,h=26,center=true);   // 胸カメラ窓
    for(i=[-3:3]) translate([i*8,-JBOT_D/2,SPK_Z]) rotate([90,0,0]) cylinder(d=4,h=26,center=true); // スピーカーグリル(1列)
    // サーボ台の内側タブ用に壁は使わない(ネジは内側から)。腕穴脇のロープはARM_D穴を通す。
  }
}

// =============================================================================
// 底板 v3: 裾に圧入。ケーブル窓 + 脚ボス + サーボ支柱ノッチ + 通気。
// =============================================================================
LEG_D=36; LEG_SP=78;
module bottom_v3(){
  difference(){
    union(){
      cylinder(d=JBOT_D-2*WALL-0.6, h=WALL);
      for(s=[-1,1]) translate([s*LEG_SP/2,0,WALL-0.1]) cylinder(d=LEG_D-2*WALL-1, h=6);  // 脚ボス
    }
    translate([-30,-14,-1]) cube([60,28,WALL+2]);                    // RDK下ケーブル窓
    translate([-25,20,-1]) cube([50,26,WALL+2]);                     // バッテリー下窓
    for(sg=[-1,1]) xbox(sg*38, sg*68, -27, 13, -1, WALL+2);          // サーボ支柱ノッチ
    for(i=[0:5]) rotate([0,0,i*60]) translate([56,0,-1]) cylinder(d=8, h=WALL+2);        // 通気
  }
}

// =============================================================================
// 天面リッド v3: 開口に落とし込み + 首穴。
// =============================================================================
module lid_v3(){
  difference(){
    union(){
      cylinder(d=TOP_OPEN_D+2*WALL-1.2, h=2);
      translate([0,0,2]) cylinder(d=TOP_OPEN_D-1, h=2);
    }
    translate([0,0,-1]) cylinder(d=NECK_D, h=6);
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
