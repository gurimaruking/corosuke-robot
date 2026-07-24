/**
 * コロ助 目コプロセッサ / Korosuke Eye Coprocessor
 * ESP32-S3 (N16R8) + GC9A01 1.28" 240x240 x2 (SPI共有・CS分離)
 *
 * 配線 (M128-240240-RGB-7-V1.0):
 *   SCL(SCK) -> GPIO12   (両目共有)
 *   SDA(MOSI)-> GPIO11   (両目共有)
 *   DC       -> GPIO9    (両目共有)
 *   RST      -> GPIO8    (両目共有)
 *   CS 左目  -> GPIO10
 *   CS 右目  -> GPIO14
 *   VCC=3.3V / GND
 *   ※モジュールのCSはプルダウン(常時選択)なので、2枚共有バスでは
 *     必ず両方のCSをGPIOで駆動する(このファームがやる)
 *
 * コマンド (USBシリアル & UART1=RDK X5から / 115200bps, 1行1コマンド):
 *   emo <neutral|happy|sad|angry|surprised|sleepy>   感情切替
 *   gaze <x> <y>      視線 (-1.0 .. 1.0)
 *   blink             両目まばたき
 *   wink <l|r>        片目ウインク
 *   idle <on|off>     自動アイドル(まばたき+視線ゆらぎ)
 *   ping              -> "pong" 応答
 *
 * UART1 (RDK X5接続用): RX=GPIO18, TX=GPIO17
 */
#include <Arduino.h>
#define LGFX_USE_V1
#include <LovyanGFX.hpp>

// ---------- ピン ----------
static constexpr int PIN_SCK  = 12;
static constexpr int PIN_MOSI = 11;
static constexpr int PIN_DC   = 9;
static constexpr int PIN_RST  = 8;
static constexpr int PIN_CS_L = 10;
static constexpr int PIN_CS_R = 14;
static constexpr int PIN_U1RX = 18;   // RDK X5 TX ->
static constexpr int PIN_U1TX = 17;   // RDK X5 RX <-

// ---------- サーボ(腕ロープ引き, SG90) ----------
static constexpr int PIN_ARM_L = 4;   // 左腕サーボ信号(USB非干渉GPIO)
static constexpr int PIN_ARM_R = 5;   // 右腕サーボ信号
static constexpr int LEDC_ARM_L = 4;  // LEDCチャンネル(表示はSPIなので空き)
static constexpr int LEDC_ARM_R = 5;

// 角度(0-180)→パルス0.5-2.5ms@50Hz(20ms)を16bit dutyで出力
void servoWriteDeg(int ledc_ch, int deg) {
  deg = constrain(deg, 0, 180);
  int us = map(deg, 0, 180, 500, 2500);
  uint32_t duty = (uint32_t)((uint64_t)us * 65535 / 20000);
  ledcWrite(ledc_ch, duty);
}
void servoSetup() {
  ledcSetup(LEDC_ARM_L, 50, 16);
  ledcSetup(LEDC_ARM_R, 50, 16);
  ledcAttachPin(PIN_ARM_L, LEDC_ARM_L);
  ledcAttachPin(PIN_ARM_R, LEDC_ARM_R);
  servoWriteDeg(LEDC_ARM_L, 90);   // 初期=中立
  servoWriteDeg(LEDC_ARM_R, 90);
}

// ---------- LovyanGFX: 共有SPIバス + パネル2枚 ----------
class EyeDisplay : public lgfx::LGFX_Device {
  lgfx::Bus_SPI _bus;
  lgfx::Panel_GC9A01 _panel;
public:
  EyeDisplay(int pin_cs, bool use_rst) {
    { // バス設定(両目同一。LovyanGFXは同一host再initを許容)
      auto b = _bus.config();
      b.spi_host   = SPI2_HOST;
      b.spi_mode   = 0;
      b.freq_write = 40000000;
      b.pin_sclk   = PIN_SCK;
      b.pin_mosi   = PIN_MOSI;
      b.pin_miso   = -1;
      b.pin_dc     = PIN_DC;
      _bus.config(b);
      _panel.setBus(&_bus);
    }
    { // パネル設定
      auto p = _panel.config();
      p.pin_cs   = pin_cs;
      p.pin_rst  = use_rst ? PIN_RST : -1;  // RSTは物理共有: 片方だけ駆動
      p.memory_width = p.panel_width  = 240;
      p.memory_height= p.panel_height = 240;
      p.invert   = true;      // GC9A01は反転が正
      p.rgb_order= false;
      _panel.config(p);
      setPanel(&_panel);
    }
  }
};

EyeDisplay eyeL(PIN_CS_L, true);    // 左目(RST駆動担当)
EyeDisplay eyeR(PIN_CS_R, false);   // 右目
LGFX_Sprite spr(&eyeL);             // 1枚のスプライトを両目で使い回す

// ---------- 目の状態 ----------
enum Emotion { NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, SLEEPY };
struct EyeState {
  Emotion emo = NEUTRAL;
  float gazeX = 0, gazeY = 0;         // 目標視線 -1..1
  float curX = 0, curY = 0;           // 現在視線(補間)
  float blink = 0;                    // 0=開 1=閉
  bool  blinking = false;
  uint32_t blinkStart = 0;
  bool  idle = true;
  uint32_t nextBlink = 3000, nextWander = 2000;
};
EyeState st;
bool winkLeft = false, winkRight = false;

// ---------- 色 ----------
static constexpr uint16_t C_WHITE = TFT_WHITE;
static constexpr uint16_t C_BLACK = TFT_BLACK;
static constexpr uint16_t C_HILITE= TFT_WHITE;

// ---------- 片目を描画してpush ----------
void renderEye(EyeDisplay& dev, bool isLeft) {
  const int CX = 120, CY = 120;
  spr.fillSprite(C_BLACK);
  // 白目(ほぼ全面)
  spr.fillCircle(CX, CY, 118, C_WHITE);

  // 瞳(コロ助=大きめの黒瞳)
  float gx = st.curX * 42, gy = st.curY * 42;
  int pr = (st.emo == SURPRISED) ? 38 : 52;           // 驚き=瞳小さく
  spr.fillCircle(CX + (int)gx, CY + (int)gy, pr, C_BLACK);
  // ハイライト
  spr.fillCircle(CX + (int)gx - pr/3, CY + (int)gy - pr/3, pr/4, C_HILITE);

  // 感情ごとのまぶた(黒で隠す)
  int lid = 0; // 上まぶたの下端Y
  switch (st.emo) {
    case SLEEPY: lid = 110; break;                    // 半目
    case SAD:    lid = 70;  break;
    case ANGRY:  lid = 70;  break;
    default:     lid = 0;   break;
  }
  // まばたき/ウインク量を合成
  float b = st.blink;
  if ((isLeft && winkLeft) || (!isLeft && winkRight)) b = 1.0f;
  int blinkY = (int)(240 * b);
  int topY = max(lid, blinkY);
  if (topY > 0) spr.fillRect(0, 0, 240, topY, C_BLACK);

  if (st.emo == SAD) {   // 悲しみ: 外側が下がる斜めまぶた
    if (isLeft) spr.fillTriangle(0,topY, 240,topY, 0,topY+55, C_BLACK);
    else        spr.fillTriangle(0,topY, 240,topY, 240,topY+55, C_BLACK);
  }
  if (st.emo == ANGRY) { // 怒り: 内側が下がる
    if (isLeft) spr.fillTriangle(0,topY, 240,topY, 240,topY+60, C_BLACK);
    else        spr.fillTriangle(0,topY, 240,topY, 0,topY+60, C_BLACK);
  }
  if (st.emo == HAPPY) { // 喜び: 下から頬で隠れる笑い目(∪型)
    spr.fillCircle(CX, CY + 150, 130, C_BLACK);
  }
  spr.pushSprite(&dev, 0, 0);
}

// ---------- コマンド処理 ----------
void handleLine(String line, Stream& reply) {
  line.trim(); line.toLowerCase();
  if (line.length() == 0) return;
  if (line == "ping") { reply.println("pong"); return; }
  if (line == "blink") { st.blinking = true; st.blinkStart = millis(); return; }
  if (line.startsWith("wink")) {
    if (line.endsWith("l")) { winkLeft = true; } else { winkRight = true; }
    st.blinkStart = millis(); st.blinking = true; return;
  }
  if (line.startsWith("emo ")) {
    String e = line.substring(4);
    if      (e == "neutral")   st.emo = NEUTRAL;
    else if (e == "happy")     st.emo = HAPPY;
    else if (e == "sad")       st.emo = SAD;
    else if (e == "angry")     st.emo = ANGRY;
    else if (e == "surprised") st.emo = SURPRISED;
    else if (e == "sleepy")    st.emo = SLEEPY;
    reply.printf("emo=%s\n", e.c_str()); return;
  }
  if (line.startsWith("gaze ")) {
    float x, y;
    if (sscanf(line.c_str(), "gaze %f %f", &x, &y) == 2) {
      st.gazeX = constrain(x, -1.f, 1.f);
      st.gazeY = constrain(y, -1.f, 1.f);
    }
    return;
  }
  if (line.startsWith("idle")) { st.idle = line.endsWith("on"); return; }
  if (line.startsWith("arm")) {           // "arm l 90" / "arm r 30" (角度0-180)
    char side = 0; int deg = 90;
    if (sscanf(line.c_str(), "arm %c %d", &side, &deg) == 2) {
      if (side == 'l') servoWriteDeg(LEDC_ARM_L, deg);
      else if (side == 'r') servoWriteDeg(LEDC_ARM_R, deg);
      reply.printf("arm %c=%d\n", side, deg);
    }
    return;
  }
  reply.println("? emo/gaze/blink/wink/idle/arm/ping");
}

String bufUSB, bufU0, bufU1;
void pollStream(Stream& s, String& buf) {
  while (s.available()) {
    char c = s.read();
    if (c == '\n' || c == '\r') { if (buf.length()) { handleLine(buf, s); buf = ""; } }
    else if (buf.length() < 120) buf += c;
  }
}

// ---------- setup / loop ----------
void setup() {
  Serial.begin(115200);                                   // USB CDC
  Serial0.begin(115200);                                  // UART0=CH343側: 診断コンソール
  Serial0.println("[boot] setup start");
  Serial1.begin(115200, SERIAL_8N1, PIN_U1RX, PIN_U1TX);  // RDK X5

  eyeL.init();
  Serial0.println("[boot] eyeL.init done");
  eyeR.init();
  Serial0.println("[boot] eyeR.init done");
  spr.setColorDepth(16);
  spr.setPsram(true);                 // N16R8のPSRAMにフレームバッファ
  spr.createSprite(240, 240);
  Serial0.printf("[boot] sprite buf=%p psram=%u free\n", spr.getBuffer(), (unsigned)ESP.getFreePsram());

  servoSetup();
  Serial0.println("[boot] servo ready (arm L=GPIO4 R=GPIO5)");

  st.nextBlink = millis() + 2500;
  Serial.println("Korosuke eyes ready nari!");
  Serial0.println("[boot] ready nari!");
}

void loop() {
  uint32_t now = millis();
  pollStream(Serial, bufUSB);
  pollStream(Serial0, bufU0);   // CH343側からもコマンド可(診断用)
  pollStream(Serial1, bufU1);

  // まばたきアニメ(閉じ120ms→開き120ms)
  if (st.blinking) {
    uint32_t t = now - st.blinkStart;
    if      (t < 120) st.blink = t / 120.0f;
    else if (t < 240) st.blink = 1.0f - (t - 120) / 120.0f;
    else { st.blink = 0; st.blinking = false; winkLeft = winkRight = false; }
  }
  // アイドル: 自動まばたき+視線ゆらぎ
  if (st.idle) {
    if (now > st.nextBlink) { st.blinking = true; st.blinkStart = now;
                              st.nextBlink = now + random(2200, 5600); }
    if (now > st.nextWander) { st.gazeX = random(-60, 61) / 100.0f;
                               st.gazeY = random(-35, 36) / 100.0f;
                               st.nextWander = now + random(1200, 3800); }
  }
  // 視線をなめらかに補間
  st.curX += (st.gazeX - st.curX) * 0.18f;
  st.curY += (st.gazeY - st.curY) * 0.18f;

  renderEye(eyeL, true);
  renderEye(eyeR, false);
  delay(15);   // ~35-40fps相当(2枚push込み)
}
