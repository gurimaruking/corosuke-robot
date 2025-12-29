/**
 * コロ助ロボット - 目の機構
 * Corosuke Robot - Eye Mechanism
 *
 * オラフロボットを参考にしたアニマトロニクス目機構
 * - 左右・上下の視線移動
 * - まばたき機能
 * - SG90サーボ使用
 */

// =============================================================================
// パラメータ
// =============================================================================

// 眼球サイズ
eye_diameter = 30;           // 眼球直径
eye_radius = eye_diameter / 2;

// サーボサイズ (SG90)
servo_width = 12.5;
servo_height = 22.5;
servo_depth = 23;
servo_shaft_height = 4;
servo_horn_length = 15;

// 機構サイズ
mechanism_width = 80;        // 両目を含む幅
mechanism_height = 50;
mechanism_depth = 60;

// 間隔
eye_spacing = 40;            // 目の間隔（中心間）

// ボールリンク
ball_link_diameter = 3;
pushrod_diameter = 1.5;

// 公差
tolerance = 0.3;

// =============================================================================
// モジュール: 眼球
// =============================================================================
module eyeball() {
    difference() {
        // 球体
        sphere(d = eye_diameter, $fn = 64);

        // 後ろ側をカット（取り付け用）
        translate([0, 0, -eye_radius])
            cylinder(h = eye_radius, d = eye_diameter + 1, $fn = 64);

        // 取り付け軸穴
        translate([0, 0, -5])
            cylinder(h = 20, d = 4, $fn = 32);
    }

    // 取り付け軸
    translate([0, 0, -8])
        difference() {
            cylinder(h = 10, d = 6, $fn = 32);
            cylinder(h = 12, d = 3, $fn = 32);  // M3ネジ穴
        }
}

// =============================================================================
// モジュール: まぶた
// =============================================================================
module eyelid(is_upper = true) {
    lid_thickness = 2;
    lid_width = eye_diameter + 4;
    lid_height = eye_diameter / 2 + 2;

    difference() {
        // 半球シェル
        intersection() {
            sphere(d = eye_diameter + 4, $fn = 64);

            if (is_upper) {
                translate([-lid_width/2, -lid_width/2, 0])
                    cube([lid_width, lid_width, lid_width]);
            } else {
                translate([-lid_width/2, -lid_width/2, -lid_width])
                    cube([lid_width, lid_width, lid_width]);
            }
        }

        // 内側をくり抜き
        sphere(d = eye_diameter + 2, $fn = 64);

        // ヒンジ穴
        rotate([0, 90, 0])
            cylinder(h = lid_width + 10, d = 2.5, center = true, $fn = 32);
    }

    // ヒンジ取り付け部
    translate([lid_width/2 + 2, 0, 0])
        rotate([0, 90, 0])
            difference() {
                cylinder(h = 5, d = 6, $fn = 32);
                cylinder(h = 6, d = 2.5, $fn = 32);
            }
}

// =============================================================================
// モジュール: サーボ（SG90参考モデル）
// =============================================================================
module sg90_servo() {
    color("blue") {
        // メインボディ
        translate([-servo_width/2, -servo_depth/2, 0])
            cube([servo_width, servo_depth, servo_height]);

        // マウントフランジ
        translate([-(servo_width + 10)/2, -servo_depth/2, servo_height - 2])
            cube([servo_width + 10, servo_depth, 2.5]);

        // シャフト部分
        translate([0, servo_depth/2 - 6, servo_height])
            cylinder(h = servo_shaft_height, d = 5, $fn = 32);
    }
}

// =============================================================================
// モジュール: 目のジンバル機構
// =============================================================================
module eye_gimbal() {
    gimbal_size = eye_diameter + 10;

    // 外側リング（水平軸）
    difference() {
        cylinder(h = 8, d = gimbal_size, center = true, $fn = 64);
        cylinder(h = 10, d = gimbal_size - 6, center = true, $fn = 64);

        // 軸穴
        rotate([0, 90, 0])
            cylinder(h = gimbal_size + 10, d = 3, center = true, $fn = 32);
    }

    // 内側リング（垂直軸）
    rotate([0, 90, 0])
        difference() {
            cylinder(h = 6, d = gimbal_size - 8, center = true, $fn = 64);
            cylinder(h = 8, d = gimbal_size - 14, center = true, $fn = 64);

            // 軸穴
            rotate([0, 90, 0])
                cylinder(h = gimbal_size, d = 3, center = true, $fn = 32);
        }
}

// =============================================================================
// モジュール: 目の機構フレーム
// =============================================================================
module eye_mechanism_frame() {
    frame_thickness = 3;

    difference() {
        // メインフレーム
        translate([-mechanism_width/2, -mechanism_depth/2, 0])
            cube([mechanism_width, mechanism_depth, mechanism_height]);

        // 目の穴（左）
        translate([-eye_spacing/2, 0, mechanism_height/2])
            rotate([90, 0, 0])
                cylinder(h = mechanism_depth + 10, d = eye_diameter + 6, center = true, $fn = 64);

        // 目の穴（右）
        translate([eye_spacing/2, 0, mechanism_height/2])
            rotate([90, 0, 0])
                cylinder(h = mechanism_depth + 10, d = eye_diameter + 6, center = true, $fn = 64);

        // 内部をくり抜き
        translate([-(mechanism_width - frame_thickness*2)/2, -(mechanism_depth - frame_thickness*2)/2, frame_thickness])
            cube([mechanism_width - frame_thickness*2, mechanism_depth - frame_thickness*2, mechanism_height]);

        // サーボマウント穴
        // 右目水平サーボ
        translate([mechanism_width/2 - 5, 0, mechanism_height/2])
            rotate([0, 90, 0])
                cylinder(h = 20, d = 3, center = true, $fn = 32);

        // 右目垂直サーボ
        translate([eye_spacing/2, mechanism_depth/2 - 5, mechanism_height/2 + 15])
            cylinder(h = 20, d = 3, center = true, $fn = 32);
    }
}

// =============================================================================
// モジュール: サーボホーン with ボールリンク
// =============================================================================
module servo_horn_with_link() {
    // ホーン
    hull() {
        cylinder(h = 2, d = 6, $fn = 32);
        translate([servo_horn_length, 0, 0])
            cylinder(h = 2, d = 4, $fn = 32);
    }

    // ボールリンク取り付け部
    translate([servo_horn_length, 0, 0])
        cylinder(h = 4, d = ball_link_diameter + 2, $fn = 32);
}

// =============================================================================
// モジュール: 完全な目ユニット（片目）
// =============================================================================
module single_eye_unit() {
    // 眼球
    color("white")
        eyeball();

    // ジンバル
    color("gray")
        eye_gimbal();

    // 上まぶた
    color("pink", 0.8)
        translate([0, 0, 2])
            eyelid(true);

    // 下まぶた（小さめ）
    color("pink", 0.8)
        translate([0, 0, -2])
            scale([1, 1, 0.5])
                eyelid(false);
}

// =============================================================================
// モジュール: まぶたサーボマウント
// =============================================================================
module eyelid_servo_mount() {
    mount_width = 20;
    mount_height = 30;
    mount_depth = 15;

    difference() {
        cube([mount_width, mount_depth, mount_height]);

        // サーボ穴
        translate([mount_width/2, mount_depth/2, mount_height - servo_height/2])
            rotate([90, 0, 0])
                translate([-servo_width/2 - tolerance, -servo_depth/2 - tolerance, -mount_depth/2])
                    cube([servo_width + tolerance*2, servo_depth + tolerance*2, mount_depth]);

        // ネジ穴
        translate([mount_width/2, mount_depth/2, mount_height - servo_height - 5])
            cylinder(h = 10, d = 3, $fn = 32);
    }
}

// =============================================================================
// 組み立てビュー
// =============================================================================
module assembly() {
    // フレーム
    color("lightgray", 0.5)
        eye_mechanism_frame();

    // 右目
    translate([eye_spacing/2, 0, mechanism_height/2])
        rotate([-90, 0, 0])
            single_eye_unit();

    // 左目
    translate([-eye_spacing/2, 0, mechanism_height/2])
        rotate([-90, 0, 0])
            single_eye_unit();

    // 右目水平サーボ
    translate([mechanism_width/2 + 5, 0, mechanism_height/2])
        rotate([0, -90, 0])
            sg90_servo();

    // 左目水平サーボ
    translate([-mechanism_width/2 - 5, 0, mechanism_height/2])
        rotate([0, 90, 0])
            sg90_servo();

    // 右まぶたサーボ
    translate([eye_spacing/2 + 20, -mechanism_depth/2 + 10, mechanism_height - 5])
        rotate([90, 0, 0])
            sg90_servo();

    // 左まぶたサーボ
    translate([-eye_spacing/2 - 20, -mechanism_depth/2 + 10, mechanism_height - 5])
        rotate([90, 0, 0])
            sg90_servo();
}

// =============================================================================
// 出力選択
// =============================================================================

// 組み立てビュー表示
assembly();

// 個別パーツのエクスポート用（コメントを外して使用）
// eyeball();
// eyelid(true);
// eyelid(false);
// eye_gimbal();
// eye_mechanism_frame();
// eyelid_servo_mount();
// servo_horn_with_link();
