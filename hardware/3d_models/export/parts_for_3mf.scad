/**
 * コロ助ロボット - パーツ別3MFエクスポート
 * Corosuke Robot - Individual Parts for 3MF Export
 *
 * 使い方:
 * 1. 出力したいパーツのコメントを外す
 * 2. File → Export → Export as 3MF
 * 3. ファイル名を付けて保存
 *
 * 3MFは色情報を保持できるので、マルチカラー印刷や
 * スライサーでの確認に便利です。
 */

$fn = 64;  // 高品質レンダリング

// =============================================================================
// 出力選択（使いたいパーツのコメントを外す）
// =============================================================================

// --- 頭部パーツ ---
//head_face_shell();
//head_skull_frame();
//head_eyeball_right();
//head_eyeball_left();
//head_eyelid_upper_right();
//head_eyelid_upper_left();
//head_eyelid_lower_right();
//head_eyelid_lower_left();
//head_mouth_upper();
//head_mouth_lower();
head_topknot();

// --- 胴体パーツ ---
//body_torso_shell();
//body_torso_frame();

// --- 腕パーツ ---
//arm_upper_right();
//arm_upper_left();
//arm_lower_right();
//arm_lower_left();
//arm_hand_right();
//arm_hand_left();

// --- 脚パーツ ---
//leg_thigh_right();
//leg_thigh_left();
//leg_shin_right();
//leg_shin_left();
//leg_foot_right();
//leg_foot_left();
//leg_foot_sole_right();  // TPU用
//leg_foot_sole_left();   // TPU用

// --- アクセサリー ---
//sword_blade();
//sword_handle();
//sword_guard();
//sword_sheath();
//sword_wheel();
//sword_back_mount();

// =============================================================================
// 頭部パーツ
// =============================================================================

module head_face_shell() {
    color("pink") {
        difference() {
            sphere(d = 120);
            sphere(d = 114);
            // 後ろをカット
            translate([0, 60, 0]) cube([150, 120, 150], center = true);
            // 目の穴
            translate([20, -50, 10]) rotate([90, 0, 0]) cylinder(h = 20, d = 32);
            translate([-20, -50, 10]) rotate([90, 0, 0]) cylinder(h = 20, d = 32);
            // 口の穴
            translate([0, -50, -25]) rotate([90, 0, 0])
                resize([35, 15, 20]) cylinder(h = 20, d = 20);
        }
    }
}

module head_skull_frame() {
    color("white") {
        difference() {
            sphere(d = 110);
            sphere(d = 104);
            translate([0, 60, 0]) cube([140, 120, 140], center = true);
            // 目のスペース
            translate([0, -20, 10]) cube([80, 60, 50], center = true);
            // 口のスペース
            translate([0, -20, -25]) cube([50, 40, 25], center = true);
            // 首の穴
            translate([0, 0, -55]) cylinder(h = 20, d = 30);
        }
    }
}

module head_eyeball_right() {
    color("white") {
        difference() {
            sphere(d = 30);
            // 瞳の位置をマーク
            translate([0, -15, 0]) sphere(d = 12);
        }
    }
    color("black")
        translate([0, -12, 0]) sphere(d = 10);
    color("white")
        translate([2, -14, 2]) sphere(d = 3);  // ハイライト
}

module head_eyeball_left() {
    head_eyeball_right();
}

module head_eyelid_upper_right() {
    color("pink") {
        difference() {
            intersection() {
                sphere(d = 34);
                translate([0, 0, 5]) cube([40, 40, 20], center = true);
            }
            sphere(d = 31);
        }
    }
}

module head_eyelid_upper_left() {
    head_eyelid_upper_right();
}

module head_eyelid_lower_right() {
    color("pink") {
        difference() {
            intersection() {
                sphere(d = 34);
                translate([0, 0, -8]) cube([40, 40, 12], center = true);
            }
            sphere(d = 31);
        }
    }
}

module head_eyelid_lower_left() {
    head_eyelid_lower_right();
}

module head_mouth_upper() {
    color("lightcoral") {
        difference() {
            resize([35, 10, 8])
                sphere(d = 20);
            translate([0, 0, -5]) cube([40, 15, 10], center = true);
        }
    }
}

module head_mouth_lower() {
    color("lightcoral") {
        difference() {
            resize([35, 12, 10])
                sphere(d = 20);
            translate([0, 0, 6]) cube([40, 15, 12], center = true);
        }
    }
}

module head_topknot() {
    // 基部
    color("black") {
        cylinder(h = 10, d = 15);

        // 髷本体
        translate([0, 0, 10]) {
            cylinder(h = 15, d = 12);

            translate([0, -5, 15])
                rotate([-45, 0, 0])
                    cylinder(h = 20, d1 = 12, d2 = 8);

            translate([0, -20, 30])
                sphere(d = 10);
        }
    }

    // 取り付け軸
    color("gray")
        translate([0, 0, -15])
            difference() {
                cylinder(h = 15, d = 8);
                cylinder(h = 16, d = 3);
            }
}

// =============================================================================
// 胴体パーツ
// =============================================================================

module body_torso_shell() {
    color("burlywood") {
        difference() {
            cylinder(h = 125, d1 = 85, d2 = 105);
            translate([0, 0, 3])
                cylinder(h = 125, d1 = 79, d2 = 99);
        }
    }

    // たが（バンド）
    color("saddlebrown") {
        for (z = [15, 62, 110]) {
            d = 85 + (105 - 85) * z / 125;
            translate([0, 0, z])
                difference() {
                    cylinder(h = 8, d = d + 3, center = true);
                    cylinder(h = 10, d = d - 3, center = true);
                }
        }
    }
}

module body_torso_frame() {
    color("lightgray") {
        difference() {
            cylinder(h = 120, d1 = 75, d2 = 95);
            translate([0, 0, 3])
                cylinder(h = 120, d1 = 69, d2 = 89);
            // 配線穴
            for (a = [0, 90, 180, 270])
                rotate([0, 0, a])
                    translate([30, 0, 60])
                        cylinder(h = 70, d = 10);
        }
    }
}

// =============================================================================
// 腕パーツ
// =============================================================================

module arm_upper_right() {
    color("white") {
        cylinder(h = 50, d = 25);
        translate([0, 0, 50]) sphere(d = 28);
    }
    color("gray")
        sphere(d = 20);
}

module arm_upper_left() {
    arm_upper_right();
}

module arm_lower_right() {
    color("white")
        cylinder(h = 45, d = 22);
    color("gray") {
        sphere(d = 18);
        translate([0, 0, 45]) sphere(d = 15);
    }
}

module arm_lower_left() {
    arm_lower_right();
}

module arm_hand_right() {
    color("pink") {
        // 手のひら
        scale([1, 0.6, 1.2]) sphere(d = 25);

        // 指
        for (i = [-1.5 : 1 : 1.5]) {
            translate([i * 5, 0, 12])
                cylinder(h = 15, d1 = 6, d2 = 4);
        }

        // 親指
        translate([12, 0, 0])
            rotate([0, 30, 0])
                cylinder(h = 12, d1 = 6, d2 = 4);
    }
}

module arm_hand_left() {
    mirror([1, 0, 0]) arm_hand_right();
}

// =============================================================================
// 脚パーツ
// =============================================================================

module leg_thigh_right() {
    color("white") {
        hull() {
            translate([0, 0, 5]) cube([35, 30, 10], center = true);
            translate([0, 0, 55]) cube([30, 25, 10], center = true);
        }
    }
    color("gray") {
        translate([0, 0, 60]) rotate([0, 90, 0])
            cylinder(h = 40, d = 25, center = true);
        rotate([0, 90, 0])
            cylinder(h = 35, d = 20, center = true);
    }
}

module leg_thigh_left() {
    leg_thigh_right();
}

module leg_shin_right() {
    color("white") {
        hull() {
            translate([0, 0, 5]) cube([30, 25, 10], center = true);
            translate([0, 0, 50]) cube([25, 20, 10], center = true);
        }
    }
    color("gray") {
        translate([0, 0, 55]) rotate([0, 90, 0])
            cylinder(h = 35, d = 20, center = true);
        rotate([0, 90, 0])
            cylinder(h = 30, d = 18, center = true);
    }
}

module leg_shin_left() {
    leg_shin_right();
}

module leg_foot_right() {
    color("white") {
        hull() {
            translate([15, 0, 10]) scale([1.5, 1, 0.4]) sphere(d = 45);
            translate([-10, 0, 10]) scale([0.8, 0.8, 0.4]) sphere(d = 40);
        }
        // 足首接続部
        translate([0, 0, 18])
            cylinder(h = 15, d = 22);
    }
}

module leg_foot_left() {
    mirror([1, 0, 0]) leg_foot_right();
}

module leg_foot_sole_right() {
    // TPU用（柔軟素材）
    color("dimgray") {
        translate([10, 0, 2])
            scale([1.4, 0.95, 0.15])
                sphere(d = 48);

        // 滑り止めパターン
        for (x = [-15 : 10 : 25]) {
            for (y = [-15 : 10 : 15]) {
                translate([x, y, 0])
                    cylinder(h = 2, d = 5, $fn = 6);
            }
        }
    }
}

module leg_foot_sole_left() {
    mirror([1, 0, 0]) leg_foot_sole_right();
}

// =============================================================================
// 刀パーツ
// =============================================================================

module sword_blade() {
    color("silver") {
        hull() {
            cube([15, 3, 5], center = true);
            translate([3, 0, 60]) cube([10, 2, 5], center = true);
            translate([5, 0, 80]) cube([3, 1, 1], center = true);
        }
    }
}

module sword_handle() {
    color("saddlebrown") {
        difference() {
            cylinder(h = 40, d1 = 12, d2 = 11);
            // 柄巻き溝
            for (z = [5 : 5 : 35]) {
                translate([0, 0, z])
                    rotate([0, 0, 45])
                        cube([15, 1, 2], center = true);
            }
        }
    }

    // 柄頭
    color("gold")
        translate([0, 0, 40])
            resize([14, 14, 8])
                sphere(d = 10);

    // 目貫
    color("gold")
        translate([6, 0, 20])
            sphere(d = 5);
}

module sword_guard() {
    color("darkgoldenrod") {
        difference() {
            resize([25, 20, 5])
                sphere(d = 20);
            cube([16, 4, 10], center = true);
        }
    }
}

module sword_sheath() {
    color("black") {
        difference() {
            hull() {
                resize([20, 18, 10]) sphere(d = 10);
                translate([0, 0, 140]) resize([18, 16, 10]) sphere(d = 10);
            }
            translate([0, 0, 5])
                hull() {
                    cube([16, 4, 10], center = true);
                    translate([0, 0, 130]) cube([14, 3, 10], center = true);
                }
        }
    }

    // 装飾リング
    color("gold") {
        for (z = [20, 70, 120]) {
            translate([0, 0, z])
                difference() {
                    d = 20 - z * 0.01;
                    resize([d + 3, d - 2 + 3, 5]) sphere(d = 10);
                    resize([d, d - 2, 10]) sphere(d = 10);
                }
        }
    }

    // 口金
    color("silver")
        difference() {
            resize([22, 20, 10]) sphere(d = 10);
            translate([0, 0, 5]) resize([20, 18, 15]) sphere(d = 10);
            translate([0, 0, -5]) cube([25, 25, 10], center = true);
        }
}

module sword_wheel() {
    color("dimgray") {
        difference() {
            rotate([90, 0, 0])
                cylinder(h = 8, d = 25, center = true);
            rotate([90, 0, 0])
                cylinder(h = 10, d = 4, center = true);
            // スポーク穴
            for (a = [0 : 60 : 300]) {
                rotate([90, 0, 0])
                    rotate([0, 0, a])
                        translate([8, 0, 0])
                            cylinder(h = 10, d = 5, center = true);
            }
        }
    }

    // タイヤ
    color("black")
        rotate([90, 0, 0])
            difference() {
                cylinder(h = 6, d = 28, center = true);
                cylinder(h = 8, d = 22, center = true);
            }
}

module sword_back_mount() {
    color("gray") {
        difference() {
            cube([40, 15, 30], center = true);
            // 鞘を通す穴
            resize([22, 20, 35]) sphere(d = 10);
            // ネジ穴
            for (x = [-15, 15]) {
                for (z = [-10, 10]) {
                    translate([x, 0, z])
                        rotate([90, 0, 0])
                            cylinder(h = 20, d = 3, center = true);
                }
            }
        }

        // クリップ
        translate([0, -10, 0])
            difference() {
                cube([24, 6, 25], center = true);
                resize([21, 10, 30]) sphere(d = 10);
            }
    }
}
