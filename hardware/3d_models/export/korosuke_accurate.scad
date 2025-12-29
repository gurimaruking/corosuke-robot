/**
 * コロ助ロボット - アニメ版忠実再現モデル
 * Korosuke Robot - Anime-Accurate Model
 *
 * キテレツ大百科のコロ助を忠実に再現
 *
 * 特徴:
 * - 頭部: ゴム毬風の真球
 * - 胴体: 風呂桶（木樽）+ たが（金属バンド）
 * - 腕: 掃除機ホース風の蛇腹構造
 * - 丁髷: ネギ坊主風の長い髷
 * - 目: 藤子キャラ特有の大きな白目＋小さな黒目
 * - 刀: 長い鞘＋先端に車輪
 *
 * 参考: 1/1スケールVCDフィギュア（全高350mm）
 * このモデル: 全高約150mm（スケーラブル）
 */

$fn = 80;  // 高品質レンダリング

// =============================================================================
// アニメ準拠カラーパレット
// =============================================================================
// 顔・肌
skin_color = "#FFE4C4";      // ビスク（肌色）
skin_color_light = "#FFF0E0"; // 明るい肌色（ハイライト用）

// 胴体（風呂桶）
tub_wood = "#DEB887";        // バーリーウッド（木目）
tub_band = "#8B4513";        // サドルブラウン（たが）
tub_band_metal = "#4A4A4A";  // 金属バンド

// 丁髷
hair_black = "#1A1A1A";      // 黒（少し明るめ）

// 目
eye_white = "#FFFFFF";
eye_black = "#000000";
eye_highlight = "#FFFFFF";

// 口
mouth_red = "#CC3333";       // 口の中

// 腕（ホース）
arm_cream = "#F5DEB3";       // 小麦色（クリーム）
arm_stripe = "#C4A882";      // 縞模様

// 脚
leg_blue = "#4169E1";        // ロイヤルブルー
foot_blue = "#4169E1";

// 刀
sword_red = "#B22222";       // 赤い鞘
sword_gold = "#FFD700";      // 金装飾
sword_brown = "#8B4513";     // 柄
sword_wheel = "#4682B4";     // 車輪

// =============================================================================
// スケール設定（全高約150mm）
// =============================================================================
scale_factor = 1.0;
head_diameter = 65 * scale_factor;
body_height = 55 * scale_factor;
body_top_diameter = 50 * scale_factor;
body_bottom_diameter = 42 * scale_factor;

// =============================================================================
// 頭部モジュール - ゴム毬風の真球
// =============================================================================
module korosuke_head() {
    // 基本の球形頭部
    color(skin_color) {
        sphere(d = head_diameter);
    }

    // 顔のパーツを配置
    korosuke_eyes();
    korosuke_nose();
    korosuke_mouth();
    korosuke_cheeks();
    korosuke_topknot();
}

// 藤子キャラ特有の目
module korosuke_eyes() {
    eye_y = -head_diameter * 0.42;  // 顔の前面
    eye_z = head_diameter * 0.08;   // 少し上寄り
    eye_spacing = head_diameter * 0.24;

    // 左右の目
    for (side = [-1, 1]) {
        translate([side * eye_spacing, eye_y, eye_z]) {
            rotate([90, 0, 0]) {
                // 白目（大きな楕円）
                color(eye_white) {
                    scale([1, 1.3, 1])
                        sphere(d = head_diameter * 0.28);
                }

                // 黒目（小さめ、中央やや下）
                translate([0, -2, -head_diameter * 0.08])
                    color(eye_black)
                        sphere(d = head_diameter * 0.13);

                // ハイライト（小さな白い点）
                translate([head_diameter * 0.03, -4, -head_diameter * 0.02])
                    color(eye_highlight)
                        sphere(d = head_diameter * 0.05);
            }
        }
    }
}

// 小さな丸い鼻
module korosuke_nose() {
    nose_y = -head_diameter * 0.48;
    nose_z = -head_diameter * 0.02;

    color("#E07070") {  // 少し赤みのある肌色
        translate([0, nose_y, nose_z])
            sphere(d = head_diameter * 0.08);
    }
}

// 口（への字または開いた口）
module korosuke_mouth() {
    mouth_y = -head_diameter * 0.44;
    mouth_z = -head_diameter * 0.18;

    // 口の輪郭（開いた口）
    color(mouth_red) {
        translate([0, mouth_y, mouth_z])
            rotate([80, 0, 0])
                scale([1.8, 1, 0.6])
                    sphere(d = head_diameter * 0.15);
    }
}

// ほっぺ（藤子キャラの特徴）
module korosuke_cheeks() {
    cheek_y = -head_diameter * 0.38;
    cheek_z = -head_diameter * 0.08;
    cheek_spacing = head_diameter * 0.32;

    color("#FFCCCC") {  // 薄いピンク
        for (side = [-1, 1]) {
            translate([side * cheek_spacing, cheek_y, cheek_z])
                scale([1, 0.6, 0.8])
                    sphere(d = head_diameter * 0.12);
        }
    }
}

// 丁髷（ちょんまげ）- ネギ坊主風
module korosuke_topknot() {
    topknot_z = head_diameter * 0.48;

    color(hair_black) {
        translate([0, 0, topknot_z]) {
            // 根元（頭皮から生えている部分）
            cylinder(h = 8, d1 = 14, d2 = 10);

            // 髷の束（上に伸びる）
            translate([0, 0, 6]) {
                // メインの束
                cylinder(h = 25, d1 = 10, d2 = 7);

                // 先端の丸い部分（ネギの頭風）
                translate([0, 0, 24])
                    sphere(d = 10);

                // 髪の毛の広がり
                for (angle = [0, 72, 144, 216, 288]) {
                    rotate([0, 12, angle])
                        translate([0, 0, 15])
                            cylinder(h = 12, d1 = 5, d2 = 2);
                }
            }

            // 髷を結んでいる紐（リボン風）
            translate([0, 0, 10])
                color("#6B4423")
                    rotate([0, 90, 0])
                        cylinder(h = 16, d = 3, center = true);
        }
    }
}

// =============================================================================
// 胴体モジュール - 風呂桶（木樽）
// =============================================================================
module korosuke_body() {
    // 木樽本体
    color(tub_wood) {
        difference() {
            // 外側の樽形状（下が少し細い）
            cylinder(h = body_height, d1 = body_bottom_diameter, d2 = body_top_diameter);

            // 内側をくり抜き（軽量化）
            translate([0, 0, 3])
                cylinder(h = body_height, d1 = body_bottom_diameter - 6, d2 = body_top_diameter - 6);
        }
    }

    // たが（金属バンド）- 3本
    color(tub_band) {
        for (z = [8, body_height/2, body_height - 8]) {
            band_d = body_bottom_diameter + (body_top_diameter - body_bottom_diameter) * (z / body_height);
            translate([0, 0, z])
                difference() {
                    cylinder(h = 4, d = band_d + 2, center = true);
                    cylinder(h = 6, d = band_d - 2, center = true);
                }
        }
    }

    // 木目の縦線（装飾）
    color("#C4A06A") {
        for (angle = [0 : 30 : 330]) {
            rotate([0, 0, angle])
                translate([body_bottom_diameter/2 - 1, 0, 0])
                    cube([1.5, 0.8, body_height - 2]);
        }
    }
}

// =============================================================================
// 腕モジュール - 掃除機ホース風の蛇腹
// =============================================================================
module korosuke_arm(is_right = true) {
    arm_length = 45;
    arm_segments = 8;
    segment_height = arm_length / arm_segments;

    mirror([is_right ? 0 : 1, 0, 0]) {
        // 蛇腹構造の腕
        for (i = [0 : arm_segments - 1]) {
            z = i * segment_height;
            segment_d = 12 - i * 0.3;  // 先に行くほど細く

            // 交互に色を変えて縞模様
            col = (i % 2 == 0) ? arm_cream : arm_stripe;

            color(col)
                translate([0, 0, z])
                    cylinder(h = segment_height * 0.9, d1 = segment_d, d2 = segment_d * 0.85);

            // 蛇腹のリング（溝）
            if (i < arm_segments - 1) {
                color(arm_stripe)
                    translate([0, 0, z + segment_height * 0.85])
                        cylinder(h = segment_height * 0.15, d = segment_d * 0.7);
            }
        }

        // 手（丸い）
        translate([0, 0, arm_length])
            korosuke_hand();
    }
}

// 手（ミトン風の丸い手）
module korosuke_hand() {
    color(skin_color) {
        // 手のひら
        scale([1, 0.7, 1.1])
            sphere(d = 18);

        // 親指
        translate([7, 0, 2])
            rotate([0, 20, 0])
                scale([0.6, 0.5, 1])
                    sphere(d = 10);
    }
}

// =============================================================================
// 脚モジュール
// =============================================================================
module korosuke_leg(is_right = true) {
    leg_length = 35;

    mirror([is_right ? 0 : 1, 0, 0]) {
        // 太もも
        color(leg_blue) {
            translate([0, 0, leg_length * 0.4])
                cylinder(h = leg_length * 0.6, d1 = 16, d2 = 14);
        }

        // すね
        color(leg_blue) {
            cylinder(h = leg_length * 0.45, d1 = 13, d2 = 15);
        }

        // 足
        translate([3, 0, 0])
            korosuke_foot();
    }
}

// 足（楕円形）
module korosuke_foot() {
    color(foot_blue) {
        translate([0, 0, -5])
            scale([1.4, 0.9, 0.45])
                sphere(d = 28);
    }
}

// =============================================================================
// 刀モジュール - 長い鞘＋車輪
// =============================================================================
module korosuke_sword() {
    sheath_length = 90;

    rotate([12, 0, 0]) {
        // 鞘（赤）
        color(sword_red) {
            difference() {
                // 外側
                hull() {
                    cylinder(h = 5, d = 12);
                    translate([0, 0, sheath_length - 5])
                        cylinder(h = 5, d = 9);
                }
                // 内側（刀を入れる部分）
                translate([0, 0, 8])
                    hull() {
                        cylinder(h = 5, d = 8);
                        translate([0, 0, sheath_length - 18])
                            cylinder(h = 5, d = 6);
                    }
            }
        }

        // 鞘の金装飾
        color(sword_gold) {
            // 上部
            translate([0, 0, 0])
                difference() {
                    cylinder(h = 6, d = 14);
                    translate([0, 0, -1])
                        cylinder(h = 8, d = 10);
                }

            // 中央
            translate([0, 0, sheath_length * 0.4])
                difference() {
                    cylinder(h = 4, d = 12);
                    translate([0, 0, -1])
                        cylinder(h = 6, d = 9);
                }

            // 下部
            translate([0, 0, sheath_length - 12])
                difference() {
                    cylinder(h = 4, d = 11);
                    translate([0, 0, -1])
                        cylinder(h = 6, d = 8);
                }
        }

        // 柄（茶色）
        color(sword_brown) {
            translate([0, 0, -25])
                cylinder(h = 28, d = 8);

            // 柄巻き
            for (z = [-22 : 4 : -2]) {
                translate([0, 0, z])
                    rotate([0, 0, z * 15])
                        difference() {
                            cylinder(h = 2, d = 9);
                            cylinder(h = 3, d = 6);
                        }
            }
        }

        // 鍔（つば）
        color(sword_gold) {
            translate([0, 0, -2])
                cylinder(h = 3, d = 16);
        }

        // 柄頭
        color(sword_gold) {
            translate([0, 0, -28])
                sphere(d = 10);
        }

        // 車輪（鞘の先端）
        translate([0, 0, sheath_length - 3]) {
            // 車輪本体
            color(sword_wheel) {
                rotate([90, 0, 0])
                    difference() {
                        cylinder(h = 6, d = 18, center = true);
                        cylinder(h = 8, d = 4, center = true);
                    }
            }

            // タイヤ（黒）
            color("#333333") {
                rotate([90, 0, 0])
                    difference() {
                        cylinder(h = 5, d = 20, center = true);
                        cylinder(h = 7, d = 16, center = true);
                    }
            }

            // スポーク
            color(sword_wheel) {
                rotate([90, 0, 0])
                    for (angle = [0 : 60 : 300]) {
                        rotate([0, 0, angle])
                            translate([5, 0, 0])
                                cylinder(h = 4, d = 2, center = true);
                    }
            }
        }
    }
}

// =============================================================================
// フルアセンブリ
// =============================================================================
module korosuke_full() {
    // 配置パラメータ
    body_z = 40;  // 胴体の高さ
    head_z = body_z + body_height + head_diameter * 0.35;  // 頭の高さ

    // 頭部
    translate([0, 0, head_z])
        korosuke_head();

    // 胴体
    translate([0, 0, body_z])
        korosuke_body();

    // 右腕
    translate([body_top_diameter/2 + 5, 0, body_z + body_height - 10])
        rotate([0, 45, 0])
            rotate([0, 0, -90])
                korosuke_arm(true);

    // 左腕
    translate([-(body_top_diameter/2 + 5), 0, body_z + body_height - 10])
        rotate([0, -45, 0])
            rotate([0, 0, 90])
                korosuke_arm(false);

    // 右脚
    translate([12, 0, body_z])
        rotate([0, 0, 0])
            korosuke_leg(true);

    // 左脚
    translate([-12, 0, body_z])
        rotate([0, 0, 0])
            korosuke_leg(false);

    // 刀（背中）
    translate([0, body_top_diameter/2 + 3, body_z + body_height/2])
        korosuke_sword();
}

// =============================================================================
// 個別パーツエクスポート用モジュール
// =============================================================================
module export_head() {
    korosuke_head();
}

module export_body() {
    korosuke_body();
}

module export_arm_right() {
    korosuke_arm(true);
}

module export_arm_left() {
    korosuke_arm(false);
}

module export_leg_right() {
    korosuke_leg(true);
}

module export_leg_left() {
    korosuke_leg(false);
}

module export_sword() {
    korosuke_sword();
}

// =============================================================================
// レンダリング（デフォルトでフルアセンブリ）
// =============================================================================
korosuke_full();
