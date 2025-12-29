/**
 * コロ助ロボット - 丁髷（ちょんまげ）
 * Corosuke Robot - Topknot (Chonmage)
 *
 * コロ助の特徴的な丁髷
 * - 江戸時代風のデザイン
 * - 頭頂部に取り付け
 */

// =============================================================================
// パラメータ
// =============================================================================

// 髷の基部
base_diameter = 15;
base_height = 10;

// 髷本体
topknot_length = 35;
topknot_width = 12;
topknot_height = 8;

// 髪の毛部分（下側の横に広がる部分）
hair_width = 50;
hair_depth = 30;
hair_height = 5;

// 取り付け軸
mount_diameter = 8;
mount_height = 15;

// =============================================================================
// モジュール: 丁髷の基部
// =============================================================================
module topknot_base() {
    // 髷を結ぶ部分
    cylinder(h = base_height, d1 = base_diameter + 5, d2 = base_diameter, $fn = 32);

    // 紐の表現（装飾リング）
    translate([0, 0, base_height/2])
        difference() {
            cylinder(h = 3, d = base_diameter + 2, $fn = 32);
            translate([0, 0, -1])
                cylinder(h = 5, d = base_diameter - 2, $fn = 32);
        }
}

// =============================================================================
// モジュール: 髷本体（上に伸びる部分）
// =============================================================================
module topknot_body() {
    translate([0, 0, base_height]) {
        // 髷の曲がった部分
        rotate([0, -20, 0]) {
            // 根本
            hull() {
                cylinder(h = 5, d = topknot_width, $fn = 32);
                translate([0, 0, topknot_length * 0.4])
                    rotate([0, 30, 0])
                        cylinder(h = 5, d = topknot_width - 2, $fn = 32);
            }

            // 先端（前に曲がる）
            translate([0, 0, topknot_length * 0.4])
                rotate([0, 30, 0]) {
                    hull() {
                        cylinder(h = 5, d = topknot_width - 2, $fn = 32);
                        translate([topknot_length * 0.3, 0, topknot_length * 0.3])
                            sphere(d = topknot_width - 4, $fn = 32);
                    }

                    // 髷の先端
                    translate([topknot_length * 0.3, 0, topknot_length * 0.3])
                        sphere(d = topknot_width - 2, $fn = 32);
                }
        }
    }
}

// =============================================================================
// モジュール: 横に広がる髪の毛
// =============================================================================
module side_hair() {
    // 左右に広がる髪
    translate([0, 0, -3]) {
        // 右側
        translate([5, 0, 0])
            scale([1, 0.6, 0.3])
                rotate([0, 30, 0])
                    sphere(d = hair_width * 0.6, $fn = 32);

        // 左側
        translate([-5, 0, 0])
            scale([1, 0.6, 0.3])
                rotate([0, -30, 0])
                    sphere(d = hair_width * 0.6, $fn = 32);
    }
}

// =============================================================================
// モジュール: 取り付け軸
// =============================================================================
module mount_shaft() {
    translate([0, 0, -mount_height]) {
        difference() {
            cylinder(h = mount_height, d = mount_diameter, $fn = 32);
            // ネジ穴
            cylinder(h = mount_height + 1, d = 3, $fn = 32);
        }
    }
}

// =============================================================================
// モジュール: 完全な丁髷
// =============================================================================
module complete_topknot() {
    color("black") {
        topknot_base();
        topknot_body();
        side_hair();
    }

    color("gray")
        mount_shaft();
}

// =============================================================================
// モジュール: 丁髷（簡易版 - 印刷しやすい）
// =============================================================================
module simple_topknot() {
    color("black") {
        // 基部
        cylinder(h = base_height, d = base_diameter, $fn = 32);

        // 髷本体（単純な曲がった円柱）
        translate([0, 0, base_height]) {
            // 根本部分
            cylinder(h = 15, d = topknot_width, $fn = 32);

            // 曲がった先端部分
            translate([0, -5, 15])
                rotate([-45, 0, 0])
                    cylinder(h = 20, d1 = topknot_width, d2 = topknot_width - 4, $fn = 32);

            // 先端の丸み
            translate([0, -20, 30])
                sphere(d = topknot_width - 2, $fn = 32);
        }
    }

    // 取り付け軸
    color("gray")
        mount_shaft();
}

// =============================================================================
// 出力
// =============================================================================

// 詳細版
// complete_topknot();

// 簡易版（印刷推奨）
simple_topknot();
