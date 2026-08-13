/**
 * LovyanGFX パネル定義 — Sunton ESP32-4827S043 (CYD 4.3" 480x272 RGBパラレル)
 *
 * ライブラリ同梱の LGFX_ESP32S3_RGB_ESP32-8048S043.h(兄弟機800x480/同ピン)を土台に
 * 解像度を 480x272 に変更したもの。ピン配置は 8048S043 と共通。
 *   - RGBパネルは実行時に自動検出できないので必ず明示定義する
 *   - フレームバッファは PSRAM 必須(パネルが連続スキャンするため)
 *   - メンバ名は _*_instance にする(基底クラスの _panel/_bus と衝突するため)
 *
 * 物理データピンは2つの5bit群 {8,3,46,9,1} と {45,48,47,21,14} が固定。
 * 画面で赤青が逆に見えたら pin_d0..4(B) と pin_d11..15(R) の割当を入れ替える。
 */
#pragma once
#ifndef LGFX_USE_V1
#define LGFX_USE_V1
#endif
#include <LovyanGFX.hpp>
#include <lgfx/v1/platforms/esp32s3/Panel_RGB.hpp>
#include <lgfx/v1/platforms/esp32s3/Bus_RGB.hpp>

class LGFX : public lgfx::LGFX_Device {
public:
  lgfx::Bus_RGB       _bus_instance;
  lgfx::Panel_RGB     _panel_instance;
  lgfx::Light_PWM     _light_instance;
  lgfx::Touch_XPT2046 _touch_instance;   // 抵抗膜タッチ(SPI, SDスロットとバス共有)

  LGFX(void) {
    { // ---- パネル(解像度) ----
      auto cfg = _panel_instance.config();
      cfg.memory_width  = 480;
      cfg.memory_height = 272;
      cfg.panel_width   = 480;
      cfg.panel_height  = 272;
      cfg.offset_x = 0;
      cfg.offset_y = 0;
      _panel_instance.config(cfg);
    }
    { // ---- フレームバッファは PSRAM 必須 ----
      auto cfg = _panel_instance.config_detail();
      cfg.use_psram = 1;
      _panel_instance.config_detail(cfg);
    }
    { // ---- RGBバス(データ16本 + 同期 + タイミング) ----
      auto cfg = _bus_instance.config();
      cfg.panel = &_panel_instance;

      cfg.pin_d0  = GPIO_NUM_8;   // B0
      cfg.pin_d1  = GPIO_NUM_3;   // B1
      cfg.pin_d2  = GPIO_NUM_46;  // B2
      cfg.pin_d3  = GPIO_NUM_9;   // B3
      cfg.pin_d4  = GPIO_NUM_1;   // B4
      cfg.pin_d5  = GPIO_NUM_5;   // G0
      cfg.pin_d6  = GPIO_NUM_6;   // G1
      cfg.pin_d7  = GPIO_NUM_7;   // G2
      cfg.pin_d8  = GPIO_NUM_15;  // G3
      cfg.pin_d9  = GPIO_NUM_16;  // G4
      cfg.pin_d10 = GPIO_NUM_4;   // G5
      cfg.pin_d11 = GPIO_NUM_45;  // R0
      cfg.pin_d12 = GPIO_NUM_48;  // R1
      cfg.pin_d13 = GPIO_NUM_47;  // R2
      cfg.pin_d14 = GPIO_NUM_21;  // R3
      cfg.pin_d15 = GPIO_NUM_14;  // R4

      cfg.pin_henable = GPIO_NUM_40;  // DE
      cfg.pin_vsync   = GPIO_NUM_41;
      cfg.pin_hsync   = GPIO_NUM_39;
      cfg.pin_pclk    = GPIO_NUM_42;
      cfg.freq_write  = 9000000;      // 480x272 なら 9MHz で約57Hz

      cfg.hsync_polarity    = 0;
      cfg.hsync_front_porch = 8;
      cfg.hsync_pulse_width = 4;
      cfg.hsync_back_porch  = 43;
      cfg.vsync_polarity    = 0;
      cfg.vsync_front_porch = 8;
      cfg.vsync_pulse_width = 4;
      cfg.vsync_back_porch  = 12;
      cfg.pclk_active_neg   = 1;
      cfg.de_idle_high      = 0;
      cfg.pclk_idle_high    = 0;
      _bus_instance.config(cfg);
    }
    _panel_instance.setBus(&_bus_instance);

    { // ---- バックライト(PWM) ----
      auto cfg = _light_instance.config();
      cfg.pin_bl = GPIO_NUM_2;
      _light_instance.config(cfg);
    }
    _panel_instance.light(&_light_instance);

    { // ---- 抵抗膜タッチ XPT2046 (SPI: SCLK=12/MOSI=11/MISO=13, CS=38, IRQ=18) ----
      auto cfg = _touch_instance.config();
      cfg.bus_shared      = false;         // パネルはRGB(SPI非共有)。SDとは共有するが本FWはSD未使用
      cfg.offset_rotation = 0;             // 座標が回転/反転していたら 0..7 を調整
      // PENIRQ(GPIO18)はこの基板では実結線されていない事が多い(C変種のR17改造と同様)。
      // pin_int を設定すると LovyanGFX が INT=HIGH を「未タッチ」と誤判定し全く反応しなくなるため -1(ポーリング)。
      cfg.pin_int  = -1;
      cfg.spi_host = SPI2_HOST;
      cfg.pin_sclk = GPIO_NUM_12;
      cfg.pin_mosi = GPIO_NUM_11;
      cfg.pin_miso = GPIO_NUM_13;
      cfg.pin_cs   = GPIO_NUM_38;
      cfg.freq     = 1000000;              // XPT2046 は 1〜2.5MHz
      cfg.x_min = 300;  cfg.x_max = 3900;  // 生ADCの目安(calibrateTouchで上書きされる)
      cfg.y_min = 300;  cfg.y_max = 3900;
      _touch_instance.config(cfg);
      _panel_instance.setTouch(&_touch_instance);
    }

    setPanel(&_panel_instance);
  }
};
