/**
 * コロ助 胴体ディスプレイ — M2: USBシリアルでJPEG映像を受信して表示 (改良版)
 *
 * フレーミング(PC/RDK → ESP32, CH340 UART):
 *   0xA5 0x5A            同期マジック
 *   len (uint32 LE)      続くJPEGのバイト数
 *   <len bytes>          JPEG本体(480x272想定、そのまま全画面描画)
 * ESP32は1枚描くごとに ACK(0x06) を返す(フロー制御=RXオーバーラン防止)。
 *
 * 改良点(前版の「映らない」誤認対策):
 *   - 受信停止後もすぐ画面を消さず、最後のフレームを残して小さな "NO SIGNAL" バッジのみ表示。
 *   - 毎フレーム左上に「通し番号」を fillRect+文字(既知良描画) で常時表示 = 生存確認 &
 *     もし映像が黒でもカウンタが進めば drawJpg 側の問題と切り分けできる。
 */
#include <Arduino.h>
#if defined(BOARD_1732S019)
#include "LGFX_ESP32_1732S019.h"    // 1.9" 170x320 SPI(タッチ無し) → 横長320x170で使用
static const int W = 320, H = 170;
#define HAS_TOUCH 0
#else
#include "LGFX_ESP32_4827S043.h"    // 4.3" 480x272 RGBパラレル(抵抗膜タッチ)
static const int W = 480, H = 272;
#define HAS_TOUCH 1
#endif

// 自己申告「SIZE w h T0/1」: センダ(display_send.py)がこれを読んで解像度・タッチ有無に
// 自動適応する。起動時+アイドル2秒毎+統計1秒毎に出す(センダは接続時に入力を捨てるため反復必須)。
static void announceSize() {
  Serial.printf("SIZE %d %d T%d\n", W, H, HAS_TOUCH);
}
#include <JPEGDEC.h>

static LGFX lcd;

// JPEGDEC: MCUブロック単位でデコード → callbackで直接パネルへblit(中間RGBバッファ不要)。
// LovyanGFX内蔵tjpgd(drawJpg)の2-3倍速。色が反転して見えたら RGB565_LITTLE ⇄ BIG を入替。
static JPEGDEC jpeg;
static int jpegDraw(JPEGDRAW *p) {
  lcd.pushImage(p->x, p->y, p->iWidth, p->iHeight, (uint16_t *)p->pPixels);
  return 1;   // 1=続行
}

#define BAUD     2000000
#define MAX_JPG  200000
static uint8_t* jpg = nullptr;

static uint32_t total = 0, frames = 0, bytesAcc = 0, lastStat = 0, lastFrameMs = 0;
static bool idleShown = false, everFrame = false;

static void drawBootIdle() {
  lcd.fillScreen(TFT_BLACK);
  lcd.setTextColor(TFT_WHITE, TFT_BLACK);
  lcd.setTextDatum(middle_center);
  lcd.setFont(&fonts::Font4);
  lcd.drawString("Korosuke Display", W / 2, H / 2 - 20);
  lcd.setFont(&fonts::Font2);
  lcd.setTextColor(TFT_CYAN, TFT_BLACK);
  lcd.drawString("waiting for USB video (A5 5A | len | jpeg) @2Mbaud", W / 2, H / 2 + 14);
}

static void drawNoSignalBadge() {   // 最後のフレームは残し、上部中央に小さく
  lcd.fillRect(W / 2 - 60, 2, 120, 18, TFT_RED);
  lcd.setTextColor(TFT_WHITE, TFT_RED);
  lcd.setTextDatum(middle_center);
  lcd.setFont(&fonts::Font2);
  lcd.drawString("NO SIGNAL", W / 2, 11);
}

// 左上に通し番号(常時・既知良描画=生存確認)
static void drawCounter() {
  lcd.fillRect(0, 0, 96, 16, TFT_BLACK);
  lcd.setTextColor(TFT_GREEN, TFT_BLACK);
  lcd.setTextDatum(top_left);
  lcd.setFont(&fonts::Font2);
  lcd.drawString(String("#") + total, 3, 1);
}

// タップ検出(デバウンス0.7s) → "TOUCH x y" をRDKへ送信(display_send.pyがボタン判定)
static uint32_t lastTouchMs = 0;
static void pollTouch() {
  int32_t tx, ty;
  if (lcd.getTouch(&tx, &ty)) {
    uint32_t now = millis();
    if (now - lastTouchMs > 700) { Serial.print("TOUCH "); Serial.print(tx); Serial.print(" "); Serial.println(ty); }
    lastTouchMs = now;
  }
}

static bool syncMagic(uint32_t toms) {
  uint32_t t = millis();
  int state = 0;
  uint16_t k = 0;
  while (millis() - t < toms) {
    if (!Serial.available()) { if (++k >= 50) { k = 0; pollTouch(); } delay(1); continue; }
    uint8_t b = Serial.read();
    if (state == 0) { state = (b == 0xA5) ? 1 : 0; }
    else            { if (b == 0x5A) return true; state = (b == 0xA5) ? 1 : 0; }
  }
  return false;
}

static uint32_t readExact(uint8_t* dst, uint32_t n, uint32_t toms) {
  uint32_t got = 0, t = millis();
  while (got < n) {
    int avail = Serial.available();
    if (avail > 0) {
      uint32_t want = n - got;
      size_t r = Serial.readBytes(dst + got, avail < (int)want ? avail : want);
      got += r;
      if (r) t = millis();
    } else if (millis() - t > toms) {
      break;
    }
  }
  return got;
}

void setup() {
  Serial.setRxBufferSize(16384);   // begin() より前(取りこぼし防止)
  Serial.begin(BAUD);
  delay(200);
  Serial.printf("\n=== Korosuke Display M2 (USB JPEG viewer) baud=%d ===\n", BAUD);
  announceSize();
  jpg = (uint8_t*)ps_malloc(MAX_JPG);
  if (!jpg) jpg = (uint8_t*)malloc(60000);   // PSRAM無し変種の保険(小画面JPEGなら足りる)
  Serial.printf("PSRAM %s, jpg buffer %s (%d B)\n",
                psramFound() ? "OK" : "NG", jpg ? "alloc" : "FAIL", MAX_JPG);
  lcd.init();
#if defined(BOARD_1732S019)
  lcd.setRotation(1);                        // 縦170x320パネルを横長320x170で使う
#endif
  lcd.setBrightness(255);
  drawBootIdle();
  lastStat = millis();
}

void loop() {
  pollTouch();
  if (!syncMagic(1000)) {
    static uint32_t lastSizeMs = 0;
    if (millis() - lastSizeMs > 2000) { announceSize(); lastSizeMs = millis(); }
    if (everFrame && !idleShown && millis() - lastFrameMs > 1500) {
      drawNoSignalBadge();          // 最後の絵は残す
      idleShown = true;
    }
    return;
  }
  uint8_t lb[4];
  if (readExact(lb, 4, 500) != 4) return;
  uint32_t len = (uint32_t)lb[0] | ((uint32_t)lb[1] << 8) |
                 ((uint32_t)lb[2] << 16) | ((uint32_t)lb[3] << 24);
  if (len == 0 || len > MAX_JPG) { Serial.printf("bad len %u\n", (unsigned)len); return; }
  uint32_t got = readExact(jpg, len, 1500);
  if (got != len) { Serial.printf("short %u/%u\n", (unsigned)got, (unsigned)len); return; }

  bool ok = false;
  if (jpeg.openRAM(jpg, len, jpegDraw)) {
    jpeg.setPixelType(RGB565_BIG_ENDIAN);   // LovyanGFX pushImage はビッグエンディアンRGB565が正
    lcd.startWrite();
    ok = jpeg.decode(0, 0, 0);       // フルスケール。callbackでMCUブロックをpushImage
    lcd.endWrite();
    jpeg.close();
  }
  total++; frames++; bytesAcc += len;
  everFrame = true; idleShown = false;
  lastFrameMs = millis();
  if (!ok) Serial.println("JPEGDEC decode FAILED");
  Serial.write(0x06);               // ACK

  uint32_t now = millis();
  if (now - lastStat >= 1000) {
    float fps = frames * 1000.0f / (now - lastStat);
    float kbps = bytesAcc / 1024.0f / ((now - lastStat) / 1000.0f);
    Serial.printf("fps=%.1f  %.0f KB/s  lastlen=%u  total=%u\n",
                  fps, kbps, (unsigned)len, (unsigned)total);
    announceSize();                 // ストリーム中もセンダへ周知(接続直後の読み捨て対策)
    frames = 0; bytesAcc = 0; lastStat = now;
  }
}
