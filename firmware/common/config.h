/**
 * コロ助ロボット - 共通設定
 * Corosuke Robot - Common Configuration
 */

#ifndef COROSUKE_CONFIG_H
#define COROSUKE_CONFIG_H

// =============================================================================
// バージョン情報
// =============================================================================
#define COROSUKE_VERSION_MAJOR 1
#define COROSUKE_VERSION_MINOR 0
#define COROSUKE_VERSION_PATCH 0

// =============================================================================
// WiFi設定
// =============================================================================
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// ホームサーバー設定
#define HOME_SERVER_IP "192.168.1.100"
#define HOME_SERVER_PORT 8080

// =============================================================================
// I2Cアドレス
// =============================================================================
#define I2C_ADDR_PCA9685_UPPER 0x40  // 上半身サーボドライバ
#define I2C_ADDR_PCA9685_LOWER 0x41  // 下半身サーボドライバ
#define I2C_ADDR_BNO055        0x28  // IMU
#define I2C_ADDR_MPU6050       0x68  // バックアップIMU

// =============================================================================
// サーボチャンネル割り当て - 上半身 (PCA9685 #1)
// =============================================================================
// 目
#define SERVO_EYE_RIGHT_H   0   // 右目 水平
#define SERVO_EYE_RIGHT_V   1   // 右目 垂直
#define SERVO_EYE_LEFT_H    2   // 左目 水平
#define SERVO_EYE_LEFT_V    3   // 左目 垂直
#define SERVO_EYELID_RIGHT  4   // 右まぶた
#define SERVO_EYELID_LEFT   5   // 左まぶた

// 口
#define SERVO_MOUTH_UPPER   6   // 口 上
#define SERVO_MOUTH_LOWER   7   // 口 下

// 首
#define SERVO_NECK_YAW      8   // 首 左右
#define SERVO_NECK_PITCH    9   // 首 上下

// 腕
#define SERVO_ARM_RIGHT_SHOULDER 10  // 右肩
#define SERVO_ARM_RIGHT_ELBOW    11  // 右肘
#define SERVO_ARM_LEFT_SHOULDER  12  // 左肩
#define SERVO_ARM_LEFT_ELBOW     13  // 左肘

// =============================================================================
// サーボチャンネル割り当て - 下半身 (PCA9685 #2)
// =============================================================================
#define SERVO_WAIST         0   // 腰

// 右脚
#define SERVO_LEG_RIGHT_HIP_YAW    1   // 右股関節 回転
#define SERVO_LEG_RIGHT_HIP_PITCH  2   // 右股関節 前後
#define SERVO_LEG_RIGHT_KNEE       3   // 右膝
#define SERVO_LEG_RIGHT_ANKLE      4   // 右足首

// 左脚
#define SERVO_LEG_LEFT_HIP_YAW     5   // 左股関節 回転
#define SERVO_LEG_LEFT_HIP_PITCH   6   // 左股関節 前後
#define SERVO_LEG_LEFT_KNEE        7   // 左膝
#define SERVO_LEG_LEFT_ANKLE       8   // 左足首

// =============================================================================
// サーボ角度制限
// =============================================================================
#define SERVO_MIN_PULSE     500   // 最小パルス幅 (μs)
#define SERVO_MAX_PULSE     2500  // 最大パルス幅 (μs)
#define SERVO_CENTER_ANGLE  90    // 中心角度

// 目の可動範囲
#define EYE_H_MIN   60
#define EYE_H_MAX   120
#define EYE_V_MIN   70
#define EYE_V_MAX   110
#define EYELID_OPEN   30
#define EYELID_CLOSE  120

// 口の可動範囲
#define MOUTH_CLOSED  90
#define MOUTH_OPEN    120

// 首の可動範囲
#define NECK_YAW_MIN    45
#define NECK_YAW_MAX    135
#define NECK_PITCH_MIN  70
#define NECK_PITCH_MAX  110

// =============================================================================
// LEDリング設定
// =============================================================================
#define LED_EYE_RIGHT_PIN   18
#define LED_EYE_LEFT_PIN    19
#define LED_EYE_NUM_LEDS    12
#define LED_BRIGHTNESS      50

// =============================================================================
// オーディオ設定
// =============================================================================
#define I2S_BCLK_PIN    4
#define I2S_LRCLK_PIN   5
#define I2S_DOUT_PIN    6
#define I2S_DIN_PIN     9

#define MIC_WS_PIN      7
#define MIC_SCK_PIN     8
#define MIC_SD_PIN      9

// =============================================================================
// UART設定 (ESP32間通信)
// =============================================================================
#define UART_BAUD_RATE  115200

// メイン ↔ 上半身
#define UART_MAIN_TX    1
#define UART_MAIN_RX    2

// 上半身 ↔ 下半身
#define UART_UPPER_TO_LOWER_TX  16
#define UART_UPPER_TO_LOWER_RX  17

// =============================================================================
// タイミング設定
// =============================================================================
#define SERVO_UPDATE_INTERVAL_MS    20   // サーボ更新間隔 (50Hz)
#define IMU_UPDATE_INTERVAL_MS      10   // IMU更新間隔 (100Hz)
#define EXPRESSION_UPDATE_MS        50   // 表情更新間隔
#define WALKING_CYCLE_MS           1000  // 歩行1サイクル時間

// =============================================================================
// バランス制御 PIDゲイン
// =============================================================================
#define BALANCE_KP  2.0f
#define BALANCE_KI  0.1f
#define BALANCE_KD  0.5f

#endif // COROSUKE_CONFIG_H
