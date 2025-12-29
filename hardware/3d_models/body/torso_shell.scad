/**
 * コロ助ロボット - 胴体シェル（外装）
 * Corosuke Robot - Torso Shell
 *
 * コロ助の胴体外装（風呂桶デザイン）
 * - 木目調の板を模したデザイン
 * - 取り外し可能な前面パネル
 */

// =============================================================================
// パラメータ
// =============================================================================

// 胴体サイズ
torso_top_diameter = 105;
torso_bottom_diameter = 85;
torso_height = 125;
shell_thickness = 3;

// 木の板のデザイン
plank_count = 12;          // 板の枚数
plank_gap = 1;             // 板の隙間
band_width = 8;            // たがの幅
band_count = 3;            // たがの数

// 前面開口
front_panel_width = 60;
front_panel_height = 80;

// =============================================================================
// モジュール: 基本シェル
// =============================================================================
module shell_base() {
    difference() {
        // 外側
        cylinder(h = torso_height,
                 d1 = torso_bottom_diameter,
                 d2 = torso_top_diameter,
                 $fn = 64);

        // 内側
        translate([0, 0, -1])
            cylinder(h = torso_height + 2,
                     d1 = torso_bottom_diameter - shell_thickness * 2,
                     d2 = torso_top_diameter - shell_thickness * 2,
                     $fn = 64);
    }
}

// =============================================================================
// モジュール: 木の板模様
// =============================================================================
module plank_pattern() {
    for (i = [0:plank_count-1]) {
        angle = i * 360 / plank_count;

        rotate([0, 0, angle])
            translate([0, 0, torso_height/2])
                rotate([0, 0, 360/plank_count/2])
                    linear_extrude(height = torso_height, center = true, scale = torso_top_diameter/torso_bottom_diameter)
                        polygon([
                            [0, 0],
                            [torso_bottom_diameter/2 * cos(360/plank_count/2 - plank_gap),
                             torso_bottom_diameter/2 * sin(360/plank_count/2 - plank_gap)],
                            [torso_bottom_diameter/2 * cos(-360/plank_count/2 + plank_gap),
                             torso_bottom_diameter/2 * sin(-360/plank_count/2 + plank_gap)]
                        ]);
    }
}

// =============================================================================
// モジュール: たが（バンド）
// =============================================================================
module bands() {
    band_positions = [15, torso_height/2, torso_height - 15];

    for (z = band_positions) {
        translate([0, 0, z]) {
            diam = torso_bottom_diameter + (torso_top_diameter - torso_bottom_diameter) * z / torso_height;
            difference() {
                cylinder(h = band_width, d = diam + 2, center = true, $fn = 64);
                cylinder(h = band_width + 1, d = diam - 4, center = true, $fn = 64);
            }
        }
    }
}

// =============================================================================
// モジュール: 前面パネル開口
// =============================================================================
module front_panel_opening() {
    translate([0, -torso_top_diameter/2, torso_height/2])
        rotate([90, 0, 0])
            resize([front_panel_width, front_panel_height, shell_thickness * 3])
                cylinder(h = shell_thickness * 3, d = 50, $fn = 64);
}

// =============================================================================
// モジュール: 前面パネル
// =============================================================================
module front_panel() {
    difference() {
        // パネル本体
        resize([front_panel_width - 2, front_panel_height - 2, shell_thickness])
            cylinder(h = shell_thickness, d = 50, $fn = 64);

        // 取り付け穴
        for (x = [-front_panel_width/2 + 8, front_panel_width/2 - 8]) {
            for (y = [-front_panel_height/2 + 8, front_panel_height/2 - 8]) {
                translate([x, y, 0])
                    cylinder(h = shell_thickness + 1, d = 3, $fn = 32);
            }
        }
    }

    // 取り付けクリップ
    for (x = [-front_panel_width/2 + 8, front_panel_width/2 - 8]) {
        translate([x, 0, shell_thickness])
            cube([5, 3, 5], center = true);
    }
}

// =============================================================================
// モジュール: 完全な胴体シェル
// =============================================================================
module complete_torso_shell() {
    difference() {
        union() {
            color("burlywood")
                shell_base();

            color("saddlebrown")
                bands();
        }

        front_panel_opening();
    }
}

// =============================================================================
// モジュール: 装飾付きシェル（木目模様）
// =============================================================================
module decorated_shell() {
    difference() {
        complete_torso_shell();

        // 木目の溝（縦線）
        for (i = [0:plank_count-1]) {
            angle = i * 360 / plank_count;
            rotate([0, 0, angle])
                translate([0, -torso_top_diameter/2 - 1, 0])
                    cube([1, shell_thickness + 2, torso_height]);
        }
    }
}

// =============================================================================
// 出力
// =============================================================================

// 胴体シェル
decorated_shell();

// 前面パネル（別パーツ）
// translate([0, -torso_top_diameter, torso_height/2])
//     rotate([90, 0, 0])
//         front_panel();
