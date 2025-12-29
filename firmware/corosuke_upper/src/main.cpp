/**
 * コロ助ロボット - 上半身制御
 * Corosuke Robot - Upper Body Controller
 *
 * 機能:
 * - 目の制御（8軸: 左右上下 + まばたき）
 * - 口の制御（2軸: 上下）
 * - 首の制御（2軸: ヨー・ピッチ）
 * - 腕の制御（4軸: 肩・肘 x2）
 * - LED目の制御（WS2812B）
 * - リップシンク
 */

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <FastLED.h>

// 共通ヘッダー
#include "../../common/config.h"
#include "../../common/protocol.h"

// =============================================================================
// グローバル変数
// =============================================================================

// サーボドライバ
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(I2C_ADDR_PCA9685_UPPER);

// LED目
CRGB ledsRight[LED_EYE_NUM_LEDS];
CRGB ledsLeft[LED_EYE_NUM_LEDS];

// サーボ現在位置
uint8_t servoPositions[16];

// 表情状態
Expression_t currentExpression = EXPR_NEUTRAL;
uint8_t blinkCounter = 0;
bool isBlinking = false;

// 口の状態
uint8_t mouthOpenAmount = 0;
bool isSpeaking = false;

// タイミング
unsigned long lastServoUpdate = 0;
unsigned long lastBlinkCheck = 0;
unsigned long lastExpressionUpdate = 0;

// UART受信バッファ
uint8_t uartBuffer[PACKET_MAX_SIZE];
uint8_t uartIndex = 0;

// =============================================================================
// 関数プロトタイプ
// =============================================================================
void initServos();
void initLEDs();
void setServoAngle(uint8_t channel, uint8_t angle);
void setEyePosition(int8_t x, int8_t y);
void setBlink(bool closed);
void setMouthOpen(uint8_t amount);
void setExpression(Expression_t expr);
void updateIdleAnimation();
void processCommand(uint8_t cmd, uint8_t* data, uint8_t length);
void handleUART();
void updateLEDEyes();

// =============================================================================
// セットアップ
// =============================================================================
void setup() {
    // シリアル初期化
    Serial.begin(115200);
    Serial.println("=================================");
    Serial.println("  コロ助 上半身コントローラー");
    Serial.println("  Corosuke Upper Body v1.0");
    Serial.println("=================================");

    // メインボードとのUART
    Serial1.begin(UART_BAUD_RATE, SERIAL_8N1, 4, 5);  // RX=4, TX=5

    // 下半身ボードとのUART
    Serial2.begin(UART_BAUD_RATE, SERIAL_8N1, UART_UPPER_TO_LOWER_RX, UART_UPPER_TO_LOWER_TX);

    // I2C初期化
    Wire.begin();

    // サーボ初期化
    initServos();

    // LED初期化
    initLEDs();

    // 初期姿勢
    setExpression(EXPR_NEUTRAL);

    Serial.println("初期化完了ナリ！");
}

// =============================================================================
// メインループ
// =============================================================================
void loop() {
    unsigned long now = millis();

    // UART受信処理
    handleUART();

    // サーボ更新 (50Hz)
    if (now - lastServoUpdate >= SERVO_UPDATE_INTERVAL_MS) {
        lastServoUpdate = now;
        // スムーズな動きのための補間処理があればここに
    }

    // まばたき処理 (ランダム間隔)
    if (now - lastBlinkCheck >= 100) {
        lastBlinkCheck = now;
        blinkCounter++;

        // 約3-5秒ごとにまばたき
        if (!isBlinking && blinkCounter > random(30, 50)) {
            isBlinking = true;
            setBlink(true);
            blinkCounter = 0;
        } else if (isBlinking && blinkCounter > 2) {
            isBlinking = false;
            setBlink(false);
            blinkCounter = 0;
        }
    }

    // アイドルアニメーション
    if (now - lastExpressionUpdate >= EXPRESSION_UPDATE_MS) {
        lastExpressionUpdate = now;
        updateIdleAnimation();
        updateLEDEyes();
    }
}

// =============================================================================
// サーボ初期化
// =============================================================================
void initServos() {
    pwm.begin();
    pwm.setPWMFreq(50);  // 50Hz for servos

    delay(10);

    // 全サーボを中心位置に
    for (int i = 0; i < 16; i++) {
        servoPositions[i] = SERVO_CENTER_ANGLE;
        setServoAngle(i, SERVO_CENTER_ANGLE);
    }

    // まぶたを開く
    setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN);
    setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN);

    Serial.println("サーボ初期化完了");
}

// =============================================================================
// LED初期化
// =============================================================================
void initLEDs() {
    FastLED.addLeds<WS2812B, LED_EYE_RIGHT_PIN, GRB>(ledsRight, LED_EYE_NUM_LEDS);
    FastLED.addLeds<WS2812B, LED_EYE_LEFT_PIN, GRB>(ledsLeft, LED_EYE_NUM_LEDS);
    FastLED.setBrightness(LED_BRIGHTNESS);

    // 初期色（黒目の色）
    fill_solid(ledsRight, LED_EYE_NUM_LEDS, CRGB::Black);
    fill_solid(ledsLeft, LED_EYE_NUM_LEDS, CRGB::Black);

    // 瞳のハイライト
    ledsRight[0] = CRGB::White;
    ledsLeft[0] = CRGB::White;

    FastLED.show();

    Serial.println("LED初期化完了");
}

// =============================================================================
// サーボ角度設定
// =============================================================================
void setServoAngle(uint8_t channel, uint8_t angle) {
    if (channel >= 16 || angle > 180) return;

    // 角度をパルス幅に変換
    uint16_t pulse = map(angle, 0, 180, SERVO_MIN_PULSE, SERVO_MAX_PULSE);
    // パルス幅を12ビット値に変換 (4096段階、20ms周期)
    uint16_t pwmValue = (uint16_t)((pulse * 4096L) / 20000L);

    pwm.setPWM(channel, 0, pwmValue);
    servoPositions[channel] = angle;
}

// =============================================================================
// 目の位置設定
// =============================================================================
void setEyePosition(int8_t x, int8_t y) {
    // x: -50〜50 (左〜右)
    // y: -50〜50 (下〜上)

    uint8_t hAngle = map(constrain(x, -50, 50), -50, 50, EYE_H_MIN, EYE_H_MAX);
    uint8_t vAngle = map(constrain(y, -50, 50), -50, 50, EYE_V_MIN, EYE_V_MAX);

    // 両目を同じ方向に
    setServoAngle(SERVO_EYE_RIGHT_H, hAngle);
    setServoAngle(SERVO_EYE_LEFT_H, hAngle);
    setServoAngle(SERVO_EYE_RIGHT_V, vAngle);
    setServoAngle(SERVO_EYE_LEFT_V, vAngle);
}

// =============================================================================
// まばたき
// =============================================================================
void setBlink(bool closed) {
    uint8_t angle = closed ? EYELID_CLOSE : EYELID_OPEN;
    setServoAngle(SERVO_EYELID_RIGHT, angle);
    setServoAngle(SERVO_EYELID_LEFT, angle);
}

// =============================================================================
// 口の開閉
// =============================================================================
void setMouthOpen(uint8_t amount) {
    // amount: 0-100
    mouthOpenAmount = constrain(amount, 0, 100);

    uint8_t angle = map(mouthOpenAmount, 0, 100, MOUTH_CLOSED, MOUTH_OPEN);
    setServoAngle(SERVO_MOUTH_LOWER, angle);
    // 上唇は固定か、少し動かす
    setServoAngle(SERVO_MOUTH_UPPER, MOUTH_CLOSED - (angle - MOUTH_CLOSED) / 3);
}

// =============================================================================
// 表情設定
// =============================================================================
void setExpression(Expression_t expr) {
    currentExpression = expr;

    switch (expr) {
        case EXPR_NEUTRAL:
            setEyePosition(0, 0);
            setBlink(false);
            setMouthOpen(0);
            break;

        case EXPR_HAPPY:
            setEyePosition(0, 10);
            // まぶたを少し下げて笑顔に
            setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN + 20);
            setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN + 20);
            setMouthOpen(30);
            break;

        case EXPR_SAD:
            setEyePosition(0, -20);
            setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN + 30);
            setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN + 30);
            setMouthOpen(10);
            break;

        case EXPR_SURPRISED:
            setEyePosition(0, 20);
            // まぶた全開
            setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN - 10);
            setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN - 10);
            setMouthOpen(80);
            break;

        case EXPR_ANGRY:
            setEyePosition(0, -10);
            // まぶたを下げて怒り顔
            setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN + 40);
            setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN + 40);
            setMouthOpen(20);
            break;

        case EXPR_SLEEPY:
            setEyePosition(0, -30);
            setServoAngle(SERVO_EYELID_RIGHT, EYELID_OPEN + 50);
            setServoAngle(SERVO_EYELID_LEFT, EYELID_OPEN + 50);
            setMouthOpen(10);
            break;

        case EXPR_THINKING:
            setEyePosition(30, 20);  // 右上を見る
            setBlink(false);
            setMouthOpen(5);
            break;

        case EXPR_EXCITED:
            setEyePosition(0, 15);
            setBlink(false);
            setMouthOpen(50);
            break;

        default:
            break;
    }

    Serial.print("表情変更: ");
    Serial.println(expr);
}

// =============================================================================
// アイドルアニメーション
// =============================================================================
void updateIdleAnimation() {
    static int8_t idleEyeX = 0;
    static int8_t idleEyeY = 0;
    static uint8_t idleCounter = 0;

    if (!isSpeaking && currentExpression == EXPR_NEUTRAL) {
        idleCounter++;

        // たまに視線を動かす
        if (idleCounter > random(50, 100)) {
            idleEyeX = random(-20, 20);
            idleEyeY = random(-10, 10);
            setEyePosition(idleEyeX, idleEyeY);
            idleCounter = 0;
        }
    }
}

// =============================================================================
// LED目の更新
// =============================================================================
void updateLEDEyes() {
    // 表情に応じてLEDの色を変更
    CRGB eyeColor = CRGB::Black;

    switch (currentExpression) {
        case EXPR_HAPPY:
        case EXPR_EXCITED:
            eyeColor = CRGB(255, 200, 100);  // 暖かい色
            break;
        case EXPR_SAD:
            eyeColor = CRGB(100, 100, 255);  // 青っぽい
            break;
        case EXPR_ANGRY:
            eyeColor = CRGB(255, 50, 50);    // 赤
            break;
        default:
            eyeColor = CRGB(200, 200, 200);  // 白
            break;
    }

    // 瞳のハイライト以外を設定
    for (int i = 1; i < LED_EYE_NUM_LEDS; i++) {
        ledsRight[i] = eyeColor;
        ledsLeft[i] = eyeColor;
    }

    // ハイライトは常に白
    ledsRight[0] = CRGB::White;
    ledsLeft[0] = CRGB::White;

    FastLED.show();
}

// =============================================================================
// UART受信処理
// =============================================================================
void handleUART() {
    // メインボードからの受信
    while (Serial1.available()) {
        uint8_t b = Serial1.read();

        if (uartIndex == 0 && b != PACKET_START) {
            continue;  // スタートバイトを待つ
        }

        uartBuffer[uartIndex++] = b;

        // パケット完成チェック
        if (uartIndex >= 4) {
            uint8_t expectedLen = uartBuffer[1] + 4;  // length + header(2) + checksum + end
            if (uartIndex >= expectedLen) {
                if (uartBuffer[uartIndex - 1] == PACKET_END) {
                    // パケット受信完了
                    if (validatePacket(uartBuffer, uartIndex)) {
                        processCommand(uartBuffer[2], &uartBuffer[3], uartBuffer[1] - 1);
                    }
                }
                uartIndex = 0;
            }
        }

        if (uartIndex >= PACKET_MAX_SIZE) {
            uartIndex = 0;  // オーバーフロー防止
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
            // PONGを返す
            Serial.println("PING受信 - PONG送信");
            break;

        case CMD_EXPRESSION: {
            if (length >= sizeof(ExpressionData_t)) {
                ExpressionData_t* exprData = (ExpressionData_t*)data;
                setExpression((Expression_t)exprData->expression_id);
            }
            break;
        }

        case CMD_EYE_POSITION: {
            if (length >= sizeof(EyePositionData_t)) {
                EyePositionData_t* eyeData = (EyePositionData_t*)data;
                setEyePosition(eyeData->x, eyeData->y);
            }
            break;
        }

        case CMD_BLINK:
            setBlink(data[0] != 0);
            break;

        case CMD_MOUTH_OPEN: {
            if (length >= sizeof(MouthData_t)) {
                MouthData_t* mouthData = (MouthData_t*)data;
                setMouthOpen(mouthData->open_amount);
            }
            break;
        }

        case CMD_LIPSYNC_DATA:
            // リップシンクデータ（音量に応じて口を動かす）
            if (length >= 1) {
                isSpeaking = true;
                setMouthOpen(data[0]);
            }
            break;

        case CMD_SPEAK_STOP:
            isSpeaking = false;
            setMouthOpen(0);
            break;

        case CMD_LOOK_AT: {
            // 注視点への視線移動
            if (length >= 2) {
                int8_t x = (int8_t)data[0];
                int8_t y = (int8_t)data[1];
                setEyePosition(x, y);
            }
            break;
        }

        case CMD_WAVE:
            // 手を振るモーション（簡易実装）
            Serial.println("手を振るナリ！");
            for (int i = 0; i < 3; i++) {
                setServoAngle(SERVO_ARM_RIGHT_SHOULDER, 45);
                delay(300);
                setServoAngle(SERVO_ARM_RIGHT_SHOULDER, 135);
                delay(300);
            }
            setServoAngle(SERVO_ARM_RIGHT_SHOULDER, 90);
            break;

        default:
            Serial.print("未知のコマンド: 0x");
            Serial.println(cmd, HEX);
            break;
    }
}
