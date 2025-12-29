/**
 * コロ助ロボット - 脚
 * Corosuke Robot - Leg
 *
 * 二足歩行用の脚（左右共通・ミラー使用）
 * - 股関節（ヨー・ピッチ）
 * - 膝関節
 * - 足首関節
 * - 足（TPU製足裏）
 */

// =============================================================================
// パラメータ
// =============================================================================

// 大腿部
thigh_length = 60;
thigh_width = 35;
thigh_depth = 30;

// 下腿部
shin_length = 55;
shin_width = 30;
shin_depth = 25;

// 足
foot_length = 70;
foot_width = 45;
foot_height = 20;

// 関節
hip_joint_diameter = 30;
knee_joint_diameter = 25;
ankle_joint_diameter = 20;

// サーボ (DS3218 - 20kg)
ds3218_width = 20;
ds3218_height = 40.5;
ds3218_depth = 40;

// サーボ (MG996R)
mg996r_width = 20;
mg996r_height = 40;
mg996r_depth = 42;

// =============================================================================
// モジュール: 股関節ブロック
// =============================================================================
module hip_block() {
    difference() {
        union() {
            // メインブロック
            cube([thigh_width + 20, thigh_depth + 10, 40], center = true);

            // ヨー軸接続部（上）
            translate([0, 0, 25])
                cylinder(h = 15, d = hip_joint_diameter, $fn = 32);
        }

        // ヨー軸穴
        translate([0, 0, 20])
            cylinder(h = 25, d = 6, $fn = 32);

        // ピッチ軸サーボスペース
        translate([0, 0, -5])
            cube([ds3218_width + 1, ds3218_depth + 1, ds3218_height + 1], center = true);

        // 配線穴
        translate([thigh_width/2 + 5, 0, 0])
            cylinder(h = 50, d = 8, center = true, $fn = 32);
    }
}

// =============================================================================
// モジュール: 大腿部
// =============================================================================
module thigh() {
    difference() {
        union() {
            // メインボディ
            hull() {
                translate([0, 0, 5])
                    cube([thigh_width, thigh_depth, 10], center = true);
                translate([0, 0, thigh_length - 5])
                    cube([thigh_width - 5, thigh_depth - 5, 10], center = true);
            }

            // 股関節接続部（上）
            translate([0, 0, thigh_length])
                rotate([0, 90, 0])
                    cylinder(h = thigh_width + 10, d = hip_joint_diameter - 5, center = true, $fn = 32);

            // 膝関節接続部（下）
            rotate([0, 90, 0])
                cylinder(h = thigh_width, d = knee_joint_diameter, center = true, $fn = 32);
        }

        // 股関節軸穴
        translate([0, 0, thigh_length])
            rotate([0, 90, 0])
                cylinder(h = thigh_width + 20, d = 6, center = true, $fn = 32);

        // 膝関節軸穴
        rotate([0, 90, 0])
            cylinder(h = thigh_width + 10, d = 6, center = true, $fn = 32);

        // 内部空洞（軽量化）
        translate([0, 0, thigh_length/2])
            cube([thigh_width - 10, thigh_depth - 10, thigh_length - 30], center = true);

        // サーボスペース
        translate([0, 0, thigh_length/2 + 10])
            cube([ds3218_width + 1, ds3218_depth + 1, ds3218_height + 1], center = true);
    }
}

// =============================================================================
// モジュール: 下腿部
// =============================================================================
module shin() {
    difference() {
        union() {
            // メインボディ
            hull() {
                translate([0, 0, 5])
                    cube([shin_width, shin_depth, 10], center = true);
                translate([0, 0, shin_length - 5])
                    cube([shin_width - 5, shin_depth - 5, 10], center = true);
            }

            // 膝関節接続部（上）
            translate([0, 0, shin_length])
                rotate([0, 90, 0])
                    cylinder(h = shin_width + 5, d = knee_joint_diameter - 3, center = true, $fn = 32);

            // 足首関節接続部（下）
            rotate([0, 90, 0])
                cylinder(h = shin_width, d = ankle_joint_diameter, center = true, $fn = 32);
        }

        // 膝関節軸穴
        translate([0, 0, shin_length])
            rotate([0, 90, 0])
                cylinder(h = shin_width + 15, d = 6, center = true, $fn = 32);

        // 足首関節軸穴
        rotate([0, 90, 0])
            cylinder(h = shin_width + 10, d = 6, center = true, $fn = 32);

        // 内部空洞
        translate([0, 0, shin_length/2])
            cube([shin_width - 10, shin_depth - 10, shin_length - 25], center = true);

        // サーボスペース
        translate([0, 0, shin_length/2 + 5])
            cube([ds3218_width + 1, ds3218_depth + 1, ds3218_height + 1], center = true);
    }
}

// =============================================================================
// モジュール: 足
// =============================================================================
module foot() {
    difference() {
        union() {
            // 足本体
            hull() {
                // つま先側
                translate([foot_length/3, 0, foot_height/2])
                    resize([foot_length/2, foot_width, foot_height])
                        sphere(d = 20, $fn = 32);

                // かかと側
                translate([-foot_length/3, 0, foot_height/2])
                    resize([foot_length/3, foot_width * 0.8, foot_height])
                        sphere(d = 20, $fn = 32);
            }

            // 足首接続部
            translate([0, 0, foot_height])
                cylinder(h = 15, d = ankle_joint_diameter + 10, $fn = 32);
        }

        // 足首軸穴
        translate([0, 0, foot_height + 7.5])
            rotate([0, 90, 0])
                cylinder(h = ankle_joint_diameter + 20, d = 6, center = true, $fn = 32);

        // サーボスペース
        translate([0, 0, foot_height + 10])
            cube([ds3218_width + 1, ds3218_depth + 1, 20], center = true);

        // 足裏くぼみ（TPU挿入用）
        translate([0, 0, 2])
            resize([foot_length - 5, foot_width - 5, 5])
                sphere(d = 20, $fn = 32);
    }
}

// =============================================================================
// モジュール: 足裏（TPU製）
// =============================================================================
module foot_sole() {
    // TPUで印刷する滑り止めパーツ

    difference() {
        resize([foot_length - 6, foot_width - 6, 4])
            sphere(d = 20, $fn = 32);

        // 上半分カット
        translate([0, 0, 5])
            cube([foot_length, foot_width, 10], center = true);
    }

    // 滑り止めパターン
    for (x = [-foot_length/3 : 10 : foot_length/3]) {
        for (y = [-foot_width/3 : 10 : foot_width/3]) {
            translate([x, y, -1])
                cylinder(h = 2, d = 5, $fn = 6);  // 六角形パターン
        }
    }
}

// =============================================================================
// モジュール: 完全な脚
// =============================================================================
module complete_leg(is_right = true) {
    // 股関節ブロック
    color("gray")
        translate([0, 0, thigh_length + shin_length + foot_height + 30])
            hip_block();

    // 大腿部
    color("white")
        translate([0, 0, shin_length + foot_height + 15])
            thigh();

    // 下腿部
    color("white")
        translate([0, 0, foot_height + 15])
            shin();

    // 足
    color("white")
        foot();

    // 足裏（TPU）
    color("darkgray")
        foot_sole();
}

// =============================================================================
// モジュール: DS3218サーボ（参考モデル）
// =============================================================================
module ds3218_servo() {
    color("black") {
        cube([ds3218_width, ds3218_depth, ds3218_height], center = true);
        translate([0, ds3218_depth/2 - 7, ds3218_height/2])
            cylinder(h = 5, d = 6, $fn = 32);
    }
}

// =============================================================================
// 出力
// =============================================================================

// 完全な脚
complete_leg(true);

// 個別パーツ出力用
// hip_block();
// thigh();
// shin();
// foot();
// foot_sole();
