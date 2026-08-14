/**
 * コンボ拡張: ESP32-1732S019 に目(GC9A01×2)+腕サーボ(SG90×2)+撫でタッチを載せる
 *
 * corosuke_eyes/src/main.cpp の目エンジンを移植したもの。差分:
 *   - SPIは SPI3_HOST(お腹のST7789が SPI2_HOST を使用中のため)
 *   - ピンはビルドフラグ(-DEYE_SCK=..等)で注入。基板ヘッダの空きピンに合わせる
 *   - コマンドはUART0(CH340)の「A5 5B|len|テキスト」フレームで到着(main.cppが呼ぶ)
 *     → devkit目基板と同じコマンド体系: emo/gaze/blink/wink/idle/arm/ping
 *   - 描画はcore0のFreeRTOSタスク(JPEG受信・デコードのloop()=core1と並走)
 *   - 撫で検知は "EVENT touch" 行をSerialへ → display_send.py がモニタの /event へ中継
 *
 * 使い方(main.cpp): setup()で eyesComboSetup()、コマンドフレーム受信毎に
 * eyesComboHandleLine(line)。COMBO_EYES 未定義なら全て空になる。
 */
#pragma once
#if defined(COMBO_EYES)

#include <LovyanGFX.hpp>

// ---- ピン(platformio.iniの-Dで上書き) ----
// 独立配線方式: 左右の目を別ピンに点対点で結線できる(Y分岐ハーネス不要)。
// SCLK/MOSIはSPI3の1系統だが、GPIOマトリクスの「1出力信号→複数パッド」機能で
// 左右両方のピンに同じ信号を複製する(eyesComboSetupのmirrorSpi3Pin)。
// DC/RST/CSは元々バス/パネル毎に持てるので完全独立。
#ifndef EYEL_SCK
#define EYEL_SCK  4
#endif
#ifndef EYEL_MOSI
#define EYEL_MOSI 5
#endif
#ifndef EYEL_DC
#define EYEL_DC   6
#endif
#ifndef EYEL_RST
#define EYEL_RST  7
#endif
#ifndef EYEL_CS
#define EYEL_CS   15
#endif
#ifndef EYER_SCK
#define EYER_SCK  38
#endif
#ifndef EYER_MOSI
#define EYER_MOSI 39
#endif
#ifndef EYER_DC
#define EYER_DC   48
#endif
#ifndef EYER_RST
#define EYER_RST  47
#endif
#ifndef EYER_CS
#define EYER_CS   21
#endif
#ifndef ARM_L_PIN
#define ARM_L_PIN 4
#endif
#ifndef ARM_R_PIN
#define ARM_R_PIN 5
#endif
#ifndef PET_TOUCH_PIN
#define PET_TOUCH_PIN -1     // S3内蔵タッチ対応GPIO。-1=無効
#endif

// ---------- サーボ(腕ロープ引き, SG90) — corosuke_eyesと同一ロジック ----------
static constexpr int LEDC_ARM_L = 4;   // ch7はお腹画面バックライトが使用
static constexpr int LEDC_ARM_R = 5;
static constexpr int SERVO_RES = 14;   // S3のLEDC上限14bit(16bitは失敗しPWMが出ない)
static uint32_t armDetachAt[2] = {0, 0};
static const uint32_t ARM_HOLD_MS = 700;
static int armIdx(int ch) { return (ch == LEDC_ARM_L) ? 0 : 1; }
static int armPin(int ch) { return (ch == LEDC_ARM_L) ? ARM_L_PIN : ARM_R_PIN; }

static void servoWriteDeg(int ch, int deg) {
  deg = constrain(deg, 0, 180);
  int us = map(deg, 0, 180, 500, 2500);
  uint32_t duty = (uint32_t)((uint64_t)us * (1UL << SERVO_RES) / 20000);
  ledcAttachPin(armPin(ch), ch);
  ledcWrite(ch, duty);
  armDetachAt[armIdx(ch)] = millis() + ARM_HOLD_MS;
}
static void servoDetach(int ch) {
  ledcDetachPin(armPin(ch));
  pinMode(armPin(ch), INPUT);
}
static void armUpdate() {
  uint32_t now = millis();
  if (armDetachAt[0] && now > armDetachAt[0]) { servoDetach(LEDC_ARM_L); armDetachAt[0] = 0; }
  if (armDetachAt[1] && now > armDetachAt[1]) { servoDetach(LEDC_ARM_R); armDetachAt[1] = 0; }
}

// ---------- GC9A01×2 (SPI3・左右独立ピン) ----------
#include <driver/gpio.h>
#include <esp_rom_gpio.h>
#include <soc/spi_periph.h>

class EyeDisplay : public lgfx::LGFX_Device {
  lgfx::Bus_SPI _bus;
  lgfx::Panel_GC9A01 _panel;
public:
  EyeDisplay(int sck, int mosi, int dc, int rst, int cs) {
    { auto b = _bus.config();
      b.spi_host   = SPI3_HOST;        // ST7789(お腹)がSPI2_HOSTなので3を使う
      b.spi_mode   = 0;
      b.freq_write = 40000000;
      b.pin_sclk   = sck;
      b.pin_mosi   = mosi;
      b.pin_miso   = -1;
      b.pin_dc     = dc;               // DCはバス毎に独立(各インスタンスが自分のDCを駆動)
      _bus.config(b);
      _panel.setBus(&_bus);
    }
    { auto p = _panel.config();
      p.pin_cs   = cs;
      p.pin_rst  = rst;
      p.memory_width = p.panel_width  = 240;
      p.memory_height= p.panel_height = 240;
      p.invert   = true;
      p.rgb_order= false;
      _panel.config(p);
      setPanel(&_panel);
    }
  }
};

static EyeDisplay eyeL(EYEL_SCK, EYEL_MOSI, EYEL_DC, EYEL_RST, EYEL_CS);
static EyeDisplay eyeR(EYER_SCK, EYER_MOSI, EYER_DC, EYER_RST, EYER_CS);
static LGFX_Sprite eyeSpr(&eyeL);

// SPI3のCLK/MOSI出力を左右両方のピンへ複製(GPIOマトリクス: 1出力信号→複数パッド可)。
// 2つ目のバスinitで1つ目のピン割当が外れるため、両init後に明示的に張り直す。
static void mirrorSpi3Pin(int pin, uint8_t sig) {
  esp_rom_gpio_pad_select_gpio(pin);
  gpio_set_direction((gpio_num_t)pin, GPIO_MODE_OUTPUT);
  esp_rom_gpio_connect_out_signal(pin, sig, false, false);
}
static void mirrorSpi3Bus() {
  mirrorSpi3Pin(EYEL_SCK,  spi_periph_signal[SPI3_HOST].spiclk_out);
  mirrorSpi3Pin(EYER_SCK,  spi_periph_signal[SPI3_HOST].spiclk_out);
  mirrorSpi3Pin(EYEL_MOSI, spi_periph_signal[SPI3_HOST].spid_out);
  mirrorSpi3Pin(EYER_MOSI, spi_periph_signal[SPI3_HOST].spid_out);
}

// ---------- 目の状態(corosuke_eyesと同一) ----------
enum Emotion { NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, SLEEPY, DEAD, THINKING };
struct EyeState {
  Emotion emo = NEUTRAL;
  bool happyVar = false;
  float gazeX = 0, gazeY = 0, curX = 0, curY = 0;
  float blink = 0;
  bool  blinking = false;
  uint32_t blinkStart = 0;
  bool  idle = true;
  uint32_t nextBlink = 3000, nextWander = 2000;
};
static EyeState est;
static bool winkLeft = false, winkRight = false;

static void renderEye(EyeDisplay& dev, bool isLeft) {
  const int CX = 120, CY = 120;
  eyeSpr.fillSprite(TFT_BLACK);
  eyeSpr.fillCircle(CX, CY, 118, TFT_WHITE);

  float gx = est.curX * 42, gy = est.curY * 42;
  int pr = (est.emo == SURPRISED) ? 38 : 52;
  eyeSpr.fillCircle(CX + (int)gx, CY + (int)gy, pr, TFT_BLACK);
  eyeSpr.fillCircle(CX + (int)gx - pr / 3, CY + (int)gy - pr / 3, pr / 4, TFT_WHITE);

  int lid = 0;
  switch (est.emo) {
    case SLEEPY: lid = 110; break;
    case SAD:    lid = 70;  break;
    case ANGRY:  lid = 70;  break;
    default:     lid = 0;   break;
  }
  float b = est.blink;
  if ((isLeft && winkLeft) || (!isLeft && winkRight)) b = 1.0f;
  int topY = max(lid, (int)(240 * b));
  if (topY > 0) eyeSpr.fillRect(0, 0, 240, topY, TFT_BLACK);

  if (est.emo == SAD) {
    if (isLeft) eyeSpr.fillTriangle(0, topY, 240, topY, 0, topY + 55, TFT_BLACK);
    else        eyeSpr.fillTriangle(0, topY, 240, topY, 240, topY + 55, TFT_BLACK);
  }
  if (est.emo == ANGRY) {
    if (isLeft) eyeSpr.fillTriangle(0, topY, 240, topY, 240, topY + 60, TFT_BLACK);
    else        eyeSpr.fillTriangle(0, topY, 240, topY, 0, topY + 60, TFT_BLACK);
  }
  if (est.emo == HAPPY) {
    eyeSpr.fillSprite(TFT_BLACK);
    eyeSpr.fillCircle(CX, CY, 118, TFT_WHITE);
    int sign = est.happyVar ? -1 : 1;
    for (int x = -82; x <= 82; x++) {
      int y = CY + sign * (x * x / 150 - 30);
      eyeSpr.fillCircle(CX + x, y, 10, TFT_BLACK);
    }
  }
  if (est.emo == DEAD) {
    eyeSpr.fillSprite(TFT_BLACK);
    eyeSpr.fillCircle(CX, CY, 118, TFT_WHITE);
    for (int i = -60; i <= 60; i += 2) {
      eyeSpr.fillCircle(CX + i, CY + i, 14, TFT_BLACK);
      eyeSpr.fillCircle(CX + i, CY - i, 14, TFT_BLACK);
    }
  }
  if (est.emo == THINKING) {
    eyeSpr.fillSprite(TFT_BLACK);
    eyeSpr.fillCircle(CX, CY, 118, TFT_WHITE);
    float t = millis() / 520.0f;
    int px = CX + (int)(40.0f * sinf(t));
    int py = CY + (int)(12.0f * sinf(t * 2.3f));
    eyeSpr.fillCircle(px, py, 50, TFT_BLACK);
    eyeSpr.fillCircle(px - 16, py - 16, 12, TFT_WHITE);
  }
  eyeSpr.pushSprite(&dev, 0, 0);
}

// ---------- コマンド処理(devkit目基板と同一体系) ----------
static void eyesComboHandleLine(String line) {
  line.trim(); line.toLowerCase();
  if (line.length() == 0) return;
  if (line == "ping") { Serial.println("pong"); return; }
  if (line == "blink") { est.blinking = true; est.blinkStart = millis(); return; }
  if (line.startsWith("wink")) {
    if (line.endsWith("l")) winkLeft = true; else winkRight = true;
    est.blinkStart = millis(); est.blinking = true; return;
  }
  if (line.startsWith("emo ")) {
    String e = line.substring(4);
    if      (e == "neutral")   est.emo = NEUTRAL;
    else if (e == "happy")   { est.emo = HAPPY; est.happyVar = false; }
    else if (e == "happy2")  { est.emo = HAPPY; est.happyVar = true;  }
    else if (e == "sad")       est.emo = SAD;
    else if (e == "angry")     est.emo = ANGRY;
    else if (e == "surprised") est.emo = SURPRISED;
    else if (e == "sleepy")    est.emo = SLEEPY;
    else if (e == "thinking")  est.emo = THINKING;
    else if (e == "x" || e == "dead") est.emo = DEAD;
    return;
  }
  if (line.startsWith("gaze ")) {
    float x, y;
    if (sscanf(line.c_str(), "gaze %f %f", &x, &y) == 2) {
      est.gazeX = constrain(x, -1.f, 1.f);
      est.gazeY = constrain(y, -1.f, 1.f);
    }
    return;
  }
  if (line.startsWith("idle")) { est.idle = line.endsWith("on"); return; }
  if (line.startsWith("arm")) {
    char side = 0; int deg = 90;
    if (line.indexOf("off") >= 0) {
      if (line.indexOf('l') >= 0) servoDetach(LEDC_ARM_L);
      if (line.indexOf('r') >= 0) servoDetach(LEDC_ARM_R);
    } else if (sscanf(line.c_str(), "arm %c %d", &side, &deg) == 2) {
      if (side == 'l') servoWriteDeg(LEDC_ARM_L, deg);
      else if (side == 'r') servoWriteDeg(LEDC_ARM_R, deg);
    }
    return;
  }
}

// ---------- 描画タスク(core0。JPEG受信のloop()=core1と並走) ----------
#if PET_TOUCH_PIN >= 0
static uint32_t petBaseline = 0, petLastMs = 0;
#endif

static void eyesTask(void*) {
  for (;;) {
    uint32_t now = millis();
    armUpdate();
#if PET_TOUCH_PIN >= 0
    if (petBaseline > 0) {   // 撫で検知(S3は接触で値上昇)。1.2秒に1回まで通知
      uint32_t tv = touchRead(PET_TOUCH_PIN);
      if (tv > petBaseline + petBaseline / 3 && now - petLastMs > 1200) {
        petLastMs = now;
        Serial.println("EVENT touch");   // display_send.py がモニタ/eventへ中継
        est.emo = HAPPY; est.blinking = true; est.blinkStart = now;
      }
    }
#endif
    if (est.blinking) {
      uint32_t t = now - est.blinkStart;
      if      (t < 120) est.blink = t / 120.0f;
      else if (t < 240) est.blink = 1.0f - (t - 120) / 120.0f;
      else { est.blink = 0; est.blinking = false; winkLeft = winkRight = false; }
    }
    if (est.idle) {
      if (now > est.nextBlink) { est.blinking = true; est.blinkStart = now;
                                 est.nextBlink = now + random(2200, 5600); }
      if (now > est.nextWander) { est.gazeX = random(-60, 61) / 100.0f;
                                  est.gazeY = random(-35, 36) / 100.0f;
                                  est.nextWander = now + random(1200, 3800); }
    }
    est.curX += (est.gazeX - est.curX) * 0.18f;
    est.curY += (est.gazeY - est.curY) * 0.18f;
    renderEye(eyeL, true);
    renderEye(eyeR, false);
    vTaskDelay(pdMS_TO_TICKS(15));   // ~35fps相当
  }
}

static void eyesComboSetup() {
  eyeL.init();
  eyeR.init();
  mirrorSpi3Bus();   // 両init後にSCLK/MOSIを左右両ピンへ複製(必ずinitの後)
  eyeSpr.setColorDepth(16);
  eyeSpr.setPsram(true);
  if (!eyeSpr.createSprite(240, 240)) {      // PSRAM無し変種の保険: 8bit色で再試行
    eyeSpr.setPsram(false);
    eyeSpr.setColorDepth(8);
    eyeSpr.createSprite(240, 240);
  }
  { double fL = ledcSetup(LEDC_ARM_L, 50, SERVO_RES);
    double fR = ledcSetup(LEDC_ARM_R, 50, SERVO_RES);
    ledcAttachPin(ARM_L_PIN, LEDC_ARM_L);
    ledcAttachPin(ARM_R_PIN, LEDC_ARM_R);
    servoWriteDeg(LEDC_ARM_L, 90);
    servoWriteDeg(LEDC_ARM_R, 90);
    Serial.printf("EYES combo: servo L=GPIO%d R=GPIO%d ledc=%.0f/%.0fHz\n",
                  ARM_L_PIN, ARM_R_PIN, fL, fR);
  }
#if PET_TOUCH_PIN >= 0
  { uint32_t s = 0;
    for (int i = 0; i < 8; i++) { s += touchRead(PET_TOUCH_PIN); delay(5); }
    petBaseline = s / 8;
    Serial.printf("EYES combo: pet touch GPIO%d baseline=%u\n", PET_TOUCH_PIN,
                  (unsigned)petBaseline); }
#endif
  est.nextBlink = millis() + 2500;
  xTaskCreatePinnedToCore(eyesTask, "eyes", 6144, nullptr, 1, nullptr, 0);
  Serial.printf("EYES combo(独立配線): L sck%d mosi%d dc%d rst%d cs%d / "
                "R sck%d mosi%d dc%d rst%d cs%d\n",
                EYEL_SCK, EYEL_MOSI, EYEL_DC, EYEL_RST, EYEL_CS,
                EYER_SCK, EYER_MOSI, EYER_DC, EYER_RST, EYER_CS);
}

#else   // COMBO_EYES未定義: 全て空
static inline void eyesComboSetup() {}
static inline void eyesComboHandleLine(const String&) {}
#endif  // COMBO_EYES
