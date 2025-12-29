/**
 * コロ助ロボット - 顔面シェル
 * Corosuke Robot - Face Shell
 *
 * コロ助の顔の外装
 * - 原作準拠の丸顔デザイン
 * - ピンク色の顔
 * - 目と口の開口部
 */

// =============================================================================
// パラメータ
// =============================================================================

// 頭部サイズ
head_diameter = 120;
head_radius = head_diameter / 2;
shell_thickness = 3;

// 目
eye_spacing = 40;
eye_diameter = 32;
eye_height = 10;

// 口
mouth_width = 35;
mouth_height = 15;
mouth_y = -25;

// ほっぺ（オプション）
cheek_diameter = 20;
cheek_height = 0;
cheek_offset_x = 35;

// =============================================================================
// モジュール: 基本顔面シェル
// =============================================================================
module face_shell_base() {
    difference() {
        // 外側の球
        sphere(d = head_diameter, $fn = 128);

        // 内側をくり抜き
        sphere(d = head_diameter - shell_thickness * 2, $fn = 128);

        // 後ろ半分をカット
        translate([0, head_radius/2, 0])
            cube([head_diameter + 10, head_diameter, head_diameter + 10], center = true);
    }
}

// =============================================================================
// モジュール: 目の開口部
// =============================================================================
module eye_openings() {
    // 右目
    translate([eye_spacing/2, -head_radius + 10, eye_height])
        rotate([90, 0, 0])
            cylinder(h = 30, d = eye_diameter, $fn = 64);

    // 左目
    translate([-eye_spacing/2, -head_radius + 10, eye_height])
        rotate([90, 0, 0])
            cylinder(h = 30, d = eye_diameter, $fn = 64);
}

// =============================================================================
// モジュール: 口の開口部（コロ助は横長の口）
// =============================================================================
module mouth_opening() {
    translate([0, -head_radius + 10, mouth_y])
        rotate([90, 0, 0])
            resize([mouth_width, mouth_height, 30])
                cylinder(h = 30, d = 20, $fn = 64);
}

// =============================================================================
// モジュール: 完全な顔面シェル
// =============================================================================
module face_shell() {
    difference() {
        face_shell_base();
        eye_openings();
        mouth_opening();
    }
}

// =============================================================================
// モジュール: 目の縁取り
// =============================================================================
module eye_rim() {
    rim_width = 3;
    rim_depth = 2;

    difference() {
        cylinder(h = rim_depth, d = eye_diameter + rim_width * 2, $fn = 64);
        translate([0, 0, -1])
            cylinder(h = rim_depth + 2, d = eye_diameter, $fn = 64);
    }
}

// =============================================================================
// モジュール: 口の縁取り
// =============================================================================
module mouth_rim() {
    rim_width = 2;
    rim_depth = 2;

    difference() {
        resize([mouth_width + rim_width * 2, mouth_height + rim_width * 2, rim_depth])
            cylinder(h = rim_depth, d = 20, $fn = 64);

        translate([0, 0, -1])
            resize([mouth_width, mouth_height, rim_depth + 2])
                cylinder(h = rim_depth + 2, d = 20, $fn = 64);
    }
}

// =============================================================================
// モジュール: ほっぺ（オプション - 少し膨らんだ部分）
// =============================================================================
module cheek(side = 1) {  // side: 1 = right, -1 = left
    translate([side * cheek_offset_x, -head_radius + 5, cheek_height])
        scale([1, 0.3, 1])
            sphere(d = cheek_diameter, $fn = 32);
}

// =============================================================================
// 完全な顔面（装飾付き）
// =============================================================================
module complete_face() {
    // メイン顔面
    color("pink")
        face_shell();

    // 目の縁取り
    color("white") {
        translate([eye_spacing/2, -head_radius + shell_thickness, eye_height])
            rotate([90, 0, 0])
                eye_rim();

        translate([-eye_spacing/2, -head_radius + shell_thickness, eye_height])
            rotate([90, 0, 0])
                eye_rim();
    }

    // 口の縁取り
    color("darkred")
        translate([0, -head_radius + shell_thickness, mouth_y])
            rotate([90, 0, 0])
                mouth_rim();
}

// =============================================================================
// 出力
// =============================================================================
complete_face();
