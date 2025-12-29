/**
 * コロ助ロボット - 口の機構
 * Corosuke Robot - Mouth Mechanism
 *
 * リップシンク対応の口の機構
 * - 上唇・下唇の独立制御
 * - SG90サーボ2個使用
 */

// =============================================================================
// パラメータ
// =============================================================================

// 口のサイズ
mouth_width = 35;
mouth_height_open = 15;
lip_thickness = 3;
lip_depth = 10;

// サーボ (SG90)
servo_width = 12.5;
servo_height = 22.5;
servo_depth = 23;

// リンケージ
link_arm_length = 15;
pushrod_length = 20;

// フレーム
frame_width = 60;
frame_height = 40;
frame_depth = 35;
frame_thickness = 3;

// =============================================================================
// モジュール: 上唇
// =============================================================================
module upper_lip() {
    difference() {
        // 唇の形状（楕円形）
        resize([mouth_width, lip_depth, lip_thickness * 2])
            sphere(d = 20, $fn = 64);

        // 下半分をカット
        translate([0, 0, -lip_thickness * 2])
            cube([mouth_width + 10, lip_depth + 10, lip_thickness * 2], center = true);
    }

    // ヒンジ取り付け部
    translate([0, lip_depth/2, 0]) {
        difference() {
            cube([mouth_width + 10, 5, 6], center = true);
            // ヒンジ穴
            rotate([0, 90, 0])
                cylinder(h = mouth_width + 20, d = 3, center = true, $fn = 32);
        }
    }

    // リンク取り付け部
    translate([mouth_width/2 + 5, 0, 0]) {
        difference() {
            cube([8, 5, 8], center = true);
            // ボールリンク穴
            translate([0, 0, 2])
                cylinder(h = 10, d = 2.5, center = true, $fn = 32);
        }
    }
}

// =============================================================================
// モジュール: 下唇
// =============================================================================
module lower_lip() {
    difference() {
        // 唇の形状
        resize([mouth_width, lip_depth, lip_thickness * 2.5])
            sphere(d = 20, $fn = 64);

        // 上半分をカット
        translate([0, 0, lip_thickness * 2])
            cube([mouth_width + 10, lip_depth + 10, lip_thickness * 3], center = true);
    }

    // ヒンジ取り付け部
    translate([0, lip_depth/2, 0]) {
        difference() {
            cube([mouth_width + 10, 5, 6], center = true);
            rotate([0, 90, 0])
                cylinder(h = mouth_width + 20, d = 3, center = true, $fn = 32);
        }
    }

    // リンク取り付け部
    translate([-mouth_width/2 - 5, 0, 0]) {
        difference() {
            cube([8, 5, 8], center = true);
            translate([0, 0, -2])
                cylinder(h = 10, d = 2.5, center = true, $fn = 32);
        }
    }
}

// =============================================================================
// モジュール: 口のフレーム
// =============================================================================
module mouth_frame() {
    difference() {
        // 外枠
        cube([frame_width, frame_depth, frame_height], center = true);

        // 内部をくり抜き
        cube([frame_width - frame_thickness*2,
              frame_depth - frame_thickness*2,
              frame_height - frame_thickness*2], center = true);

        // 前面開口（口が見える部分）
        translate([0, -frame_depth/2, 0])
            cube([mouth_width + 5, frame_thickness * 3, mouth_height_open + 10], center = true);

        // サーボマウント穴（右側 - 上唇用）
        translate([frame_width/2 - servo_width/2 - 2, 0, 5]) {
            cube([servo_width + 1, servo_depth + 1, servo_height + 1], center = true);
            // ネジ穴
            translate([0, 0, -servo_height/2 - 3])
                cylinder(h = 10, d = 3, center = true, $fn = 32);
        }

        // サーボマウント穴（左側 - 下唇用）
        translate([-frame_width/2 + servo_width/2 + 2, 0, -5]) {
            cube([servo_width + 1, servo_depth + 1, servo_height + 1], center = true);
            translate([0, 0, -servo_height/2 - 3])
                cylinder(h = 10, d = 3, center = true, $fn = 32);
        }
    }

    // ヒンジマウント
    translate([0, -frame_depth/2 + frame_thickness + 3, 0]) {
        // 上唇ヒンジ
        translate([0, 0, mouth_height_open/2 + 2])
            rotate([0, 90, 0])
                difference() {
                    cylinder(h = mouth_width + 15, d = 6, center = true, $fn = 32);
                    cylinder(h = mouth_width + 20, d = 3, center = true, $fn = 32);
                }

        // 下唇ヒンジ
        translate([0, 0, -mouth_height_open/2 - 2])
            rotate([0, 90, 0])
                difference() {
                    cylinder(h = mouth_width + 15, d = 6, center = true, $fn = 32);
                    cylinder(h = mouth_width + 20, d = 3, center = true, $fn = 32);
                }
    }
}

// =============================================================================
// モジュール: サーボホーン
// =============================================================================
module servo_horn() {
    difference() {
        hull() {
            cylinder(h = 2, d = 7, $fn = 32);
            translate([link_arm_length, 0, 0])
                cylinder(h = 2, d = 4, $fn = 32);
        }
        // サーボシャフト穴
        cylinder(h = 5, d = 4.5, center = true, $fn = 32);
        // リンク穴
        translate([link_arm_length, 0, 0])
            cylinder(h = 5, d = 2, center = true, $fn = 32);
    }
}

// =============================================================================
// モジュール: SG90サーボ（参考モデル）
// =============================================================================
module sg90_servo() {
    color("blue") {
        translate([-servo_width/2, -servo_depth/2, 0])
            cube([servo_width, servo_depth, servo_height]);

        translate([0, servo_depth/2 - 6, servo_height])
            cylinder(h = 4, d = 5, $fn = 32);
    }
}

// =============================================================================
// 組み立てビュー
// =============================================================================
module mouth_assembly() {
    // フレーム
    color("lightgray", 0.5)
        mouth_frame();

    // 上唇
    color("pink")
        translate([0, -frame_depth/2 + 8, mouth_height_open/2 + 2])
            rotate([20, 0, 0])  // 少し開いた状態
                upper_lip();

    // 下唇
    color("pink")
        translate([0, -frame_depth/2 + 8, -mouth_height_open/2 - 2])
            rotate([-30, 0, 0])  // 少し開いた状態
                lower_lip();

    // 上唇サーボ
    translate([frame_width/2 - servo_width/2 - 2, 0, 5])
        rotate([0, 0, 180])
            sg90_servo();

    // 下唇サーボ
    translate([-frame_width/2 + servo_width/2 + 2, 0, -5])
        sg90_servo();
}

// =============================================================================
// 出力
// =============================================================================

// 組み立てビュー
mouth_assembly();

// 個別パーツ出力用
// upper_lip();
// lower_lip();
// mouth_frame();
// servo_horn();
