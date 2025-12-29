/**
 * コロ助ロボット - フルアセンブリ（色付き3MF出力用）
 * Corosuke Robot - Full Assembly for colored 3MF export
 *
 * OpenSCADから3MFエクスポート:
 * File → Export → Export as 3MF
 */

// パーツのインクルード
use <../head/skull.scad>
use <../head/face_shell.scad>
use <../head/eye_mechanism.scad>
use <../head/mouth_mechanism.scad>
use <../head/topknot.scad>
use <../body/torso_frame.scad>
use <../body/torso_shell.scad>
use <../arms/arm.scad>
use <../legs/leg.scad>
use <../accessories/sword.scad>

// =============================================================================
// 配置パラメータ
// =============================================================================
head_height = 350;       // 頭の高さ
torso_height = 200;      // 胴体の高さ
leg_height = 0;          // 脚の高さ（地面）

// =============================================================================
// フルアセンブリ
// =============================================================================
module corosuke_full_assembly() {
    // === 頭部 ===
    translate([0, 0, head_height]) {
        // 顔面シェル（ピンク）
        color("pink") face_shell();

        // 頭蓋骨フレーム（白）
        color("white", 0.5) complete_skull();

        // 丁髷（黒）
        translate([0, -10, 55])
            color("black") simple_topknot();

        // 目の機構
        translate([0, -20, 10])
            rotate([90, 0, 0])
                eye_assembly_colored();

        // 口の機構
        translate([0, -30, -25])
            rotate([90, 0, 0])
                mouth_assembly_colored();
    }

    // === 胴体 ===
    translate([0, 0, torso_height]) {
        // 胴体シェル（茶色・風呂桶）
        color("burlywood") decorated_shell();

        // 胴体フレーム
        color("lightgray", 0.3) complete_torso_frame();
    }

    // === 腕 ===
    // 右腕
    translate([60, 0, torso_height + 90])
        rotate([0, 0, -90])
            arm_assembly_colored(true);

    // 左腕
    translate([-60, 0, torso_height + 90])
        rotate([0, 0, 90])
            mirror([1, 0, 0])
                arm_assembly_colored(false);

    // === 脚 ===
    // 右脚
    translate([25, 0, leg_height])
        leg_assembly_colored(true);

    // 左脚
    translate([-25, 0, leg_height])
        mirror([1, 0, 0])
            leg_assembly_colored(false);

    // === 刀 ===
    translate([0, 25, torso_height + 60])
        rotate([15, 0, 0])
            sword_assembly_colored();
}

// =============================================================================
// 色付きサブアセンブリ
// =============================================================================

module eye_assembly_colored() {
    // 眼球（白）
    color("white") {
        translate([20, 0, 0]) sphere(d = 30, $fn = 32);
        translate([-20, 0, 0]) sphere(d = 30, $fn = 32);
    }

    // 瞳（黒）
    color("black") {
        translate([20, -12, 0]) sphere(d = 12, $fn = 32);
        translate([-20, -12, 0]) sphere(d = 12, $fn = 32);
    }

    // まぶた（ピンク）
    color("pink") {
        translate([20, 0, 8])
            scale([1.2, 0.8, 0.3])
                sphere(d = 30, $fn = 32);
        translate([-20, 0, 8])
            scale([1.2, 0.8, 0.3])
                sphere(d = 30, $fn = 32);
    }

    // 機構フレーム（グレー）
    color("gray", 0.5)
        cube([80, 40, 50], center = true);
}

module mouth_assembly_colored() {
    // 唇（ピンク・濃いめ）
    color("lightcoral") {
        // 上唇
        translate([0, 0, 5])
            scale([1, 0.3, 0.2])
                sphere(d = 40, $fn = 32);
        // 下唇
        translate([0, 0, -5])
            scale([1, 0.35, 0.25])
                sphere(d = 40, $fn = 32);
    }

    // 口の中（暗い赤）
    color("darkred")
        scale([0.8, 0.2, 0.4])
            sphere(d = 35, $fn = 32);
}

module arm_assembly_colored(is_right) {
    // 上腕（白）
    color("white")
        cylinder(h = 50, d = 25, $fn = 32);

    // 肘関節（グレー）
    color("gray")
        translate([0, 0, -5])
            sphere(d = 20, $fn = 32);

    // 前腕（白）
    color("white")
        translate([0, 0, -50])
            cylinder(h = 45, d = 22, $fn = 32);

    // 手（ピンク）
    color("pink")
        translate([0, 0, -75])
            scale([1, 0.6, 1.2])
                sphere(d = 25, $fn = 32);

    // 指（ピンク）
    color("pink")
        for (i = [-1.5 : 1 : 1.5]) {
            translate([i * 5, 0, -90])
                cylinder(h = 15, d = 6, $fn = 16);
        }
}

module leg_assembly_colored(is_right) {
    // 股関節（グレー）
    color("gray")
        translate([0, 0, 180])
            sphere(d = 30, $fn = 32);

    // 大腿部（白）
    color("white")
        translate([0, 0, 120])
            cylinder(h = 60, d = 35, $fn = 32);

    // 膝（グレー）
    color("gray")
        translate([0, 0, 115])
            sphere(d = 25, $fn = 32);

    // 下腿部（白）
    color("white")
        translate([0, 0, 60])
            cylinder(h = 55, d = 30, $fn = 32);

    // 足首（グレー）
    color("gray")
        translate([0, 0, 55])
            sphere(d = 20, $fn = 32);

    // 足（白）
    color("white")
        translate([10, 0, 10])
            scale([1.5, 1, 0.4])
                sphere(d = 50, $fn = 32);

    // 足裏（ダークグレー・TPU）
    color("dimgray")
        translate([10, 0, 2])
            scale([1.4, 0.95, 0.15])
                sphere(d = 50, $fn = 32);
}

module sword_assembly_colored() {
    rotate([0, 0, 90]) {
        // 鞘（黒）
        color("black")
            translate([0, 0, -120])
                cylinder(h = 150, d1 = 18, d2 = 20, $fn = 32);

        // 鞘の装飾（ゴールド）
        color("gold") {
            translate([0, 0, -20])
                cylinder(h = 5, d = 22, $fn = 32);
            translate([0, 0, -70])
                cylinder(h = 5, d = 22, $fn = 32);
            translate([0, 0, -110])
                cylinder(h = 5, d = 22, $fn = 32);
        }

        // 車輪（ダークグレー）
        color("dimgray")
            translate([0, 0, -135])
                rotate([90, 0, 0])
                    cylinder(h = 8, d = 25, center = true, $fn = 32);

        // 柄（茶色）
        color("saddlebrown")
            translate([0, 0, 0])
                cylinder(h = 40, d = 12, $fn = 32);

        // 鍔（ゴールド）
        color("gold")
            translate([0, 0, -5])
                cylinder(h = 5, d = 25, $fn = 32);

        // 柄頭（ゴールド）
        color("gold")
            translate([0, 0, 40])
                sphere(d = 14, $fn = 32);
    }
}

// =============================================================================
// レンダリング
// =============================================================================
corosuke_full_assembly();
