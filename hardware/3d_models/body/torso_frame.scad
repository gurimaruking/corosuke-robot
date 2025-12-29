/**
 * コロ助ロボット - 胴体フレーム
 * Corosuke Robot - Torso Frame
 *
 * コロ助の胴体内部フレーム
 * - 風呂桶をモチーフにした円筒形
 * - 首・腕・腰の接続部
 * - 電子部品・バッテリースペース
 */

// =============================================================================
// パラメータ
// =============================================================================

// 胴体サイズ（風呂桶形状）
torso_top_diameter = 100;     // 上部直径
torso_bottom_diameter = 80;   // 下部直径
torso_height = 120;           // 高さ
wall_thickness = 3;

// 首の接続
neck_diameter = 30;
neck_mount_height = 15;

// 肩の接続
shoulder_width = 110;         // 肩幅
shoulder_height = 90;         // 胴体上端からの位置
shoulder_mount_diameter = 25;

// 腰の接続
hip_diameter = 40;
hip_mount_height = 20;

// サーボ (MG996R)
mg996r_width = 20;
mg996r_height = 40;
mg996r_depth = 42;

// 電子部品スペース
electronics_width = 60;
electronics_depth = 40;
electronics_height = 50;

// =============================================================================
// モジュール: 基本胴体フレーム
// =============================================================================
module torso_frame_base() {
    difference() {
        // 外側（テーパー円筒）
        cylinder(h = torso_height,
                 d1 = torso_bottom_diameter,
                 d2 = torso_top_diameter,
                 $fn = 64);

        // 内側をくり抜き
        translate([0, 0, wall_thickness])
            cylinder(h = torso_height,
                     d1 = torso_bottom_diameter - wall_thickness * 2,
                     d2 = torso_top_diameter - wall_thickness * 2,
                     $fn = 64);
    }
}

// =============================================================================
// モジュール: 首の接続部
// =============================================================================
module neck_mount() {
    translate([0, 0, torso_height]) {
        difference() {
            // マウントプレート
            cylinder(h = neck_mount_height, d = torso_top_diameter - 10, $fn = 64);

            // 首の穴
            translate([0, 0, -1])
                cylinder(h = neck_mount_height + 2, d = neck_diameter, $fn = 64);

            // サーボ用スペース（首ヨー）
            translate([0, 0, 5])
                cylinder(h = neck_mount_height, d = neck_diameter + 30, $fn = 64);

            // 配線穴
            for (angle = [45, 135, 225, 315]) {
                rotate([0, 0, angle])
                    translate([torso_top_diameter/2 - 15, 0, -1])
                        cylinder(h = neck_mount_height + 2, d = 8, $fn = 32);
            }
        }

        // サーボマウント（首ヨー用 MG996R）
        translate([0, neck_diameter/2 + mg996r_depth/2 + 5, 5])
            neck_servo_mount();
    }
}

// =============================================================================
// モジュール: 首サーボマウント
// =============================================================================
module neck_servo_mount() {
    difference() {
        cube([mg996r_width + 10, mg996r_depth + 10, mg996r_height/2], center = true);
        cube([mg996r_width + 0.5, mg996r_depth + 0.5, mg996r_height], center = true);
    }
}

// =============================================================================
// モジュール: 肩の接続部
// =============================================================================
module shoulder_mounts() {
    // 右肩
    translate([shoulder_width/2, 0, shoulder_height])
        shoulder_mount(1);

    // 左肩
    translate([-shoulder_width/2, 0, shoulder_height])
        shoulder_mount(-1);
}

module shoulder_mount(side) {  // side: 1 = right, -1 = left
    rotate([0, side * 90, 0]) {
        difference() {
            union() {
                // マウントプレート
                cylinder(h = 15, d = shoulder_mount_diameter + 10, $fn = 32);

                // 胴体との接続アーム
                translate([0, 0, 7.5])
                    rotate([0, -side * 90, 0])
                        translate([0, 0, -side * 5])
                            cube([20, 15, abs(shoulder_width/2 - torso_top_diameter/2)], center = true);
            }

            // シャフト穴
            translate([0, 0, -1])
                cylinder(h = 20, d = 6, $fn = 32);

            // ベアリング溝
            translate([0, 0, 5])
                cylinder(h = 8, d = shoulder_mount_diameter, $fn = 32);
        }

        // サーボマウント
        translate([0, -shoulder_mount_diameter/2 - 15, 7.5])
            shoulder_servo_mount();
    }
}

// =============================================================================
// モジュール: 肩サーボマウント
// =============================================================================
module shoulder_servo_mount() {
    difference() {
        cube([mg996r_width + 8, mg996r_depth + 8, mg996r_height/2], center = true);
        translate([0, 0, 5])
            cube([mg996r_width + 0.5, mg996r_depth + 0.5, mg996r_height], center = true);
    }
}

// =============================================================================
// モジュール: 腰の接続部
// =============================================================================
module hip_mount() {
    translate([0, 0, -hip_mount_height]) {
        difference() {
            // マウントベース
            cylinder(h = hip_mount_height, d = torso_bottom_diameter - 5, $fn = 64);

            // 腰シャフト穴
            translate([0, 0, -1])
                cylinder(h = hip_mount_height + 2, d = hip_diameter, $fn = 64);

            // ベアリング溝
            translate([0, 0, hip_mount_height - 10])
                difference() {
                    cylinder(h = 8, d = hip_diameter + 15, $fn = 64);
                    cylinder(h = 8, d = hip_diameter - 5, $fn = 64);
                }

            // 配線穴
            for (angle = [0, 90, 180, 270]) {
                rotate([0, 0, angle])
                    translate([torso_bottom_diameter/2 - 20, 0, -1])
                        cylinder(h = hip_mount_height + 2, d = 10, $fn = 32);
            }
        }
    }
}

// =============================================================================
// モジュール: 電子部品マウント
// =============================================================================
module electronics_mount() {
    translate([0, 0, 20]) {
        difference() {
            // マウントプレート
            cube([electronics_width + 10, electronics_depth + 10, 3], center = true);

            // ネジ穴
            for (x = [-electronics_width/2 + 5, electronics_width/2 - 5]) {
                for (y = [-electronics_depth/2 + 5, electronics_depth/2 - 5]) {
                    translate([x, y, 0])
                        cylinder(h = 10, d = 3, center = true, $fn = 32);
                }
            }
        }

        // 基板スタンドオフ
        for (x = [-electronics_width/2 + 5, electronics_width/2 - 5]) {
            for (y = [-electronics_depth/2 + 5, electronics_depth/2 - 5]) {
                translate([x, y, 5])
                    difference() {
                        cylinder(h = 10, d = 6, $fn = 32);
                        cylinder(h = 12, d = 2.5, $fn = 32);
                    }
            }
        }
    }
}

// =============================================================================
// モジュール: 内部リブ（補強）
// =============================================================================
module internal_ribs() {
    rib_thickness = 2;

    // 垂直リブ（4方向）
    for (angle = [0, 90, 180, 270]) {
        rotate([0, 0, angle])
            translate([0, 0, torso_height/2])
                intersection() {
                    cube([rib_thickness, torso_top_diameter, torso_height], center = true);
                    cylinder(h = torso_height,
                             d1 = torso_bottom_diameter - wall_thickness * 2 - 2,
                             d2 = torso_top_diameter - wall_thickness * 2 - 2,
                             center = true, $fn = 64);
                }
    }

    // 水平リブ
    for (z = [30, 60, 90]) {
        translate([0, 0, z]) {
            diam = torso_bottom_diameter + (torso_top_diameter - torso_bottom_diameter) * z / torso_height;
            difference() {
                cylinder(h = rib_thickness, d = diam - wall_thickness * 2 - 2, $fn = 64);
                cylinder(h = rib_thickness + 1, d = diam - wall_thickness * 2 - 20, $fn = 64);
            }
        }
    }
}

// =============================================================================
// 完全な胴体フレーム
// =============================================================================
module complete_torso_frame() {
    torso_frame_base();
    neck_mount();
    shoulder_mounts();
    hip_mount();
    internal_ribs();
    electronics_mount();
}

// =============================================================================
// 出力
// =============================================================================
complete_torso_frame();
