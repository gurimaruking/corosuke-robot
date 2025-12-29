/**
 * コロ助ロボット - メインコントローラー
 * Corosuke Robot - Main Controller (ESP32-S3-CAM)
 *
 * 機能:
 * - WiFi接続・ホームサーバー通信
 * - カメラによる人物検知
 * - 音声入力（マイク）
 * - 音声出力（スピーカー）
 * - LLM/VOICEVOX連携
 * - 上半身・下半身への指令送信
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "esp_camera.h"
#include "Audio.h"

// 共通ヘッダー
#include "../../common/config.h"
#include "../../common/protocol.h"

// =============================================================================
// カメラピン定義 (ESP32-S3-CAM)
// =============================================================================
#define PWDN_GPIO_NUM     -1
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM     10
#define SIOD_GPIO_NUM     40
#define SIOC_GPIO_NUM     39
#define Y9_GPIO_NUM       48
#define Y8_GPIO_NUM       11
#define Y7_GPIO_NUM       12
#define Y6_GPIO_NUM       14
#define Y5_GPIO_NUM       16
#define Y4_GPIO_NUM       18
#define Y3_GPIO_NUM       17
#define Y2_GPIO_NUM       15
#define VSYNC_GPIO_NUM    38
#define HREF_GPIO_NUM     47
#define PCLK_GPIO_NUM     13

// =============================================================================
// グローバル変数
// =============================================================================

// WiFi状態
bool wifiConnected = false;

// オーディオ
Audio audio;

// 人物検知
bool personDetected = false;
int personX = 0;
int personY = 0;

// 会話状態
bool isListening = false;
bool isSpeaking = false;
String lastUserMessage = "";
String lastResponse = "";

// タイミング
unsigned long lastPersonCheck = 0;
unsigned long lastIdleAction = 0;

// =============================================================================
// 関数プロトタイプ
// =============================================================================
void initWiFi();
void initCamera();
void initAudio();
void checkForPerson();
void sendCommandToUpper(uint8_t cmd, uint8_t* data, uint8_t length);
void handleWebCommand();
String sendToLLM(String message);
void speakWithVoicevox(String text);
void updateLipsync(uint8_t amplitude);
void performIdleAction();

// =============================================================================
// セットアップ
// =============================================================================
void setup() {
    Serial.begin(115200);
    Serial.println("=================================");
    Serial.println("  コロ助 メインコントローラー");
    Serial.println("  Corosuke Main v1.0");
    Serial.println("=================================");

    // 上半身ボードとのUART
    Serial1.begin(UART_BAUD_RATE, SERIAL_8N1, UART_MAIN_RX, UART_MAIN_TX);

    // WiFi初期化
    initWiFi();

    // カメラ初期化
    initCamera();

    // オーディオ初期化
    initAudio();

    Serial.println("ワガハイはコロ助ナリ！初期化完了ナリ！");

    // 起動メッセージを話す
    // speakWithVoicevox("ワガハイはコロ助ナリ！よろしくナリ！");
}

// =============================================================================
// メインループ
// =============================================================================
void loop() {
    unsigned long now = millis();

    // オーディオ処理
    audio.loop();

    // 人物検知 (1秒ごと)
    if (now - lastPersonCheck >= 1000) {
        lastPersonCheck = now;
        checkForPerson();
    }

    // アイドル動作 (10秒ごと)
    if (!isSpeaking && !isListening && now - lastIdleAction >= 10000) {
        lastIdleAction = now;
        performIdleAction();
    }

    // シリアルからのデバッグコマンド
    if (Serial.available()) {
        String cmd = Serial.readStringUntil('\n');
        cmd.trim();
        handleDebugCommand(cmd);
    }
}

// =============================================================================
// WiFi初期化
// =============================================================================
void initWiFi() {
    Serial.print("WiFi接続中...");
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(500);
        Serial.print(".");
        attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
        wifiConnected = true;
        Serial.println();
        Serial.print("WiFi接続完了！ IP: ");
        Serial.println(WiFi.localIP());
    } else {
        Serial.println();
        Serial.println("WiFi接続失敗ナリ...");
    }
}

// =============================================================================
// カメラ初期化
// =============================================================================
void initCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size = FRAMESIZE_QVGA;  // 320x240
    config.jpeg_quality = 12;
    config.fb_count = 1;
    config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("カメラ初期化失敗: 0x%x\n", err);
    } else {
        Serial.println("カメラ初期化完了");
    }
}

// =============================================================================
// オーディオ初期化
// =============================================================================
void initAudio() {
    audio.setPinout(I2S_BCLK_PIN, I2S_LRCLK_PIN, I2S_DOUT_PIN);
    audio.setVolume(15);  // 0-21

    Serial.println("オーディオ初期化完了");
}

// =============================================================================
// 人物検知（簡易版 - 実際はEdge Impulseなどを使用）
// =============================================================================
void checkForPerson() {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) {
        return;
    }

    // TODO: 実際の人物検知ロジック
    // ここでは簡易的に画像の中心部の輝度変化で検知する例
    // 実際の実装ではEdge Impulseモデルを使用

    // 仮の検知ロジック
    bool detected = false;
    int centerX = 160;
    int centerY = 120;

    if (detected && !personDetected) {
        // 新しく人を検知
        personDetected = true;
        Serial.println("人を検知したナリ！");

        // 上半身に通知
        PersonData_t personData;
        personData.detected = 1;
        personData.x = centerX;
        personData.y = centerY;
        personData.size = 100;
        sendCommandToUpper(CMD_PERSON_DETECTED, (uint8_t*)&personData, sizeof(personData));

        // 視線を向ける
        int8_t lookX = map(centerX, 0, 320, -50, 50);
        int8_t lookY = map(centerY, 0, 240, 50, -50);
        uint8_t lookData[2] = {(uint8_t)lookX, (uint8_t)lookY};
        sendCommandToUpper(CMD_LOOK_AT, lookData, 2);
    }

    esp_camera_fb_return(fb);
}

// =============================================================================
// 上半身ボードへコマンド送信
// =============================================================================
void sendCommandToUpper(uint8_t cmd, uint8_t* data, uint8_t length) {
    uint8_t packet[PACKET_MAX_SIZE];
    uint8_t idx = 0;

    packet[idx++] = PACKET_START;
    packet[idx++] = length + 1;  // cmd + data
    packet[idx++] = cmd;

    for (int i = 0; i < length; i++) {
        packet[idx++] = data[i];
    }

    uint8_t checksum = calculateChecksum(&packet[1], idx - 1);
    packet[idx++] = checksum;
    packet[idx++] = PACKET_END;

    Serial1.write(packet, idx);
}

// =============================================================================
// LLMへメッセージ送信
// =============================================================================
String sendToLLM(String message) {
    if (!wifiConnected) {
        return "WiFiに接続されていないナリ...";
    }

    HTTPClient http;
    String url = String("http://") + HOME_SERVER_IP + ":" + HOME_SERVER_PORT + "/chat";

    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<512> doc;
    doc["message"] = message;
    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);
    String response = "";

    if (httpCode == HTTP_CODE_OK) {
        String payload = http.getString();
        StaticJsonDocument<1024> resDoc;
        deserializeJson(resDoc, payload);
        response = resDoc["response"].as<String>();
    } else {
        response = "サーバーに接続できないナリ...";
        Serial.printf("HTTP Error: %d\n", httpCode);
    }

    http.end();
    return response;
}

// =============================================================================
// VOICEVOXで発話
// =============================================================================
void speakWithVoicevox(String text) {
    if (!wifiConnected) {
        Serial.println("WiFiに接続されていないナリ...");
        return;
    }

    isSpeaking = true;

    // サーバーにテキストを送信し、音声URLを取得
    HTTPClient http;
    String url = String("http://") + HOME_SERVER_IP + ":" + HOME_SERVER_PORT + "/speak";

    http.begin(url);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<512> doc;
    doc["text"] = text;
    String requestBody;
    serializeJson(doc, requestBody);

    int httpCode = http.POST(requestBody);

    if (httpCode == HTTP_CODE_OK) {
        String payload = http.getString();
        StaticJsonDocument<256> resDoc;
        deserializeJson(resDoc, payload);
        String audioUrl = resDoc["audio_url"].as<String>();

        // 音声を再生
        audio.connecttohost(audioUrl.c_str());

        // 発話開始を上半身に通知
        uint8_t dummy = 0;
        sendCommandToUpper(CMD_SPEAK_START, &dummy, 1);
    } else {
        Serial.printf("VOICEVOX Error: %d\n", httpCode);
    }

    http.end();
}

// =============================================================================
// リップシンク更新
// =============================================================================
void updateLipsync(uint8_t amplitude) {
    uint8_t mouthOpen = map(amplitude, 0, 255, 0, 100);
    sendCommandToUpper(CMD_LIPSYNC_DATA, &mouthOpen, 1);
}

// =============================================================================
// アイドル動作
// =============================================================================
void performIdleAction() {
    static int actionIndex = 0;

    switch (actionIndex % 5) {
        case 0: {
            // 周りを見回す
            int8_t x = random(-30, 30);
            int8_t y = random(-20, 20);
            uint8_t lookData[2] = {(uint8_t)x, (uint8_t)y};
            sendCommandToUpper(CMD_LOOK_AT, lookData, 2);
            break;
        }
        case 1: {
            // 表情を変える
            ExpressionData_t expr;
            expr.expression_id = EXPR_THINKING;
            expr.intensity = 50;
            expr.duration_ms = 2000;
            sendCommandToUpper(CMD_EXPRESSION, (uint8_t*)&expr, sizeof(expr));
            break;
        }
        case 2: {
            // 首を傾げる
            // 上半身に首の動きコマンドを送る
            break;
        }
        case 3: {
            // 元の表情に戻す
            ExpressionData_t expr;
            expr.expression_id = EXPR_NEUTRAL;
            expr.intensity = 100;
            expr.duration_ms = 0;
            sendCommandToUpper(CMD_EXPRESSION, (uint8_t*)&expr, sizeof(expr));
            break;
        }
        case 4: {
            // 前を見る
            uint8_t lookData[2] = {0, 0};
            sendCommandToUpper(CMD_LOOK_AT, lookData, 2);
            break;
        }
    }

    actionIndex++;
}

// =============================================================================
// デバッグコマンド処理
// =============================================================================
void handleDebugCommand(String cmd) {
    Serial.print("デバッグコマンド: ");
    Serial.println(cmd);

    if (cmd == "hello") {
        speakWithVoicevox("こんにちはナリ！ワガハイはコロ助ナリ！");
    }
    else if (cmd == "walk") {
        // 歩行開始
        WalkData_t walkData;
        walkData.mode = WALK_FORWARD;
        walkData.speed = 50;
        walkData.direction = 0;
        // 下半身への送信は上半身経由で
    }
    else if (cmd == "stop") {
        // 歩行停止
    }
    else if (cmd == "wave") {
        uint8_t dummy = 0;
        sendCommandToUpper(CMD_WAVE, &dummy, 1);
    }
    else if (cmd == "happy") {
        ExpressionData_t expr;
        expr.expression_id = EXPR_HAPPY;
        expr.intensity = 100;
        expr.duration_ms = 3000;
        sendCommandToUpper(CMD_EXPRESSION, (uint8_t*)&expr, sizeof(expr));
    }
    else if (cmd == "sad") {
        ExpressionData_t expr;
        expr.expression_id = EXPR_SAD;
        expr.intensity = 100;
        expr.duration_ms = 3000;
        sendCommandToUpper(CMD_EXPRESSION, (uint8_t*)&expr, sizeof(expr));
    }
    else if (cmd == "surprised") {
        ExpressionData_t expr;
        expr.expression_id = EXPR_SURPRISED;
        expr.intensity = 100;
        expr.duration_ms = 2000;
        sendCommandToUpper(CMD_EXPRESSION, (uint8_t*)&expr, sizeof(expr));
    }
    else if (cmd.startsWith("say ")) {
        String text = cmd.substring(4);
        // LLMに送信して応答を得る
        String response = sendToLLM(text);
        Serial.println("コロ助: " + response);
        speakWithVoicevox(response);
    }
    else if (cmd == "status") {
        Serial.println("=== コロ助ステータス ===");
        Serial.print("WiFi: ");
        Serial.println(wifiConnected ? "接続中" : "未接続");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        Serial.print("人物検知: ");
        Serial.println(personDetected ? "あり" : "なし");
        Serial.println("========================");
    }
    else {
        Serial.println("使用可能なコマンド:");
        Serial.println("  hello    - 挨拶");
        Serial.println("  wave     - 手を振る");
        Serial.println("  happy    - 嬉しい表情");
        Serial.println("  sad      - 悲しい表情");
        Serial.println("  surprised - 驚き");
        Serial.println("  say <text> - LLMと会話");
        Serial.println("  status   - ステータス表示");
    }
}

// =============================================================================
// オーディオイベントコールバック
// =============================================================================
void audio_info(const char* info) {
    Serial.print("Audio: ");
    Serial.println(info);
}

void audio_eof_mp3(const char* info) {
    Serial.println("再生完了");
    isSpeaking = false;

    // 発話終了を上半身に通知
    uint8_t dummy = 0;
    sendCommandToUpper(CMD_SPEAK_STOP, &dummy, 1);
}
