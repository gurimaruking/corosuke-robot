/**
 * コロ助ロボット - 刀（アクセサリー）
 * Corosuke Robot - Sword Accessory
 *
 * コロ助の背中に背負う刀
 * - アニメ版準拠のデザイン
 * - 鞘の先端に車輪（原作設定）
 * - 3Dプリント用に最適化
 */

// =============================================================================
// パラメータ
// =============================================================================

// 全体サイズ
total_length = 200;          // 鞘を含む全長

// 刀身
blade_length = 80;           // 刀身の長さ（短め - 原作設定）
blade_width = 15;
blade_thickness = 3;

// 柄（つか）
handle_length = 40;
handle_width = 12;
handle_depth = 15;

// 鍔（つば）
guard_diameter = 25;
guard_thickness = 5;

// 鞘（さや）
sheath_length = 150;
sheath_width = 20;
sheath_depth = 18;
sheath_thickness = 2;

// 鞘先端の車輪
wheel_diameter = 25;
wheel_width = 8;

// 背中マウント
mount_width = 40;
mount_height = 30;
mount_depth = 15;

// =============================================================================
// モジュール: 刀身
// =============================================================================
module blade() {
    color("silver") {
        // 刀身本体
        hull() {
            // 根本
            translate([0, 0, 0])
                cube([blade_width, blade_thickness, 5], center = true);

            // 中間
            translate([0, 0, blade_length * 0.7])
                cube([blade_width * 0.8, blade_thickness * 0.8, 5], center = true);

            // 先端（切っ先）
            translate([blade_width * 0.2, 0, blade_length])
                cube([blade_width * 0.3, blade_thickness * 0.5, 1], center = true);
        }

        // 刃の稜線（装飾）
        translate([0, blade_thickness/2 - 0.5, blade_length/2])
            cube([blade_width * 0.6, 0.5, blade_length * 0.9], center = true);
    }
}

// =============================================================================
// モジュール: 柄
// =============================================================================
module handle() {
    color("saddlebrown") {
        difference() {
            // 柄本体
            hull() {
                translate([0, 0, 0])
                    cube([handle_width, handle_depth, 5], center = true);
                translate([0, 0, -handle_length + 5])
                    cube([handle_width * 0.9, handle_depth * 0.9, 5], center = true);
            }

            // 柄巻きの溝（装飾）
            for (z = [0 : 5 : handle_length]) {
                translate([0, 0, -z])
                    rotate([0, 0, 45])
                        cube([handle_width * 1.5, 1, 2], center = true);
            }
        }
    }

    // 柄頭（かしら）
    color("gold")
        translate([0, 0, -handle_length])
            resize([handle_width + 2, handle_depth + 2, 8])
                sphere(d = 10, $fn = 32);

    // 目貫（めぬき）- 装飾
    color("gold")
        translate([handle_width/2, 0, -handle_length/2])
            sphere(d = 5, $fn = 16);
}

// =============================================================================
// モジュール: 鍔
// =============================================================================
module guard() {
    color("darkgoldenrod") {
        difference() {
            // 鍔本体（楕円形）
            resize([guard_diameter, guard_diameter * 0.8, guard_thickness])
                sphere(d = guard_diameter, $fn = 32);

            // 刀身が通る穴
            cube([blade_width + 1, blade_thickness + 1, guard_thickness + 2], center = true);
        }
    }
}

// =============================================================================
// モジュール: 鞘
// =============================================================================
module sheath() {
    color("black") {
        difference() {
            // 外側
            hull() {
                translate([0, 0, 0])
                    resize([sheath_width, sheath_depth, 10])
                        sphere(d = 10, $fn = 32);
                translate([0, 0, sheath_length - 10])
                    resize([sheath_width * 0.9, sheath_depth * 0.9, 10])
                        sphere(d = 10, $fn = 32);
            }

            // 内側（刀身が入る空間）
            translate([0, 0, 5])
                hull() {
                    cube([blade_width + 2, blade_thickness + 2, 10], center = true);
                    translate([0, 0, sheath_length - 20])
                        cube([blade_width, blade_thickness, 10], center = true);
                }
        }
    }

    // 鞘の装飾リング
    color("gold") {
        for (z = [20, sheath_length/2, sheath_length - 30]) {
            translate([0, 0, z])
                difference() {
                    resize([sheath_width + 3, sheath_depth + 3, 5])
                        sphere(d = 10, $fn = 32);
                    resize([sheath_width, sheath_depth, 10])
                        sphere(d = 10, $fn = 32);
                }
        }
    }

    // 鞘の口金（こじり）
    color("silver")
        translate([0, 0, 0])
            difference() {
                resize([sheath_width + 2, sheath_depth + 2, 10])
                    sphere(d = 10, $fn = 32);
                translate([0, 0, 5])
                    resize([sheath_width, sheath_depth, 15])
                        sphere(d = 10, $fn = 32);
                translate([0, 0, -5])
                    cube([sheath_width + 5, sheath_depth + 5, 10], center = true);
            }
}

// =============================================================================
// モジュール: 車輪（鞘先端）
// =============================================================================
module sheath_wheel() {
    color("darkgray") {
        difference() {
            // ホイール
            rotate([90, 0, 0])
                cylinder(h = wheel_width, d = wheel_diameter, center = true, $fn = 32);

            // 軸穴
            rotate([90, 0, 0])
                cylinder(h = wheel_width + 2, d = 4, center = true, $fn = 32);

            // スポーク穴（装飾）
            for (angle = [0 : 60 : 300]) {
                rotate([90, 0, 0])
                    rotate([0, 0, angle])
                        translate([wheel_diameter/4, 0, 0])
                            cylinder(h = wheel_width + 2, d = 5, center = true, $fn = 16);
            }
        }
    }

    // タイヤ部分
    color("black")
        rotate([90, 0, 0])
            difference() {
                cylinder(h = wheel_width - 2, d = wheel_diameter + 3, center = true, $fn = 32);
                cylinder(h = wheel_width, d = wheel_diameter - 2, center = true, $fn = 32);
            }
}

// =============================================================================
// モジュール: 背中マウント
// =============================================================================
module back_mount() {
    color("gray") {
        difference() {
            // ベースプレート
            cube([mount_width, mount_depth, mount_height], center = true);

            // 鞘を通す穴
            translate([0, 0, 0])
                resize([sheath_width + 2, sheath_depth + 2, mount_height + 2])
                    sphere(d = 10, $fn = 32);

            // 取り付けネジ穴
            for (x = [-mount_width/2 + 5, mount_width/2 - 5]) {
                for (z = [-mount_height/2 + 5, mount_height/2 - 5]) {
                    translate([x, 0, z])
                        rotate([90, 0, 0])
                            cylinder(h = mount_depth + 2, d = 3, center = true, $fn = 32);
                }
            }
        }

        // クリップ部分
        translate([0, -mount_depth/2 - 3, 0])
            difference() {
                cube([sheath_width + 10, 6, mount_height - 5], center = true);
                resize([sheath_width + 1, 10, mount_height])
                    sphere(d = 10, $fn = 32);
            }
    }
}

// =============================================================================
// モジュール: 完全な刀（組み立て状態）
// =============================================================================
module complete_sword() {
    // 刀身
    translate([0, 0, guard_thickness/2])
        blade();

    // 鍔
    guard();

    // 柄
    translate([0, 0, -guard_thickness/2])
        handle();
}

// =============================================================================
// モジュール: 鞘に収めた状態
// =============================================================================
module sword_in_sheath() {
    // 鞘
    translate([0, 0, -sheath_length])
        sheath();

    // 車輪
    translate([0, 0, -sheath_length - wheel_diameter/2 + 5])
        sheath_wheel();

    // 刀の柄（鞘から出ている部分）
    translate([0, 0, -guard_thickness/2])
        handle();

    // 鍔
    guard();
}

// =============================================================================
// モジュール: 背中に装着した状態
// =============================================================================
module sword_on_back() {
    // 背中マウント
    translate([0, 0, -30])
        back_mount();

    // 鞘に収めた刀
    rotate([15, 0, 0])  // 少し斜めに
        sword_in_sheath();
}

// =============================================================================
// 出力
// =============================================================================

// 背中装着状態
sword_on_back();

// 個別パーツ出力用
// blade();
// handle();
// guard();
// sheath();
// sheath_wheel();
// back_mount();
// complete_sword();
// sword_in_sheath();
