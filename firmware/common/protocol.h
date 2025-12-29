/**
 * コロ助ロボット - ESP32間通信プロトコル
 * Corosuke Robot - Inter-ESP32 Communication Protocol
 */

#ifndef COROSUKE_PROTOCOL_H
#define COROSUKE_PROTOCOL_H

#include <stdint.h>

// =============================================================================
// パケット構造
// =============================================================================
// [START][LENGTH][CMD][DATA...][CHECKSUM][END]
//   0xAA   1byte  1byte  N bytes   1byte   0x55

#define PACKET_START    0xAA
#define PACKET_END      0x55
#define PACKET_MAX_SIZE 64

// =============================================================================
// コマンド定義
// =============================================================================

// システムコマンド (0x00-0x0F)
#define CMD_PING            0x00    // 疎通確認
#define CMD_PONG            0x01    // 疎通応答
#define CMD_STATUS          0x02    // ステータス要求
#define CMD_STATUS_RESP     0x03    // ステータス応答
#define CMD_ERROR           0x0F    // エラー通知

// 表情コマンド (0x10-0x1F) - メイン→上半身
#define CMD_EXPRESSION      0x10    // 表情設定
#define CMD_EYE_POSITION    0x11    // 目の位置
#define CMD_BLINK           0x12    // まばたき
#define CMD_MOUTH_OPEN      0x13    // 口の開閉度

// 音声コマンド (0x20-0x2F) - メイン→上半身
#define CMD_SPEAK_START     0x20    // 発話開始
#define CMD_SPEAK_STOP      0x21    // 発話停止
#define CMD_LIPSYNC_DATA    0x22    // リップシンクデータ
#define CMD_PLAY_AUDIO      0x23    // 音声ファイル再生

// 動作コマンド (0x30-0x3F) - 上半身→下半身
#define CMD_WALK_START      0x30    // 歩行開始
#define CMD_WALK_STOP       0x31    // 歩行停止
#define CMD_WALK_DIRECTION  0x32    // 歩行方向
#define CMD_TURN            0x33    // 旋回
#define CMD_STAND           0x34    // 直立
#define CMD_SIT             0x35    // 座る

// 腕コマンド (0x40-0x4F) - メイン→上半身
#define CMD_ARM_POSITION    0x40    // 腕の位置
#define CMD_WAVE            0x41    // 手を振る
#define CMD_POINT           0x42    // 指差し

// センサーデータ (0x50-0x5F) - 下半身→上半身
#define CMD_IMU_DATA        0x50    // IMUデータ
#define CMD_BALANCE_STATUS  0x51    // バランス状態

// カメラ/AI (0x60-0x6F) - メイン→上半身
#define CMD_PERSON_DETECTED 0x60    // 人物検知
#define CMD_FACE_POSITION   0x61    // 顔の位置
#define CMD_LOOK_AT         0x62    // 注視点設定

// =============================================================================
// 表情ID
// =============================================================================
typedef enum {
    EXPR_NEUTRAL = 0,       // 通常
    EXPR_HAPPY,             // 嬉しい
    EXPR_SAD,               // 悲しい
    EXPR_SURPRISED,         // 驚き
    EXPR_ANGRY,             // 怒り
    EXPR_SLEEPY,            // 眠い
    EXPR_THINKING,          // 考え中
    EXPR_EXCITED,           // ワクワク
    EXPR_COUNT
} Expression_t;

// =============================================================================
// 歩行モード
// =============================================================================
typedef enum {
    WALK_STOP = 0,
    WALK_FORWARD,
    WALK_BACKWARD,
    WALK_LEFT,
    WALK_RIGHT,
    WALK_TURN_LEFT,
    WALK_TURN_RIGHT
} WalkMode_t;

// =============================================================================
// パケット構造体
// =============================================================================
#pragma pack(push, 1)

typedef struct {
    uint8_t start;
    uint8_t length;
    uint8_t cmd;
    uint8_t data[PACKET_MAX_SIZE - 5];
    // checksum and end are calculated/added during send
} Packet_t;

// 表情パケットデータ
typedef struct {
    uint8_t expression_id;
    uint8_t intensity;      // 0-100
    uint16_t duration_ms;
} ExpressionData_t;

// 目の位置パケットデータ
typedef struct {
    int8_t x;       // -50 to 50 (左右)
    int8_t y;       // -50 to 50 (上下)
    uint8_t speed;  // 0-100
} EyePositionData_t;

// 口の開閉パケットデータ
typedef struct {
    uint8_t open_amount;    // 0-100
} MouthData_t;

// 歩行コマンドデータ
typedef struct {
    uint8_t mode;           // WalkMode_t
    uint8_t speed;          // 0-100
    int8_t direction;       // -90 to 90 度
} WalkData_t;

// IMUデータ
typedef struct {
    int16_t pitch;          // ピッチ角 x100
    int16_t roll;           // ロール角 x100
    int16_t yaw;            // ヨー角 x100
    int16_t accel_x;        // 加速度X x100
    int16_t accel_y;        // 加速度Y x100
    int16_t accel_z;        // 加速度Z x100
} ImuData_t;

// 人物検知データ
typedef struct {
    uint8_t detected;       // 0 or 1
    int16_t x;              // 画面上のX座標
    int16_t y;              // 画面上のY座標
    uint16_t size;          // 検出サイズ
} PersonData_t;

#pragma pack(pop)

// =============================================================================
// ユーティリティ関数（インライン）
// =============================================================================

static inline uint8_t calculateChecksum(const uint8_t* data, uint8_t length) {
    uint8_t sum = 0;
    for (uint8_t i = 0; i < length; i++) {
        sum ^= data[i];
    }
    return sum;
}

static inline bool validatePacket(const uint8_t* buffer, uint8_t size) {
    if (size < 5) return false;
    if (buffer[0] != PACKET_START) return false;
    if (buffer[size - 1] != PACKET_END) return false;

    uint8_t checksum = calculateChecksum(&buffer[1], size - 3);
    return checksum == buffer[size - 2];
}

#endif // COROSUKE_PROTOCOL_H
