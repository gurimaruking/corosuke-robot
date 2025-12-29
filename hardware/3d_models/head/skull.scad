/**
 * コロ助ロボット - 頭蓋骨フレーム
 * Corosuke Robot - Skull Frame
 *
 * コロ助の頭部内部フレーム
 * - 目の機構マウント
 * - 口の機構マウント
 * - サーボ・電子部品スペース
 * - 首との接続部
 */

// =============================================================================
// パラメータ
// =============================================================================

// 頭部サイズ（コロ助は球形の頭）
head_diameter = 120;
head_radius = head_diameter / 2;

// フレーム
frame_thickness = 3;

// 目の位置
eye_spacing = 40;
eye_height = 10;  // 中心からの高さ
eye_mechanism_width = 80;
eye_mechanism_height = 50;
eye_mechanism_depth = 60;

// 口の位置
mouth_height = -25;  // 中心からの高さ
mouth_width = 40;
mouth_height_size = 20;

// 首の接続
neck_diameter = 30;
neck_mount_height = 20;

// サーボ (SG90)
servo_width = 12.5;
servo_height = 22.5;
servo_depth = 23;

// =============================================================================
// モジュール: 頭蓋骨フレーム
// =============================================================================
module skull_frame() {
    difference() {
        union() {
            // メイン球形フレーム
            difference() {
                sphere(d = head_diameter - 10, $fn = 64);
                sphere(d = head_diameter - 10 - frame_thickness * 2, $fn = 64);

                // 前面カット（顔の開口部）
                translate([0, head_radius, 0])
                    cube([head_diameter, head_diameter, head_diameter], center = true);
            }

            // 目の機構マウントレール
            eye_mount_rails();

            // 口の機構マウント
            mouth_mount();

            // 首の接続部
            neck_connector();

            // 内部リブ（補強）
            internal_ribs();
        }

        // 目の開口部
        translate([0, -head_radius/2, eye_height])
            rotate([90, 0, 0])
                cylinder(h = 30, d = eye_mechanism_width + 10, $fn = 64);

        // 口の開口部
        translate([0, -head_radius/2, mouth_height])
            rotate([90, 0, 0])
                cube([mouth_width + 10, mouth_height_size + 10, 30], center = true);

        // 配線穴
        translate([head_radius/2 - 10, 0, 0])
            cylinder(h = head_diameter, d = 15, center = true, $fn = 32);

        translate([-head_radius/2 + 10, 0, 0])
            cylinder(h = head_diameter, d = 15, center = true, $fn = 32);
    }
}

// =============================================================================
// モジュール: 目の機構マウントレール
// =============================================================================
module eye_mount_rails() {
    rail_width = 5;
    rail_height = 10;

    // 左レール
    translate([-eye_mechanism_width/2 - rail_width, 0, eye_height])
        cube([rail_width, eye_mechanism_depth, rail_height], center = true);

    // 右レール
    translate([eye_mechanism_width/2 + rail_width, 0, eye_height])
        cube([rail_width, eye_mechanism_depth, rail_height], center = true);

    // 上レール
    translate([0, 0, eye_height + eye_mechanism_height/2])
        cube([eye_mechanism_width + rail_width*2, rail_width, rail_height], center = true);

    // マウントプレート（後部）
    translate([0, eye_mechanism_depth/2 - 5, eye_height])
        difference() {
            cube([eye_mechanism_width, 5, eye_mechanism_height], center = true);

            // サーボ用穴
            for (x = [-30, -10, 10, 30]) {
                translate([x, 0, 10])
                    rotate([90, 0, 0])
                        cylinder(h = 10, d = 3, center = true, $fn = 32);
            }
        }
}

// =============================================================================
// モジュール: 口の機構マウント
// =============================================================================
module mouth_mount() {
    mount_depth = 30;

    translate([0, 0, mouth_height]) {
        // マウントフレーム
        difference() {
            cube([mouth_width + 20, mount_depth, mouth_height_size + 10], center = true);
            cube([mouth_width, mount_depth + 10, mouth_height_size], center = true);

            // サーボ穴
            translate([mouth_width/2 + 5, 0, 0])
                cube([servo_width + 1, servo_depth + 1, servo_height + 1], center = true);

            translate([-mouth_width/2 - 5, 0, 0])
                cube([servo_width + 1, servo_depth + 1, servo_height + 1], center = true);
        }
    }
}

// =============================================================================
// モジュール: 首の接続部
// =============================================================================
module neck_connector() {
    translate([0, 0, -head_radius/2]) {
        difference() {
            // 接続シリンダー
            cylinder(h = neck_mount_height, d = neck_diameter + 10, $fn = 64);

            // 首の穴
            cylinder(h = neck_mount_height + 10, d = neck_diameter, $fn = 64);

            // ベアリング溝
            translate([0, 0, 5])
                difference() {
                    cylinder(h = 8, d = neck_diameter + 6, $fn = 64);
                    cylinder(h = 8, d = neck_diameter - 2, $fn = 64);
                }

            // ネジ穴（4箇所）
            for (angle = [0, 90, 180, 270]) {
                rotate([0, 0, angle])
                    translate([neck_diameter/2 + 3, 0, 10])
                        cylinder(h = 15, d = 3, $fn = 32);
            }
        }
    }
}

// =============================================================================
// モジュール: 内部リブ
// =============================================================================
module internal_ribs() {
    rib_thickness = 2;

    // 垂直リブ（左右）
    for (x = [-head_radius/2 + 15, head_radius/2 - 15]) {
        translate([x, 0, 0])
            intersection() {
                cube([rib_thickness, head_diameter, head_diameter], center = true);
                sphere(d = head_diameter - 15, $fn = 64);
            }
    }

    // 水平リブ
    translate([0, 0, -10])
        intersection() {
            cube([head_diameter, head_diameter, rib_thickness], center = true);
            sphere(d = head_diameter - 15, $fn = 64);
        }
}

// =============================================================================
// モジュール: 丁髷マウント
// =============================================================================
module topknot_mount() {
    mount_diameter = 15;
    mount_height = 10;

    translate([0, -10, head_radius - 5]) {
        difference() {
            cylinder(h = mount_height, d = mount_diameter, $fn = 32);
            cylinder(h = mount_height + 1, d = 8, $fn = 32);  // 丁髷の軸穴
        }
    }
}

// =============================================================================
// モジュール: ESP32-CAMマウント
// =============================================================================
module camera_mount() {
    // ESP32-S3-CAMのサイズ
    cam_width = 24;
    cam_height = 32;
    cam_depth = 10;

    translate([0, -head_radius/2 + 15, head_radius/2 - 20]) {
        difference() {
            cube([cam_width + 6, cam_depth + 6, cam_height + 6], center = true);
            cube([cam_width + 0.5, cam_depth + 0.5, cam_height + 0.5], center = true);

            // カメラレンズ穴
            translate([0, -cam_depth/2, -cam_height/4])
                rotate([90, 0, 0])
                    cylinder(h = 10, d = 10, $fn = 32);
        }
    }
}

// =============================================================================
// 完全な頭蓋骨
// =============================================================================
module complete_skull() {
    skull_frame();
    topknot_mount();
    camera_mount();
}

// =============================================================================
// 出力
// =============================================================================
complete_skull();

// デバッグ：目の機構位置確認用ダミー
// %translate([0, -10, eye_height])
//     cube([eye_mechanism_width, eye_mechanism_depth, eye_mechanism_height], center = true);
