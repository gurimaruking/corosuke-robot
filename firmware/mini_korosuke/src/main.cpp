/**
 * ミニコロ助 (mini Korosuke) — ESP32-S3 単体 / 完全オフライン
 * Ph1: 単画面 ILI9488 に「左右2つの丸い目」を描画し、表情8種＋まばたき＋視線を出す。
 *
 * ベースボード: Elecrow ESP Terminal 3.5" (ESP32-S3, 320x480 ILI9488 SPI, OV2640, FT6236)
 * 目の描画は firmware/corosuke_eyes/src/main.cpp renderEye() を「単画面に2目」へ移植し、
 * スプライト寸法に対して比率で描くよう解像度非依存化した。
 *
 * ▼ ピン
 *   確定 (Elecrow wiki):
 *     SD(SPI):   SCK=12  MOSI=13  MISO=14  CS=10
 *     Touch FT6236(I2C): SDA=2  SCL=1               (Ph2: なで検知に使用)
 *     Buzzer=45   Mic I2S: CLK=39 WS=38
 *     Camera OV2640: MCLK=7 PCLK=17 D2..D9=8,47,48,21,18,16,15,6   (Ph3: 顔検出)
 *     Crowtail: D=11,40 / A=19,20 / UART RX=44 TX=43 (Ph2: MAX98357AをI2Sでここへ)
 *
 *   ★★ 未確定 — 実機スキーマで必ず確認して修正すること ★★
 *     LCD ILI9488 の制御ピン CS/DC/RST/BL。本S3+カメラ版の確定値が未取得。
 *     LCDはSDと同一SPIバス(SCK12/MOSI13/MISO14)を共有する構成とみなして設定。
 *     ネット上のCS15/DC2/BL27は旧ESP32(非S3)版の値で、DC=2は本機のTouch SDA=2と衝突する。
 *     下の PIN_LCD_CS/DC/RST/BL は「衝突しない空きGPIOの仮値」。到着後に確定値へ。
 *
 * シリアルコマンド (USB-CDC / 115200, 1行1コマンド) — センサ無しでも動作確認できる:
 *   emo <neutral|happy|happy2|sad|angry|surprised|sleepy|thinking|x>
 *   gaze <x> <y>      視線 (-1.0..1.0)
 *   blink             まばたき
 *   wink <l|r>        片目ウインク
 *   idle <on|off>     自動アイドル(まばたき+視線ゆらぎ)
 *   demo <on|off>     表情8種を自動巡回(初期ON。実機の見た目確認用)
 *   ping              -> pong
 */
#include <Arduino.h>
#define LGFX_USE_V1
#include <LovyanGFX.hpp>

// ---------- LCD 共有SPIバス(= SDと同じ) ----------
static constexpr int PIN_LCD_SCK  = 12;   // = SD SCLK
static constexpr int PIN_LCD_MOSI = 13;   // = SD MOSI
static constexpr int PIN_LCD_MISO = 14;   // = SD MISO
// ★未確定(仮値=確定ピンと衝突しない空きGPIO)。実機スキーマで確定させる:
static constexpr int PIN_LCD_CS   = 3;    // ★ SD_CS=10 とは別。
static constexpr int PIN_LCD_DC   = 42;   // ★ Touch SDA=2 とは別にすること。
static constexpr int PIN_LCD_RST  = -1;   // ★ -1=未接続/リセット共有の可能性。
static constexpr int PIN_LCD_BL   = 46;   // ★ バックライト。

// ---------- 画面レイアウト(landscape 480x320・左右2目) ----------
static constexpr int SCREEN_W = 480, SCREEN_H = 320;
static constexpr int EYE_D    = 200;                       // 片目スプライト径
static constexpr int EYE_Y    = (SCREEN_H - EYE_D) / 2;    // 60
static constexpr int EYE_XL   = 30;                        // 左目X
static constexpr int EYE_XR   = SCREEN_W - EYE_D - EYE_XL; // 250 (鼻の隙間=20px)

// ---------- LovyanGFX: ILI9488 (SPI, SDとバス共有) ----------
class MiniDisplay : public lgfx::LGFX_Device {
  lgfx::Bus_SPI       _bus;
  lgfx::Panel_ILI9488 _panel;
  lgfx::Light_PWM     _light;
public:
  MiniDisplay() {
    { auto b = _bus.config();
      b.spi_host   = SPI2_HOST;
      b.spi_mode   = 0;
      b.freq_write = 40000000;   // ILI9488 SPIは18bit/pxで重め。重ければ下げる
      b.freq_read  = 16000000;
      b.pin_sclk   = PIN_LCD_SCK;
      b.pin_mosi   = PIN_LCD_MOSI;
      b.pin_miso   = PIN_LCD_MISO;
      b.pin_dc     = PIN_LCD_DC;
      b.dma_channel= SPI_DMA_CH_AUTO;
      b.spi_3wire  = false;
      b.use_lock   = true;
      _bus.config(b); _panel.setBus(&_bus); }
    { auto p = _panel.config();
      p.pin_cs   = PIN_LCD_CS;
      p.pin_rst  = PIN_LCD_RST;
      p.pin_busy = -1;
      p.panel_width  = 320;      // ネイティブは縦320x480
      p.panel_height = 480;
      p.readable   = false;
      p.invert     = false;
      p.rgb_order  = false;
      p.bus_shared = true;       // SDとSPI共有
      _panel.config(p); setPanel(&_panel); }
    if (PIN_LCD_BL >= 0) {
      auto l = _light.config();
      l.pin_bl = PIN_LCD_BL; l.invert = false; l.freq = 12000; l.pwm_channel = 7;
      _light.config(l); _panel.setLight(&_light); }
  }
};

MiniDisplay lcd;
LGFX_Sprite spr(&lcd);          // 片目分のスプライト(両目で使い回す)

// ---------- 目の状態(corosuke_eyes から流用) ----------
enum Emotion { NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, SLEEPY, DEAD, THINKING };
struct EyeState {
  Emotion emo = NEUTRAL;
  bool  happyVar = false;
  float gazeX = 0, gazeY = 0;
  float curX = 0, curY = 0;
  float blink = 0;
  bool  blinking = false;
  uint32_t blinkStart = 0;
  bool  idle = true;
  uint32_t nextBlink = 3000, nextWander = 2000;
};
EyeState st;
bool winkLeft = false, winkRight = false;

// デモ(表情自動巡回)
bool demoOn = true;
uint32_t nextDemo = 0;
int demoIdx = 0;

static constexpr uint16_t C_WHITE = TFT_WHITE;
static constexpr uint16_t C_BLACK = TFT_BLACK;

// ---------- 片目描画(スプライト寸法に対し比率で描く=解像度非依存) ----------
void renderEye(bool isLeft) {
  const float CX = EYE_D * 0.5f, CY = EYE_D * 0.5f;
  const float R  = EYE_D * 0.5f - 2.0f;         // 白目半径
  spr.fillSprite(C_BLACK);
  spr.fillCircle(CX, CY, R, C_WHITE);

  // 瞳
  float gx = st.curX * (R * 0.36f), gy = st.curY * (R * 0.36f);
  float pr = (st.emo == SURPRISED) ? R * 0.32f : R * 0.44f;   // 驚き=瞳小さく
  spr.fillCircle(CX + gx, CY + gy, pr, C_BLACK);
  spr.fillCircle(CX + gx - pr / 3, CY + gy - pr / 3, pr / 4, C_WHITE);   // ハイライト

  // 感情ごとの上まぶた
  float lid = 0;
  switch (st.emo) {
    case SLEEPY: lid = EYE_D * 0.46f; break;   // 半目
    case SAD:    lid = EYE_D * 0.29f; break;
    case ANGRY:  lid = EYE_D * 0.29f; break;
    default:     lid = 0;             break;
  }
  float b = st.blink;
  if ((isLeft && winkLeft) || (!isLeft && winkRight)) b = 1.0f;
  float blinkY = EYE_D * b;
  int topY = (int)max(lid, blinkY);
  if (topY > 0) spr.fillRect(0, 0, EYE_D, topY, C_BLACK);

  if (st.emo == SAD) {   // 外側が下がる斜めまぶた
    int d = (int)(EYE_D * 0.23f);
    if (isLeft) spr.fillTriangle(0, topY, EYE_D, topY, 0, topY + d, C_BLACK);
    else        spr.fillTriangle(0, topY, EYE_D, topY, EYE_D, topY + d, C_BLACK);
  }
  if (st.emo == ANGRY) { // 内側が下がる
    int d = (int)(EYE_D * 0.25f);
    if (isLeft) spr.fillTriangle(0, topY, EYE_D, topY, EYE_D, topY + d, C_BLACK);
    else        spr.fillTriangle(0, topY, EYE_D, topY, 0, topY + d, C_BLACK);
  }
  if (st.emo == HAPPY) { // にっこり: 白目に細い黒の笑い弧(瞳は出さない)
    spr.fillSprite(C_BLACK);
    spr.fillCircle(CX, CY, R, C_WHITE);
    int   sign  = st.happyVar ? -1 : 1;
    float xmax  = R * 0.69f;
    float brush = R * 0.085f;
    for (float x = -xmax; x <= xmax; x += 1.0f) {
      float y = CY + sign * (x * x / (R * 1.27f) - R * 0.25f);
      spr.fillCircle(CX + x, y, brush, C_BLACK);
    }
  }
  if (st.emo == DEAD) {  // 終了合図: ✕✕(バツ目)
    spr.fillSprite(C_BLACK);
    spr.fillCircle(CX, CY, R, C_WHITE);
    float lim = R * 0.6f, brush = R * 0.12f;
    for (float i = -lim; i <= lim; i += 2.0f) {
      spr.fillCircle(CX + i, CY + i, brush, C_BLACK);
      spr.fillCircle(CX + i, CY - i, brush, C_BLACK);
    }
  }
  if (st.emo == THINKING) {  // 考え中: 瞳がゆっくり泳ぐ
    spr.fillSprite(C_BLACK);
    spr.fillCircle(CX, CY, R, C_WHITE);
    float t  = millis() / 520.0f;
    float px = CX + R * 0.40f * sinf(t);
    float py = CY + R * 0.12f * sinf(t * 2.3f);
    spr.fillCircle(px, py, R * 0.44f, C_BLACK);
    spr.fillCircle(px - R * 0.14f, py - R * 0.14f, R * 0.10f, C_WHITE);
  }

  spr.pushSprite(isLeft ? EYE_XL : EYE_XR, EYE_Y);
}

// ---------- コマンド処理(corosuke_eyes から流用 + demo) ----------
void handleLine(String line, Stream& reply) {
  line.trim(); line.toLowerCase();
  if (line.length() == 0) return;
  if (line == "ping") { reply.println("pong"); return; }
  if (line == "blink") { st.blinking = true; st.blinkStart = millis(); return; }
  if (line.startsWith("wink")) {
    if (line.endsWith("l")) winkLeft = true; else winkRight = true;
    st.blinkStart = millis(); st.blinking = true; return;
  }
  if (line.startsWith("emo ")) {
    String e = line.substring(4);
    demoOn = false;                       // 手動指定でデモ停止
    if      (e == "neutral")   st.emo = NEUTRAL;
    else if (e == "happy")   { st.emo = HAPPY; st.happyVar = false; }
    else if (e == "happy2")  { st.emo = HAPPY; st.happyVar = true;  }
    else if (e == "sad")       st.emo = SAD;
    else if (e == "angry")     st.emo = ANGRY;
    else if (e == "surprised") st.emo = SURPRISED;
    else if (e == "sleepy")    st.emo = SLEEPY;
    else if (e == "thinking")  st.emo = THINKING;
    else if (e == "x" || e == "dead") st.emo = DEAD;
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
  if (line.startsWith("demo")) { demoOn = line.endsWith("on"); reply.printf("demo=%d\n", demoOn); return; }
  reply.println("? emo/gaze/blink/wink/idle/demo/ping");
}

String bufUSB;
void pollStream(Stream& s, String& buf) {
  while (s.available()) {
    char c = s.read();
    if (c == '\n' || c == '\r') { if (buf.length()) { handleLine(buf, s); buf = ""; } }
    else if (buf.length() < 120) buf += c;
  }
}

// 表情巡回デモの並び
const Emotion DEMO_SEQ[] = { NEUTRAL, HAPPY, HAPPY, SAD, ANGRY, SURPRISED, SLEEPY, THINKING, DEAD };
const bool    DEMO_VAR[] = { false,   false, true,  false, false, false,     false,   false,    false };
const int     DEMO_N = sizeof(DEMO_SEQ) / sizeof(DEMO_SEQ[0]);

void setup() {
  Serial.begin(115200);                 // USB-CDC

  lcd.init();
  lcd.setRotation(1);                   // landscape 480x320
  lcd.fillScreen(C_BLACK);
  lcd.setBrightness(200);

  spr.setColorDepth(16);
  spr.setPsram(true);                   // フレームバッファはPSRAMへ
  spr.createSprite(EYE_D, EYE_D);

  st.nextBlink = millis() + 2500;
  nextDemo     = millis() + 2500;
  Serial.println("mini korosuke eyes ready nari!");
}

void loop() {
  uint32_t now = millis();
  pollStream(Serial, bufUSB);

  // デモ: 表情を自動巡回(センサ無しでも見た目確認できる)
  if (demoOn && now > nextDemo) {
    st.emo      = DEMO_SEQ[demoIdx];
    st.happyVar = DEMO_VAR[demoIdx];
    st.blinking = true; st.blinkStart = now;         // 切替時にひとつまばたき
    demoIdx = (demoIdx + 1) % DEMO_N;
    nextDemo = now + 2500;
  }

  // まばたき(閉じ120ms→開き120ms)
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

  renderEye(true);
  renderEye(false);
  delay(15);
}
