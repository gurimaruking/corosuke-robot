/*
 * コロ助 φ158 ホロノミック・ベース 成立性検討 (feasibility mockup) / 2026-07-29
 *
 * 目的: 3×オムニ輪(48mm) + FEETECHバスサーボ を 120°配置で φ158 に収めつつ、
 *       胴底中央から出る RDK X5 の USBケーブル(想定 φ90 出口)を塞がないか検証する。
 *
 * 結論(数値): STS3215(45mm)は φ158 に収めると中央クリアが φ34 まで潰れ φ90 と衝突。
 *             STS3032(23mm・小型バスサーボ)なら中央 φ78 を確保でき、ほぼ両立する。
 *   -D SERVO=\"STS3032\" で小型サーボ版に切替。
 */
$fn = 96;
JBOT_D = 158;   // 胴裾径 = ベース外径
WALL   = 3;
SERVO  = "STS3215";                 // or "STS3032"
// [W(接線X), L(放射Y), H(Z)]
SG   = (SERVO=="STS3032") ? [12,23,27.5] : [24.7,45.2,35];
OMNI_D = 48;  OMNI_W = 20;           // オムニ輪 径/幅
RW     = (SERVO=="STS3032") ? 62 : 62;  // 車輪軸の半径位置
CABLE_D = 90;                        // 出したいケーブル出口(=現行 bottom_v3 の中央穴)

clear_r = RW - SG[1];                // 中央クリア半径(サーボ内端)
echo(str("SERVO=", SERVO, "  中央クリア=φ", 2*clear_r, "  車輪外縁R=", RW+OMNI_W/2));

module base(){
  color("#d97706") linear_extrude(WALL)
    difference(){ circle(d=JBOT_D); circle(d=JBOT_D-2*WALL); }
}
module drive_module(){
  // オムニ輪: 軸=放射(Y)方向、円板はX-Z面、下(-Z)へ接地
  color("#90caf9") translate([0,RW,OMNI_D/2]) rotate([90,0,0]) cylinder(d=OMNI_D,h=OMNI_W,center=true);
  // サーボ本体: 車輪から中心へ放射状に伸びる
  color("#37474f") translate([0, RW-SG[1]/2, SG[2]/2]) cube([SG[0],SG[1],SG[2]], center=true);
}

base();
for(a=[0,120,240]) rotate([0,0,a]) drive_module();

// 出したいケーブル柱(φ90) = 赤ゴースト。サーボと重なる=干渉。
%color("red")   translate([0,0,-2]) cylinder(d=CABLE_D,     h=60);
// 実際に確保できる中央クリア = 緑
%color("green") translate([0,0,-4]) cylinder(d=2*clear_r,   h=2);

// ケーブル逃がしレーン(サーボ間の120°ギャップ, +Y と 60°の中間=角度=60°方向) を明示
color("#c8e6c9") rotate([0,0,60]) translate([-14, clear_r, WALL/2]) cube([28, JBOT_D/2-clear_r, 1]);
