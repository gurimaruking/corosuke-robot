/**
 * コロ助ロボット - パーツ別3MFエクスポート
 * Corosuke Robot - Individual Parts for 3MF Export
 *
 * カラーリング（アニメ版準拠）:
 * - 顔: クリーム/肌色 (#FFDAB9)
 * - 胴体: オレンジ (#FF8C00)
 * - 腕: ライトブルー縞 (#87CEEB)
 * - 脚: 青 (#4169E1)
 * - 丁髷: 黒
 * - 鼻: 赤
 * - ボタン: 赤・黄色
 *
 * 使い方:
 * 1. 出力したいパーツのコメントを外す
 * 2. File → Export → Export as 3MF
 */

$fn = 64;

// =============================================================================
// カラー定義（アニメ版コロ助準拠）
// =============================================================================
face_color = "#FFDAB9";        // 顔 - ピーチパフ/肌色
body_color = "#FF8C00";        // 胴体 - ダークオレンジ
arm_color = "#87CEEB";         // 腕 - スカイブルー
arm_stripe_color = "#4682B4";  // 腕の縞 - スチールブルー
leg_color = "#4169E1";         // 脚 - ロイヤルブルー
hand_color = "#FFDAB9";        // 手 - 肌色
nose_color = "#FF0000";        // 鼻 - 赤
button_red = "#FF0000";        // ボタン - 赤
button_yellow = "#FFD700";     // ボタン - 黄色
hair_color = "#000000";        // 丁髷 - 黒
eye_white = "#FFFFFF";         // 白目
eye_black = "#000000";         // 黒目
mouth_color = "#CC0000";       // 口の中 - 暗い赤
lip_color = "#FF6B6B";         // 唇 - 明るい赤
sword_sheath = "#CC0000";      // 鞘 - 赤（アニメ版）
wheel_color = "#1E90FF";       // 車輪 - 青

// =============================================================================
// 出力選択（使いたいパーツのコメントを外す）
// =============================================================================

// --- 頭部パーツ ---
//head_face_shell();
//head_eyeball_right();
//head_eyeball_left();
//head_nose();
head_topknot();
//head_mouth();

// --- 胴体パーツ ---
//body_torso_shell();
//body_buttons();

// --- 腕パーツ ---
//arm_right();
//arm_left();
//hand_right();
//hand_left();

// --- 脚パーツ ---
//leg_right();
//leg_left();
//foot_right();
//foot_left();

// --- 刀パーツ ---
//sword_full();
//sword_sheath_part();
//sword_wheel_part();

// --- フルアセンブリ ---
//corosuke_full();

// =============================================================================
// 頭部パーツ
// =============================================================================

module head_face_shell() {
    color(face_color) {
        difference() {
            // 丸い顔
            sphere(d = 120);
            // 内側をくり抜き
            sphere(d = 114);
            // 後ろをカット
            translate([0, 60, 0]) cube([150, 120, 150], center = true);
            // 目の穴（大きめの白目）
            translate([22, -50, 12]) rotate([90, 0, 0]) cylinder(h = 20, d = 35);
            translate([-22, -50, 12]) rotate([90, 0, 0]) cylinder(h = 20, d = 35);
            // 口の穴
            translate([0, -50, -20]) rotate([90, 0, 0])
                resize([50, 25, 20]) cylinder(h = 20, d = 30);
        }
    }
}

module head_eyeball_right() {
    // 白目（大きい楕円）
    color(eye_white) {
        scale([1, 0.8, 1.2])
            sphere(d = 32);
    }
    // 黒目（小さめ、少し上寄り）
    color(eye_black) {
        translate([0, -10, 3])
            sphere(d = 12);
    }
    // ハイライト
    color(eye_white) {
        translate([3, -14, 6])
            sphere(d = 4);
    }
}

module head_eyeball_left() {
    head_eyeball_right();
}

module head_nose() {
    // 赤くて丸い鼻
    color(nose_color) {
        sphere(d = 12);
    }
}

module head_topknot() {
    // 丁髷（黒）- コロ助の特徴的な短い髪
    color(hair_color) {
        // 根本
        cylinder(h = 8, d = 12);

        // 髪の毛の束（上に立つ）
        translate([0, 0, 8]) {
            // 中央の束
            cylinder(h = 18, d1 = 10, d2 = 6);

            // 先端を丸く
            translate([0, 0, 18])
                sphere(d = 8);

            // 少し広がった部分
            for (a = [0, 120, 240]) {
                rotate([0, 15, a])
                    cylinder(h = 12, d1 = 6, d2 = 3);
            }
        }
    }

    // 取り付け軸
    color("gray")
        translate([0, 0, -12])
            difference() {
                cylinder(h = 12, d = 8);
                cylinder(h = 14, d = 3);
            }
}

module head_mouth() {
    // 大きく開いた口
    color(mouth_color) {
        difference() {
            resize([45, 20, 22])
                sphere(d = 30);
            translate([0, 0, 12])
                cube([50, 25, 20], center = true);
        }
    }

    // 唇（赤い縁取り）
    color(lip_color) {
        difference() {
            resize([50, 22, 25])
                sphere(d = 30);
            resize([44, 18, 22])
                sphere(d = 30);
            translate([0, 0, -15])
                cube([55, 30, 30], center = true);
        }
    }
}

// =============================================================================
// 胴体パーツ
// =============================================================================

module body_torso_shell() {
    // オレンジ色の胴体
    color(body_color) {
        difference() {
            // 少し角丸の四角い胴体
            hull() {
                translate([0, 0, 10])
                    resize([80, 60, 20])
                        sphere(d = 50);
                translate([0, 0, 90])
                    resize([90, 65, 20])
                        sphere(d = 50);
            }
            // 内側をくり抜き
            hull() {
                translate([0, 0, 13])
                    resize([74, 54, 20])
                        sphere(d = 50);
                translate([0, 0, 87])
                    resize([84, 59, 20])
                        sphere(d = 50);
            }
        }
    }

    // ボタンを追加
    body_buttons();
}

module body_buttons() {
    // 赤いボタン（左右）
    color(button_red) {
        translate([30, -25, 70])
            sphere(d = 12);
        translate([-30, -25, 70])
            sphere(d = 12);
    }

    // 黄色いボタン（中央下）- オプション
    color(button_yellow) {
        translate([0, -28, 40])
            sphere(d = 10);
    }
}

// =============================================================================
// 腕パーツ（水色の縞模様）
// =============================================================================

module arm_right() {
    // 縞模様の腕
    arm_striped();
}

module arm_left() {
    mirror([1, 0, 0])
        arm_striped();
}

module arm_striped() {
    stripe_height = 8;
    arm_length = 50;

    for (i = [0 : stripe_height * 2 : arm_length]) {
        // 水色部分
        color(arm_color)
            translate([0, 0, i])
                cylinder(h = stripe_height, d1 = 18, d2 = 17);

        // 濃い青部分
        if (i + stripe_height < arm_length) {
            color(arm_stripe_color)
                translate([0, 0, i + stripe_height])
                    cylinder(h = stripe_height, d1 = 17, d2 = 16);
        }
    }

    // 肩の接続部（灰色）
    color("gray")
        translate([0, 0, arm_length])
            sphere(d = 20);
}

module hand_right() {
    // 肌色の丸い手
    color(hand_color) {
        sphere(d = 28);
    }
}

module hand_left() {
    hand_right();
}

// =============================================================================
// 脚パーツ（青色）
// =============================================================================

module leg_right() {
    leg_blue();
}

module leg_left() {
    mirror([1, 0, 0])
        leg_blue();
}

module leg_blue() {
    color(leg_color) {
        // 太ももから足まで一体型の青い脚
        hull() {
            translate([0, 0, 60])
                sphere(d = 30);
            translate([5, 0, 0])
                sphere(d = 35);
        }
    }
}

module foot_right() {
    // 青い楕円形の足
    color(leg_color) {
        scale([1.3, 0.8, 0.5])
            sphere(d = 40);
    }
}

module foot_left() {
    foot_right();
}

// =============================================================================
// 刀パーツ（赤い鞘、青い車輪）
// =============================================================================

module sword_full() {
    sword_sheath_part();

    translate([0, 0, -140])
        sword_wheel_part();

    // 柄
    color("saddlebrown")
        translate([0, 0, 10])
            cylinder(h = 35, d = 10);

    // 柄頭
    color("gold")
        translate([0, 0, 45])
            sphere(d = 12);
}

module sword_sheath_part() {
    // 赤い鞘（アニメ版）
    color(sword_sheath) {
        difference() {
            hull() {
                cylinder(h = 10, d = 18);
                translate([0, 0, 130])
                    cylinder(h = 10, d = 14);
            }
            // 内側
            translate([0, 0, 5])
                hull() {
                    cylinder(h = 10, d = 12);
                    translate([0, 0, 120])
                        cylinder(h = 10, d = 10);
                }
        }
    }

    // 金の装飾リング
    color("gold") {
        translate([0, 0, 5])
            difference() {
                cylinder(h = 6, d = 20);
                cylinder(h = 8, d = 16);
            }
        translate([0, 0, 60])
            difference() {
                cylinder(h = 5, d = 17);
                cylinder(h = 7, d = 14);
            }
    }
}

module sword_wheel_part() {
    // 青い車輪（アニメ版）
    color(wheel_color) {
        rotate([90, 0, 0])
            difference() {
                cylinder(h = 8, d = 25, center = true);
                cylinder(h = 10, d = 5, center = true);
            }
    }

    // タイヤ（黒）
    color("black")
        rotate([90, 0, 0])
            difference() {
                cylinder(h = 6, d = 28, center = true);
                cylinder(h = 8, d = 23, center = true);
            }
}

// =============================================================================
// フルアセンブリ
// =============================================================================

module corosuke_full() {
    // 頭部
    translate([0, 0, 220]) {
        head_face_shell();

        // 目
        translate([22, -55, 12])
            rotate([-10, 0, 0])
                head_eyeball_right();
        translate([-22, -55, 12])
            rotate([-10, 0, 0])
                head_eyeball_left();

        // 鼻
        translate([0, -58, -5])
            head_nose();

        // 口
        translate([0, -50, -22])
            rotate([90, 0, 0])
                head_mouth();

        // 丁髷
        translate([0, -10, 58])
            head_topknot();
    }

    // 胴体
    translate([0, 0, 110])
        body_torso_shell();

    // 右腕
    translate([55, 0, 180])
        rotate([0, 45, 0]) {
            arm_right();
            translate([0, 0, -15])
                hand_right();
        }

    // 左腕
    translate([-55, 0, 180])
        rotate([0, -45, 0]) {
            arm_left();
            translate([0, 0, -15])
                hand_left();
        }

    // 右脚
    translate([25, 0, 50])
        leg_right();
    translate([30, 0, 5])
        foot_right();

    // 左脚
    translate([-25, 0, 50])
        leg_left();
    translate([-30, 0, 5])
        foot_left();

    // 刀（背中）
    translate([0, 30, 160])
        rotate([15, 0, 0])
            sword_full();
}
