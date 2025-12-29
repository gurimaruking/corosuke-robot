/**
 * コロ助ロボット - 腕
 * Corosuke Robot - Arm
 *
 * コロ助の腕（左右共通・ミラー使用）
 * - 肩関節（上下）
 * - 肘関節（曲げ）
 * - 手（固定）
 */

// =============================================================================
// パラメータ
// =============================================================================

// 上腕
upper_arm_length = 50;
upper_arm_diameter = 25;

// 前腕
lower_arm_length = 45;
lower_arm_diameter = 22;

// 手
hand_width = 30;
hand_height = 25;
hand_depth = 15;
finger_length = 20;
finger_diameter = 8;

// 関節
joint_diameter = 20;
joint_width = 15;

// サーボ
servo_width = 12.5;
servo_height = 22.5;
servo_depth = 23;

// =============================================================================
// モジュール: 上腕
// =============================================================================
module upper_arm() {
    difference() {
        union() {
            // メインシリンダー
            cylinder(h = upper_arm_length, d = upper_arm_diameter, $fn = 32);

            // 肩関節部
            translate([0, 0, upper_arm_length])
                sphere(d = joint_diameter + 5, $fn = 32);
        }

        // サーボスペース
        translate([0, 0, upper_arm_length/2])
            cube([servo_width + 1, servo_depth + 1, servo_height + 1], center = true);

        // 肘関節穴
        translate([0, 0, -1])
            cylinder(h = 10, d = 6, $fn = 32);
    }
}

// =============================================================================
// モジュール: 肩関節
// =============================================================================
module shoulder_joint() {
    difference() {
        union() {
            // 関節球
            sphere(d = joint_diameter, $fn = 32);

            // 取り付け部
            translate([0, 0, joint_diameter/2])
                cylinder(h = 15, d = joint_diameter - 5, $fn = 32);
        }

        // シャフト穴
        cylinder(h = joint_diameter * 2, d = 6, center = true, $fn = 32);

        // サーボホーン取り付け
        translate([0, 0, joint_diameter/2 + 10])
            cylinder(h = 10, d = 8, $fn = 32);
    }
}

// =============================================================================
// モジュール: 前腕
// =============================================================================
module lower_arm() {
    difference() {
        union() {
            // メインシリンダー
            cylinder(h = lower_arm_length, d = lower_arm_diameter, $fn = 32);

            // 肘関節部
            translate([0, 0, lower_arm_length])
                rotate([90, 0, 0])
                    cylinder(h = joint_width, d = joint_diameter, center = true, $fn = 32);
        }

        // 手首接続穴
        translate([0, 0, -1])
            cylinder(h = 15, d = 8, $fn = 32);

        // 肘関節軸穴
        translate([0, 0, lower_arm_length])
            rotate([90, 0, 0])
                cylinder(h = joint_width + 10, d = 3, center = true, $fn = 32);
    }
}

// =============================================================================
// モジュール: 肘関節
// =============================================================================
module elbow_joint() {
    difference() {
        // 関節ブロック
        hull() {
            rotate([90, 0, 0])
                cylinder(h = joint_width - 2, d = joint_diameter - 2, center = true, $fn = 32);

            translate([0, 0, -15])
                cylinder(h = 5, d = upper_arm_diameter - 5, $fn = 32);
        }

        // 軸穴
        rotate([90, 0, 0])
            cylinder(h = joint_width + 5, d = 3, center = true, $fn = 32);

        // サーボホーン取り付け
        rotate([90, 0, 0])
            translate([0, 0, joint_width/2 - 3])
                cylinder(h = 5, d = 8, $fn = 32);
    }
}

// =============================================================================
// モジュール: 手（簡易版）
// =============================================================================
module hand() {
    // 手のひら
    hull() {
        translate([0, 0, 0])
            sphere(d = hand_depth, $fn = 32);
        translate([0, 0, hand_height - hand_depth/2])
            resize([hand_width, hand_depth, hand_depth])
                sphere(d = hand_depth, $fn = 32);
    }

    // 指（4本まとめて）
    translate([0, 0, hand_height]) {
        for (x = [-hand_width/3, -hand_width/9, hand_width/9, hand_width/3]) {
            translate([x, 0, 0])
                finger();
        }
    }

    // 親指
    translate([hand_width/2 - 3, 0, hand_height/2])
        rotate([0, 30, 0])
            scale([0.8, 1, 0.8])
                finger();
}

// =============================================================================
// モジュール: 指
// =============================================================================
module finger() {
    // 指を3関節で表現
    union() {
        // 第1関節
        cylinder(h = finger_length * 0.4, d = finger_diameter, $fn = 16);

        // 第2関節
        translate([0, 0, finger_length * 0.4])
            rotate([10, 0, 0]) {
                cylinder(h = finger_length * 0.35, d = finger_diameter * 0.9, $fn = 16);

                // 第3関節（先端）
                translate([0, 0, finger_length * 0.35])
                    rotate([10, 0, 0])
                        cylinder(h = finger_length * 0.25, d1 = finger_diameter * 0.8, d2 = finger_diameter * 0.5, $fn = 16);
            }
    }
}

// =============================================================================
// モジュール: 完全な腕
// =============================================================================
module complete_arm(is_right = true) {
    mirror_factor = is_right ? 1 : -1;

    // 肩関節
    color("gray")
        shoulder_joint();

    // 上腕
    color("white")
        translate([0, 0, -upper_arm_length - 5])
            upper_arm();

    // 肘関節
    color("gray")
        translate([0, 0, -upper_arm_length - 10])
            elbow_joint();

    // 前腕
    color("white")
        translate([0, 0, -upper_arm_length - lower_arm_length - 20])
            lower_arm();

    // 手
    color("pink")
        translate([0, 0, -upper_arm_length - lower_arm_length - 25])
            rotate([180, 0, 0])
                hand();
}

// =============================================================================
// モジュール: 腕カバー（外装）
// =============================================================================
module arm_cover() {
    cover_thickness = 2;

    difference() {
        union() {
            // 上腕カバー
            cylinder(h = upper_arm_length - 5, d = upper_arm_diameter + cover_thickness * 2, $fn = 32);

            // 前腕カバー
            translate([0, 0, -lower_arm_length - 15])
                cylinder(h = lower_arm_length - 5, d = lower_arm_diameter + cover_thickness * 2, $fn = 32);
        }

        // 内部くり抜き
        translate([0, 0, -1])
            cylinder(h = upper_arm_length, d = upper_arm_diameter + 1, $fn = 32);

        translate([0, 0, -lower_arm_length - 16])
            cylinder(h = lower_arm_length, d = lower_arm_diameter + 1, $fn = 32);
    }
}

// =============================================================================
// 出力
// =============================================================================

// 完全な腕（右）
complete_arm(true);

// 個別パーツ出力用
// upper_arm();
// lower_arm();
// shoulder_joint();
// elbow_joint();
// hand();
