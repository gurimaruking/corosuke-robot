/*
 * コロ助 胴体 v2 / Korosuke torso v2 — 実装レイアウト再設計
 *
 * 要件(2026-07-27):
 *   1. SG90 x2 をネジ止めし、腕ロープ(蛇腹中心φ12)を引ける
 *      — ホーン回転面をロープの鉛直面に一致させる(引き方向に注意)
 *   2. RDK X5 モジュラーケース(91.4x62.4x27.1)が入る
 *   3. モバイルバッテリー置き場(縦置きトレイ、寸法パラメータ化)
 *   4. ESP32-S3 + ブレッドボードの置き場(中段デッキ)
 *   5. 胴体の上からも物を入れられる(天板廃止→φ118開口+落とし込みリッド)
 *   6. RDK X5 の USBケーブル4本(電源/通信TypeC/カメラ/ESP32)を胴体の下から出す
 *      → 底板に大型ケーブル窓
 *   7. 胸からカメラをのぞかせる(32x32 UVC基板ポケット+φ8.5窓+マイクグリル)
 *
 * 外形は korosuke_print.scad の jacket_shell と互換(H165, 裾158/上165, WALL3):
 *   背面ハッチ/ボタン穴/腕穴/スピーカーグリル位置は同一 → back_panel,
 *   collar, button, 頭部, 腕, 脚は v1 のまま使用可。
 *
 * ============ SHOW ============
 *   0 断面プレビュー(組込み想定・ゴースト付き)
 *   1 jacket_shell_v2 (胴シェル: そのまま上向き印刷・サポート不要)
 *   2 bottom_plate_v2 (底板: ケーブル窓+バッテリートレイ+脚ボス)
 *   3 mid_deck        (中段デッキ: ブレッドボード+サーボ吊り下げ)
 *   4 servo_bracket   (SG90 Lブラケット x2印刷・左右共通)
 *   5 top_lid         (天面リッド: 首穴φ46+指掛かり)
 *   6 cam_bezel       (胸カメラ化粧リング・赤)
 *   7 foot_base_v2    (フットベース: ケーブル窓+裏面後方排線溝+テープ/M3固定)
 *
 * Author: Kazuki Murata / Robostadion   License: CC BY 4.0 (design)
 * Character (C) Fujiko F. Fujio / fan-made, non-commercial tribute.
 */

// ============================== 基本寸法(v1互換) ==============================
WALL   = 3.0;
JH     = 165;            // JACKET_H
JTOP_D = 165;            // 上径
JBOT_D = 158;            // 裾径
ARM_OUT_D = 34;          // 腕蛇腹外径
ARM_HOLE_Z = JH-38;      // 腕穴高さ(=127)
LEG_D = 36; LEG_SPACING = 78;

// ---- RDK X5 モジュラーケース実測 ----
CASE_W = 91.4; CASE_D = 62.4; CASE_H = 27.1;
CASE_CLR = 1.0;

// ---- モバイルバッテリー(縦置き) — 手持ちに合わせて変更可 ----
PB_W = 62;               // 幅(X) — Anker PowerCore 10000級 + 遊び
PB_T = 24;               // 厚み(Y)
PB_H = 95;               // 高さ(Z) 参考値(トレイは上開放なので高さ自由)
PB_Y0 = 20;              // トレイ前端(ベイ後壁との隙間)

// ---- SG90 実寸(TA0132図面で裏取り済み 2026-07-27) ----
SG_L = 23.1;             // 本体長22.7+公差(窓)
SG_W = 12.5;             // 本体幅12.1+公差(窓)
SG_HOLE_PITCH = 28.6;    // 取付穴ピッチ(実測図面: 8.75+6.0+13.85)
SG_SHAFT_OFF  = 5.55;    // 軸の本体中心からのオフセット(長手方向, 22.7/2-5.8)
SG_SCREW_D = 2.2;        // タブ穴φ2.2(付属タッピングM2)

// ---- 中段デッキ ----
DECK_Z = 105;            // デッキ上面高さ(RDKケース上端95+余裕)
DECK_T = 3;
DECK_FRONT_CUT = -58;    // 前側直線カット(胸カメラと干渉回避)
BB_W = 84; BB_D = 57;    // ブレッドボード(ハーフ83x55.5)+遊び リム内寸
ROPE_X = 54;             // ロープ通し穴/サーボ軸のX位置(左右対称)
ROPE_HOLE_D = 8;

// ---- 天面開口 ----
TOP_OPEN_D = 118;        // 上から物を入れる開口
LID_D = 125;             // リッド外径(レベート126に落とし込み)
NECK_D = 46;             // 首穴(v1天板と同じ)

// ---- 胸カメラ(32x32 UVC基板) ----
CAM_Z = 100;             // レンズ中心高さ
CAM_TILT = 10;           // 上向き角
CAM_PITCH = 28;          // 基板M2穴ピッチ(Arducam IMX291=28x28 / 34x34も選択可)
CAM_LENS_D = 12;         // レンズ窓(M12レンズ先端φ10+遊び。100°FOVケラレ防止)
CAM_BOSS_H = 7;          // 基板浮かせ量(裏面部品逃げ)

// ---- スピーカー(φ50) ----
SPK_Z = 35;              // v1グリル(z26-44)の中心

$fn = $preview ? 48 : 96;

// 内半径ヘルパ(テーパー)
function r_out(z) = (JBOT_D + (JTOP_D-JBOT_D)*z/JH)/2;
function r_in(z)  = r_out(z) - WALL;

// =============================================================================
// 胴シェル v2
// =============================================================================
module shell_wall(){          // 素のテーパー壁
  difference(){
    cylinder(h=JH, d1=JBOT_D, d2=JTOP_D);
    translate([0,0,-1]) cylinder(h=JH+2, d1=JBOT_D-2*WALL, d2=JTOP_D-2*WALL);
  }
}

module top_ring(){            // 天面リング: φ118開口 + リッド落とし込みレベート
  translate([0,0,JH-WALL]) difference(){
    cylinder(h=WALL, d=JTOP_D-1);
    translate([0,0,-1]) cylinder(h=WALL+2, d=TOP_OPEN_D);          // 開口
    translate([0,0,WALL-2]) cylinder(h=2.1, d=LID_D+1.0);          // レベート(深さ2)
  }
}

module rdk_bay(){             // RDK X5 縦置きレール(v1同等, z0-100)
  intersection(){
    cylinder(h=JH, d1=JBOT_D-1, d2=JTOP_D-1);
    union(){
      for(s=[-1,1]) translate([s*(CASE_D/2+CASE_CLR+WALL/2)-WALL/2, -72, 0])
        cube([WALL, 72+CASE_H/2+CASE_CLR+WALL, 100]);
      translate([-CASE_D/2-CASE_CLR-WALL, -CASE_H/2-CASE_CLR-WALL, 0])
        cube([CASE_D+2*CASE_CLR+2*WALL, WALL, 100]);               // 前ストッパ
    }
  }
}

module pb_bay(){              // バッテリー縦置きレール(背面, 上開放)
  y1 = PB_Y0 + PB_T + 1.6;    // 後壁位置
  intersection(){
    cylinder(h=JH, d1=JBOT_D-1, d2=JTOP_D-1);
    union(){
      for(s=[-1,1]) translate([s*(PB_W/2+0.8+WALL/2)-WALL/2, PB_Y0-WALL, 0])
        cube([WALL, PB_T+1.6+2*WALL, 78]);                          // 横レール
      translate([-PB_W/2-0.8-WALL, PB_Y0-WALL, 0])
        cube([PB_W+1.6+2*WALL, WALL, 78]);                          // 前壁
      translate([-PB_W/2-0.8-WALL, y1, 0])
        cube([PB_W+1.6+2*WALL, WALL, 78]);                          // 後壁
    }
  }
}

module deck_boss(a){          // デッキ受け柱(z=0から全高→上向き印刷でサポート不要)
  rotate([0,0,a]){
    // 柱: 底から立て、上面=デッキ下面。M3下穴。底板側は同位置にノッチあり
    translate([70,0,0]) difference(){
      cylinder(d=10, h=DECK_Z-DECK_T);
      translate([0,0,DECK_Z-DECK_T-9]) cylinder(d=2.8, h=10);
    }
    // 壁への連結リブ(全高。外へのはみ出しはシェル外形でクリップ)
    intersection(){
      translate([72,-3,0]) cube([9, 6, DECK_Z-DECK_T]);
      rotate([0,0,-a]) difference(){
        cylinder(h=JH, d1=JBOT_D-1, d2=JTOP_D-1);
        translate([0,0,-1]) cylinder(h=JH+2, d=20);  // 中心側はどうせ届かないがCGAL安定用
      }
    }
  }
}

module cam_pocket_bosses(){   // 胸カメラ基板ボス(M2 x4, 10°上向き)
  translate([0, -r_in(CAM_Z)+2, CAM_Z]) rotate([90+CAM_TILT,0,0])
    for(sx=[-1,1], sz=[-1,1]) translate([sx*CAM_PITCH/2, sz*CAM_PITCH/2, -2])
      difference(){
        cylinder(d=5.5, h=CAM_BOSS_H+2);
        translate([0,0,2]) cylinder(d=1.7, h=CAM_BOSS_H+1);         // M2セルフタップ
      }
}

module spk_seat(){            // φ50スピーカー座(グリル裏, リング+結束穴)
  translate([0, -r_in(SPK_Z)+1, SPK_Z]) rotate([90,0,0]) difference(){
    cylinder(d=58, h=5);
    translate([0,0,-1]) cylinder(d=50.6, h=7);                      // スピーカー落とし込み
    for(s=[-1,1]) translate([s*27,0,2.5]) rotate([90,0,0]) cylinder(d=3.2, h=12, center=true); // 結束バンド
  }
}

module jacket_shell_v2(){
  difference(){
    union(){
      shell_wall();
      top_ring();
      rdk_bay();
      pb_bay();
      for(a=[45,135,225,315]) deck_boss(a);
      cam_pocket_bosses();
      spk_seat();
    }
    // ---- v1互換の開口 ----
    translate([-35, JBOT_D/2-14, 22]) cube([70, 20, 100]);          // 背面ハッチ
    for(i=[-2:2], j=[0:2]) translate([i*9, -JBOT_D/2+((abs(i)+j)%9)-2, 26+j*9])
      rotate([90,0,0]) cylinder(d=4, h=16);                          // スピーカーグリル
    for(sx=[-1,1]) translate([sx*30, -JBOT_D/2+2, JH*0.46])
      rotate([90,0,0]) cylinder(d=6.5, h=WALL+6);                    // ボタン穴
    for(s=[-1,1]) translate([s*(JTOP_D/2-2), 0, ARM_HOLE_Z])
      rotate([0,90,0]) cylinder(d=ARM_OUT_D+2, h=20, center=true);   // 腕穴
    // ---- v2 追加開口 ----
    // 胸カメラ: レンズ窓(10°上向き, 内側すり鉢=広角ケラレ防止) + マイクグリル3穴
    translate([0, -r_in(CAM_Z)+2, CAM_Z]) rotate([90+CAM_TILT,0,0]){
      translate([0,0,-WALL-6]) cylinder(d=CAM_LENS_D, h=WALL+10);
      translate([0,0,-1.2]) cylinder(d1=CAM_LENS_D, d2=CAM_LENS_D+9, h=6); // すり鉢
    }
    for(i=[-1:1]) translate([20, -JBOT_D/2+2, CAM_Z-3+i*5])
      rotate([90,0,0]) cylinder(d=2.2, h=WALL+8);                    // マイク穴
  }
}

// =============================================================================
// 底板 v2: 裾に圧入。RDKケーブル窓 + バッテリー窓 + 脚ボス + 通気
//   RDK X5 のUSB(電源/通信TypeC/カメラ/ESP32)はこの窓から下へ出し、
//   脚の間(高さ約70mm)を通して背面へ逃がす。
// =============================================================================
module bottom_plate_v2(){
  difference(){
    union(){
      cylinder(d=JBOT_D-2*WALL-0.6, h=WALL);
      for(s=[-1,1]) translate([s*LEG_SPACING/2,0,WALL-0.1])
        cylinder(d=LEG_D-2*WALL-1, h=6);                             // 脚ボス
      // バッテリー底ズレ止め(窓のフチ)
      translate([-PB_W/2-2, PB_Y0-2, WALL-0.1]) cube([PB_W+4, 2, 4]);
      translate([-PB_W/2-2, PB_Y0+PB_T+1.6, WALL-0.1]) cube([PB_W+4, 2, 4]);
    }
    // RDKベイ直下のケーブル窓(56x24 — 両側4mmずつ受け残し)
    translate([-28, -CASE_H/2-CASE_CLR+1, -1]) cube([56, 24, WALL+2]);
    // バッテリー直下の窓(出力ポート下向きでもOKに) + ベルクロスロット
    translate([-20, PB_Y0+4, -1]) cube([40, PB_T-6, WALL+2]);
    for(s=[-1,1]) translate([s*(PB_W/2+5)-2, PB_Y0+PB_T/2-8, -1]) cube([4, 16, WALL+2]);
    // 背面ケーブル逃げ(通信TypeC等を外へ)
    translate([-15, 52, -1]) cube([30, 14, WALL+2]);
    // 通気
    for(i=[0:5]) rotate([0,0,i*60]) translate([58,0,-1]) cylinder(d=8, h=WALL+2);
    // フットベース固定用M3 x4(タップ止め or 貫通。両面テープ運用なら未使用でOK)
    for(a=[30,150,210,330]) rotate([0,0,a]) translate([66,0,-1]) cylinder(d=3.2, h=WALL+2);
    // デッキ柱ノッチ x4(シェル側の全高柱+リブを避ける)
    for(a=[45,135,225,315]) rotate([0,0,a]){
      translate([70,0,-1]) cylinder(d=11.5, h=WALL+2);
      translate([69,-3.6,-1]) cube([9, 7.2, WALL+2]);
    }
  }
}

// =============================================================================
// フットベース v2: 胴の裾を両面テープ(または M3x4)で載せる台座。
//   ★底板のケーブル窓と同位置に貫通窓 → さらに裏面の「排線溝」(深さ5)で
//     ベタ置きのまま背面へケーブルを逃がす(電源/通信TypeC/カメラ/ESP32)。
//   実機は現在アクリル両面テープ固定 → テープゾーン=窓を避けた前後の平面。
// =============================================================================
FB_D = 178;              // ベース外径(裾158+のりしろ)
FB_T = 9;                // 厚み(排線溝5を掘っても上面4残る)
FB_CH_W = 26;            // 裏面排線溝の幅
module foot_base_v2(){
  difference(){
    union(){
      cylinder(d=FB_D, h=FB_T);
      // 裾ズレ止めリング(内側に胴裾JBOT_Dが載る位置決め土手)
      difference(){
        cylinder(d=JBOT_D+2*WALL+2, h=FB_T+2.5);
        translate([0,0,FB_T-0.1]) cylinder(d=JBOT_D+0.8, h=4);
      }
    }
    // --- 底板と同位置の貫通窓 ---
    translate([-28, -CASE_H/2-CASE_CLR+1, -1]) cube([56, 24, FB_T+5]);   // RDK USB窓
    translate([-20, PB_Y0+4, -1]) cube([40, PB_T-6, FB_T+5]);            // バッテリー窓
    translate([-15, 52, -1]) cube([30, 14, FB_T+5]);                     // 背面スロット
    // --- 裏面排線溝: RDK窓→背面エッジまで一直線(ベタ置きで後方へ排線) ---
    translate([-FB_CH_W/2, -CASE_H/2-CASE_CLR+1, -1]) cube([FB_CH_W, FB_D/2+2, 6]);
    // --- 胴底板とのM3共締め穴(皿もみ) ---
    for(a=[30,150,210,330]) rotate([0,0,a]) translate([66,0,0]){
      translate([0,0,-1]) cylinder(d=3.4, h=FB_T+4);
      translate([0,0,-0.1]) cylinder(d1=6.5, d2=3.4, h=2.2);             // 皿(裏面から)
    }
    // 軽量化/通気
    for(a=[0,60,120,180,240,300]) rotate([0,0,a]) translate([50,0,-1]) cylinder(d=10, h=FB_T+5);
  }
}

// =============================================================================
// 中段デッキ(z=105): ブレッドボード+ESP32-S3 置き場。
//   左右ウィングの下に SG90 ブラケットを吊り、φ8穴がロープガイドを兼ねる。
//   4隅ボスへ M3x4。上の開口から手が届く(=上から物を入れる棚でもある)。
// =============================================================================
module mid_deck(){
  difference(){
    union(){
      // 本体(前側直線カットで胸カメラと干渉回避)
      linear_extrude(DECK_T) intersection(){
        circle(r=r_in(DECK_Z)-2.5);
        translate([-100, DECK_FRONT_CUT]) square([200, 200]);
      }
      // ブレッドボード枠(リム2mm)
      translate([0,-6,DECK_T]) difference(){
        rrect(BB_W+2.4+4, BB_D+2.4+4, 2, 5);
        rrect(BB_W+2.4, BB_D+2.4, 2.1, 4);
      }
    }
    // 4隅 M3通し穴(deck_boss位置 r=70, 45°刻み)
    for(a=[45,135,225,315]) rotate([0,0,a]) translate([70,0,-1]) cylinder(d=3.4, h=DECK_T+2);
    // ロープ穴(=ガイド) + サーボブラケット取付M3
    for(s=[-1,1]){
      translate([s*ROPE_X, 0, -1]) cylinder(d=ROPE_HOLE_D, h=DECK_T+2);
      for(t=[-1,1]) translate([s*ROPE_X, t*10, -1]) cylinder(d=3.4, h=DECK_T+2);
    }
    // 背面ケーブル落とし(ESP32のUSB→RDKへ / サーボ線)
    translate([-16, 40, -1]) cube([32, 14, DECK_T+2]);
    // 結束バンドスロット(LiPo/アンプ基板等の固定用)
    for(s=[-1,1], y=[-30, 26]) translate([s*40-2, y, -1]) cube([4, 10, DECK_T+2]);
  }
}
module rrect(w,d,h,r){ translate([-w/2,-d/2,0]) linear_extrude(h) offset(r=r) offset(r=-r) square([w,d]); }

// =============================================================================
// SG90 Lブラケット(左右共通・2個印刷): デッキ下面へ M3x2 で吊る。
//   サーボ軸=Y向き(前後) → ホーンはX-Z(鉛直)面を回る。
//   ホーン先端を上(12時)にするとロープ穴直下 → 内側下方へ回すとロープを引く。
//   ★向きの注意: ロープは腕穴(x=±77.5, z=127)→デッキφ8穴(x=±54)→ホーン先端。
//     左は時計回り/右は反時計回り(内側へ)が「引き」。ESP32側で回転方向を反転。
// =============================================================================
module servo_bracket(){
  flange_w = 34;   // フランジY方向
  flange_l = 26;   // フランジX方向
  plate_w  = 44;   // 垂直板X幅(窓23.1+両ネジ28.6を余白込みで収める)
  plate_x0 = -14;  // 垂直板左端(窓が+X側へ5.55ずれるため右寄せ非対称)
  plate_h  = 32;   // 垂直板高さ
  difference(){
    union(){
      translate([-flange_l/2, -flange_w/2, 0]) cube([flange_l, flange_w, 4]);       // 上フランジ
      translate([plate_x0, -flange_w/2, -plate_h]) cube([plate_w, 3, plate_h]);     // 垂直板(前面)
      // 三角リブx2(フランジ⇔板)
      for(s=[-1,1]) translate([s*(flange_l/2-2.5)-1.5, -flange_w/2+3, -14])
        rotate([90,0,90]) linear_extrude(3) polygon([[0,0],[12,14],[0,14]]);
    }
    // フランジ: M3通し x2(デッキ穴t=±10と一致) + ロープ穴φ8
    for(t=[-1,1]) translate([0, t*10, -1]) cylinder(d=3.2, h=6);
    translate([0,0,-1]) cylinder(d=ROPE_HOLE_D, h=6);
    // 垂直板: SG90窓(窓中心=+SHAFT_OFF → 軸オフセット分を相殺し
    //   出力軸がロープ穴(x=0)の真下に来る。軸側の端を-X向きに挿入)
    translate([SG_SHAFT_OFF, -flange_w/2-1, -plate_h+4]) hull(){
      translate([-SG_L/2+SG_W/2, 0, SG_W/2]) rotate([-90,0,0]) cylinder(d=SG_W, h=5);
      translate([ SG_L/2-SG_W/2, 0, SG_W/2]) rotate([-90,0,0]) cylinder(d=SG_W, h=5);
    }
    // SG90取付ネジ(タブ穴φ2.2ピッチ28.6, 付属タッピングM2)
    for(s=[-1,1]) translate([SG_SHAFT_OFF+s*SG_HOLE_PITCH/2, -flange_w/2-1, -plate_h+4+SG_W/2])
      rotate([-90,0,0]) cylinder(d=SG_SCREW_D, h=6);
  }
}

// =============================================================================
// 天面リッド: レベートに落とし込み。首穴φ46 + 指掛かり2箇所。
//   頭(首)ごと持ち上げれば上から胴内(デッキ)に物を出し入れできる。
// =============================================================================
module top_lid(){
  difference(){
    union(){
      cylinder(d=LID_D, h=2);                       // レベートに沈む段
      translate([0,0,2]) cylinder(d=TOP_OPEN_D-1, h=2);  // 下側スカート(ズレ止め)
    }
    translate([0,0,-1]) cylinder(d=NECK_D, h=6);    // 首穴(ケーブル+首固定)
    for(s=[-1,1]) translate([s*(LID_D/2-9), 0, -1]) cylinder(d=12, h=1.6);  // 指掛かり(裏から)
  }
}

// =============================================================================
// 胸カメラ化粧リング(赤): レンズ窓φ8.5に外から嵌める
// =============================================================================
module cam_bezel(){
  difference(){
    union(){ cylinder(d=20, h=2.5); translate([0,0,-WALL]) cylinder(d=11.8, h=WALL+0.1); }
    translate([0,0,-WALL-1]) cylinder(d=10.2, h=WALL+5);   // M12レンズ先端が通る
  }
}

// =============================================================================
// プレビュー(断面 + ゴースト)
// =============================================================================
module ghosts(){
  %translate([-CASE_D/2, -CASE_H/2, WALL]) cube([CASE_D, CASE_H, CASE_W]);          // RDK X5ケース
  %translate([-PB_W/2, PB_Y0+0.8, WALL]) cube([PB_W, PB_T, PB_H]);                  // モバイルバッテリー
  %translate([-83/2, -6-55.5/2, DECK_Z]) cube([83, 55.5, 10]);                      // ブレッドボード
  for(s=[-1,1]) %translate([s*ROPE_X-6, -12, DECK_Z-DECK_T-32]) cube([12, 24, 28]); // SG90ゾーン
}
module assembly_v2(){
  difference(){
    union(){
      color("#ef8f1f") jacket_shell_v2();
      color("#d97706") translate([0,0,0.01]) bottom_plate_v2();
      color("#8d6e63") translate([0,0,DECK_Z-DECK_T]) mid_deck();
      for(s=[-1,1]) color("#607d8b") translate([s*ROPE_X, 0, DECK_Z-DECK_T]) rotate([0,0,s==1?0:180]) servo_bracket();
      color("#f7dc6f") translate([0,0,JH-2]) top_lid();
    }
    // 断面カット(プレビューを見やすく)
    if($preview) translate([-200,-400,-10]) cube([400,400,400]);
  }
  ghosts();
}

// ============================== RENDER SWITCH ==============================
SHOW = 0;
if(SHOW==0)      assembly_v2();
else if(SHOW==1) jacket_shell_v2();
else if(SHOW==2) bottom_plate_v2();
else if(SHOW==3) translate([0,0,DECK_T]) mid_deck();
else if(SHOW==4) translate([0,0,17]) rotate([90,0,0]) servo_bracket();  // x2印刷(左右共通)・垂直板をベッドに寝かせた印刷向き
else if(SHOW==5) top_lid();
else if(SHOW==6) rotate([180,0,0]) translate([0,0,-2.5]) cam_bezel();
else if(SHOW==7) foot_base_v2();
