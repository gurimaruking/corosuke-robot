/**
 * コロ助ロボット - 下半身制御
 * Corosuke Robot - Lower Body Controller
 *
 * 機能:
 * - 腰の制御（1軸）
 * - 脚の制御（8軸: 股関節・膝・足首 x2）
 * - IMUによるバランス制御
 * - 二足歩行パターン生成
 */

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <Adafruit_BNO055.h>
#include <Adafruit_Sensor.h>

// 共通ヘッダー
#include "../../common/config.h"
#include "../../common/protocol.h"

// =============================================================================
// グローバル変数
// =============================================================================

// サーボドライバ
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(I2C_ADDR_PCA9685_LOWER);

// IMU
Adafruit_BNO055 bno = Adafruit_BNO055(55, I2C_ADDR_BNO055);

// サーボ現在位置・目標位置
float servoCurrentPos[16];
float servoTargetPos[16];

// 歩行状態
WalkMode_t walkMode = WALK_STOP;
uint8_t walkSpeed = 50;
float walkPhase = 0.0f;
bool isWalking = false;

// バランス制御
float pitchAngle = 0.0f;
float rollAngle = 0.0f;
float yawAngle = 0.0f;

// PID制御用
float pitchError = 0.0f, pitchErrorSum = 0.0f, pitchErrorPrev = 0.0f;
float rollError = 0.0f, rollErrorSum = 0.0f, rollErrorPrev = 0.0f;

// タイミング
unsigned long lastServoUpdate = 0;
unsigned long lastIMUUpdate = 0;
unsigned long lastWalkUpdate = 0;

// UART受信バッファ
uint8_t uartBuffer[PACKET_MAX_SIZE];
uint8_t uartIndex = 0;

// =============================================================================
// 歩行パラメータ
// =============================================================================
#define WALK_STEP_HEIGHT     20.0f   // 足を上げる高さ（度）
#define WALK_STEP_LENGTH     15.0f   // 歩幅（度）
#define WALK_SWAY_AMOUNT     10.0f   // 左右の揺れ（度）
#define WALK_CYCLE_SPEED     0.005f  // 歩行サイクル速度

// =============================================================================
// 関数プロトタイプ
// =============================================================================
void initServos();
void initIMU();
void setServoAngle(uint8_t channel, float angle);
void updateServos();
void updateIMU();
void updateBalance();
void updateWalking();
void generateGait();
void processCommand(uint8_t cmd, uint8_t* data, uint8_t length);
void handleUART();
void standUp();
void sitDown();

// =============================================================================
// セットアップ
// =============================================================================
void setup() {
    // シリアル初期化
    Serial.begin(115200);
    Serial.println("=================================");
    Serial.println("  コロ助 下半身コントローラー");
    Serial.println("  Corosuke Lower Body v1.0");
    Serial.println("=================================");

    // 上半身ボードとのUART
    Serial2.begin(UART_BAUD_RATE, SERIAL_8N1, UART_UPPER_TO_LOWER_RX, UART_UPPER_TO_LOWER_TX);

    // I2C初期化
    Wire.begin();

    // サーボ初期化
    initServos();

    // IMU初期化
    initIMU();

    // 初期姿勢（直立）
    standUp();

    Serial.println("初期化完了ナリ！");
}

// =============================================================================
// メインループ
// =============================================================================
void loop() {
    unsigned long now = millis();

    // UART受信処理
    handleUART();

    // IMU更新 (100Hz)
    if (now - lastIMUUpdate >= IMU_UPDATE_INTERVAL_MS) {
        lastIMUUpdate = now;
        updateIMU();

        if (isWalking) {
            updateBalance();
        }
    }

    // 歩行更新
    if (isWalking && now - lastWalkUpdate >= 10) {
        lastWalkUpdate = now;
        updateWalking();
    }

    // サーボ更新 (50Hz)
    if (now - lastServoUpdate >= SERVO_UPDATE_INTERVAL_MS) {
        lastServoUpdate = now;
        updateServos();
    }
}

// =============================================================================
// サーボ初期化
// =============================================================================
void initServos() {
    pwm.begin();
    pwm.setPWMFreq(50);

    delay(10);

    // 全サーボを中心位置に
    for (int i = 0; i < 16; i++) {
        servoCurrentPos[i] = SERVO_CENTER_ANGLE;
        servoTargetPos[i] = SERVO_CENTER_ANGLE;
    }

    Serial.println("サーボ初期化完了");
}

// =============================================================================
// IMU初期化
// =============================================================================
void initIMU() {
    if (!bno.begin()) {
        Serial.println("BNO055が見つからないナリ！MPU6050にフォールバック...");
        // TODO: MPU6050フォールバック実装
    } else {
        Serial.println("BNO055初期化完了");
        bno.setExtCrystalUse(true);
    }
}

// =============================================================================
// サーボ角度設定（即座に適用）
// =============================================================================
void setServoAngle(uint8_t channel, float angle) {
    if (channel >= 16) return;

    angle = constrain(angle, 0, 180);

    uint16_t pulse = map((int)angle, 0, 180, SERVO_MIN_PULSE, SERVO_MAX_PULSE);
    uint16_t pwmValue = (uint16_t)((pulse * 4096L) / 20000L);

    pwm.setPWM(channel, 0, pwmValue);
    servoCurrentPos[channel] = angle;
}

// =============================================================================
// サーボ位置更新（スムーズ補間）
// =============================================================================
void updateServos() {
    for (int i = 0; i < 16; i++) {
        if (abs(servoCurrentPos[i] - servoTargetPos[i]) > 0.5f) {
            // 線形補間
            float diff = servoTargetPos[i] - servoCurrentPos[i];
            float step = diff * 0.2f;  // 20%ずつ近づく

            servoCurrentPos[i] += step;
            setServoAngle(i, servoCurrentPos[i]);
        }
    }
}

// =============================================================================
// IMU更新
// =============================================================================
void updateIMU() {
    sensors_event_t event;
    bno.getEvent(&event);

    // オイラー角取得
    pitchAngle = event.orientation.y;
    rollAngle = event.orientation.z;
    yawAngle = event.orientation.x;
}

// =============================================================================
// バランス制御（PID）
// =============================================================================
void updateBalance() {
    // ピッチ制御（前後）
    pitchError = 0.0f - pitchAngle;
    pitchErrorSum += pitchError;
    pitchErrorSum = constrain(pitchErrorSum, -100.0f, 100.0f);
    float pitchD = pitchError - pitchErrorPrev;
    pitchErrorPrev = pitchError;

    float pitchCorrection = BALANCE_KP * pitchError +
                            BALANCE_KI * pitchErrorSum +
                            BALANCE_KD * pitchD;

    // ロール制御（左右）
    rollError = 0.0f - rollAngle;
    rollErrorSum += rollError;
    rollErrorSum = constrain(rollErrorSum, -100.0f, 100.0f);
    float rollD = rollError - rollErrorPrev;
    rollErrorPrev = rollError;

    float rollCorrection = BALANCE_KP * rollError +
                           BALANCE_KI * rollErrorSum +
                           BALANCE_KD * rollD;

    // 足首に補正を適用
    servoTargetPos[SERVO_LEG_RIGHT_ANKLE] += pitchCorrection * 0.5f;
    servoTargetPos[SERVO_LEG_LEFT_ANKLE] += pitchCorrection * 0.5f;

    // 制限をかける
    servoTargetPos[SERVO_LEG_RIGHT_ANKLE] = constrain(servoTargetPos[SERVO_LEG_RIGHT_ANKLE], 60, 120);
    servoTargetPos[SERVO_LEG_LEFT_ANKLE] = constrain(servoTargetPos[SERVO_LEG_LEFT_ANKLE], 60, 120);
}

// =============================================================================
// 歩行更新
// =============================================================================
void updateWalking() {
    if (walkMode == WALK_STOP) {
        isWalking = false;
        standUp();
        return;
    }

    // 歩行フェーズを進める
    float speedFactor = walkSpeed / 100.0f;
    walkPhase += WALK_CYCLE_SPEED * speedFactor;
    if (walkPhase >= 1.0f) {
        walkPhase -= 1.0f;
    }

    generateGait();
}

// =============================================================================
// 歩行パターン生成（簡易ペンギン歩き）
// =============================================================================
void generateGait() {
    float phase = walkPhase * 2.0f * PI;

    // 左右の足の位相差は180度
    float rightPhase = phase;
    float leftPhase = phase + PI;

    // 足を上げる動作（サイン波）
    float rightLift = max(0.0f, sin(rightPhase)) * WALK_STEP_HEIGHT;
    float leftLift = max(0.0f, sin(leftPhase)) * WALK_STEP_HEIGHT;

    // 前後の動作（コサイン波）
    float rightSwing = cos(rightPhase) * WALK_STEP_LENGTH;
    float leftSwing = cos(leftPhase) * WALK_STEP_LENGTH;

    // 体の左右の揺れ（重心移動）
    float bodySway = sin(phase) * WALK_SWAY_AMOUNT;

    // 方向に応じて調整
    float directionFactor = 1.0f;
    if (walkMode == WALK_BACKWARD) {
        directionFactor = -1.0f;
    }

    // 右脚
    servoTargetPos[SERVO_LEG_RIGHT_HIP_PITCH] = 90 + rightSwing * directionFactor;
    servoTargetPos[SERVO_LEG_RIGHT_KNEE] = 90 + rightLift;
    servoTargetPos[SERVO_LEG_RIGHT_ANKLE] = 90 - rightLift * 0.5f;
    servoTargetPos[SERVO_LEG_RIGHT_HIP_YAW] = 90 + bodySway;

    // 左脚
    servoTargetPos[SERVO_LEG_LEFT_HIP_PITCH] = 90 + leftSwing * directionFactor;
    servoTargetPos[SERVO_LEG_LEFT_KNEE] = 90 + leftLift;
    servoTargetPos[SERVO_LEG_LEFT_ANKLE] = 90 - leftLift * 0.5f;
    servoTargetPos[SERVO_LEG_LEFT_HIP_YAW] = 90 - bodySway;

    // 腰は揺れに合わせて少し回転
    servoTargetPos[SERVO_WAIST] = 90 + bodySway * 0.3f;

    // 旋回の場合
    if (walkMode == WALK_TURN_LEFT) {
        servoTargetPos[SERVO_LEG_RIGHT_HIP_YAW] += 10;
        servoTargetPos[SERVO_LEG_LEFT_HIP_YAW] += 10;
    } else if (walkMode == WALK_TURN_RIGHT) {
        servoTargetPos[SERVO_LEG_RIGHT_HIP_YAW] -= 10;
        servoTargetPos[SERVO_LEG_LEFT_HIP_YAW] -= 10;
    }
}

// =============================================================================
// 直立姿勢
// =============================================================================
void standUp() {
    Serial.println("直立ナリ！");

    servoTargetPos[SERVO_WAIST] = 90;

    // 右脚
    servoTargetPos[SERVO_LEG_RIGHT_HIP_YAW] = 90;
    servoTargetPos[SERVO_LEG_RIGHT_HIP_PITCH] = 90;
    servoTargetPos[SERVO_LEG_RIGHT_KNEE] = 90;
    servoTargetPos[SERVO_LEG_RIGHT_ANKLE] = 90;

    // 左脚
    servoTargetPos[SERVO_LEG_LEFT_HIP_YAW] = 90;
    servoTargetPos[SERVO_LEG_LEFT_HIP_PITCH] = 90;
    servoTargetPos[SERVO_LEG_LEFT_KNEE] = 90;
    servoTargetPos[SERVO_LEG_LEFT_ANKLE] = 90;
}

// =============================================================================
// 座る姿勢
// =============================================================================
void sitDown() {
    Serial.println("座るナリ！");

    // 膝を曲げて座る
    servoTargetPos[SERVO_LEG_RIGHT_HIP_PITCH] = 45;
    servoTargetPos[SERVO_LEG_RIGHT_KNEE] = 45;
    servoTargetPos[SERVO_LEG_LEFT_HIP_PITCH] = 45;
    servoTargetPos[SERVO_LEG_LEFT_KNEE] = 45;
}

// =============================================================================
// UART受信処理
// =============================================================================
void handleUART() {
    while (Serial2.available()) {
        uint8_t b = Serial2.read();

        if (uartIndex == 0 && b != PACKET_START) {
            continue;
        }

        uartBuffer[uartIndex++] = b;

        if (uartIndex >= 4) {
            uint8_t expectedLen = uartBuffer[1] + 4;
            if (uartIndex >= expectedLen) {
                if (uartBuffer[uartIndex - 1] == PACKET_END) {
                    if (validatePacket(uartBuffer, uartIndex)) {
                        processCommand(uartBuffer[2], &uartBuffer[3], uartBuffer[1] - 1);
                    }
                }
                uartIndex = 0;
            }
        }

        if (uartIndex >= PACKET_MAX_SIZE) {
            uartIndex = 0;
        }
    }
}

// =============================================================================
// コマンド処理
// =============================================================================
void processCommand(uint8_t cmd, uint8_t* data, uint8_t length) {
    Serial.print("コマンド受信: 0x");
    Serial.println(cmd, HEX);

    switch (cmd) {
        case CMD_PING:
            Serial.println("PING受信");
            break;

        case CMD_WALK_START: {
            Serial.println("歩行開始ナリ！");
            isWalking = true;
            walkMode = WALK_FORWARD;
            walkPhase = 0.0f;
            break;
        }

        case CMD_WALK_STOP:
            Serial.println("歩行停止ナリ！");
            walkMode = WALK_STOP;
            isWalking = false;
            standUp();
            break;

        case CMD_WALK_DIRECTION: {
            if (length >= sizeof(WalkData_t)) {
                WalkData_t* walkData = (WalkData_t*)data;
                walkMode = (WalkMode_t)walkData->mode;
                walkSpeed = walkData->speed;
                Serial.print("歩行モード: ");
                Serial.println(walkMode);
            }
            break;
        }

        case CMD_STAND:
            isWalking = false;
            standUp();
            break;

        case CMD_SIT:
            isWalking = false;
            sitDown();
            break;

        case CMD_TURN: {
            if (length >= 1) {
                int8_t direction = (int8_t)data[0];
                if (direction < 0) {
                    walkMode = WALK_TURN_LEFT;
                } else {
                    walkMode = WALK_TURN_RIGHT;
                }
                isWalking = true;
            }
            break;
        }

        default:
            Serial.print("未知のコマンド: 0x");
            Serial.println(cmd, HEX);
            break;
    }
}
