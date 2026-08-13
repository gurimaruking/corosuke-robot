/**
 * LovyanGFX パネル定義 — Sunton ESP32-1732S019 (1.9" 170x320 ST7789 SPI)
 *
 * 4827S043(RGBパラレル)と違いSPI接続なので、GPIOが約20本ヘッダに出ているのが利点。
 * タッチ非搭載(getTouchは常にfalse → main.cppのpollTouchは無害に空振り)。
 *
 * ピン(Sunton回路図/Arduino_GFX・ESPHome既知設定より):
 *   SCLK=12  MOSI=13  DC=11  CS=10  RST=1  BL=14(PWM)  MISO=なし
 * パネルはST7789の240x320メモリのうち170幅を使うため offset_x=35。IPSなので invert=true。
 * 本FWは横長で使う → main.cpp側で setRotation(1) して 320x170 として描画。
 */
#pragma once
#ifndef LGFX_USE_V1
#define LGFX_USE_V1
#endif
#include <LovyanGFX.hpp>

class LGFX : public lgfx::LGFX_Device {
public:
  lgfx::Bus_SPI      _bus_instance;
  lgfx::Panel_ST7789 _panel_instance;
  lgfx::Light_PWM    _light_instance;

  LGFX(void) {
    { // ---- SPIバス ----
      auto cfg = _bus_instance.config();
      cfg.spi_host    = SPI2_HOST;
      cfg.spi_mode    = 0;
      cfg.freq_write  = 40000000;   // ST7789は40MHz安定(80MHzも通ることが多いがまず安全側)
      cfg.freq_read   = 16000000;
      cfg.spi_3wire   = false;
      cfg.use_lock    = true;
      cfg.dma_channel = SPI_DMA_CH_AUTO;
      cfg.pin_sclk = GPIO_NUM_12;
      cfg.pin_mosi = GPIO_NUM_13;
      cfg.pin_miso = -1;
      cfg.pin_dc   = GPIO_NUM_11;
      _bus_instance.config(cfg);
      _panel_instance.setBus(&_bus_instance);
    }
    { // ---- パネル ST7789 (170x320, オフセット35) ----
      auto cfg = _panel_instance.config();
      cfg.pin_cs   = GPIO_NUM_10;
      cfg.pin_rst  = GPIO_NUM_1;
      cfg.pin_busy = -1;
      cfg.memory_width  = 240;   // ST7789の内蔵GRAMは240x320
      cfg.memory_height = 320;
      cfg.panel_width   = 170;
      cfg.panel_height  = 320;
      cfg.offset_x = 35;         // (240-170)/2
      cfg.offset_y = 0;
      cfg.offset_rotation = 0;
      cfg.readable   = false;
      cfg.invert     = true;     // IPSパネル
      cfg.rgb_order  = false;
      cfg.dlen_16bit = false;
      cfg.bus_shared = false;
      _panel_instance.config(cfg);
    }
    { // ---- バックライト(PWM) ----
      auto cfg = _light_instance.config();
      cfg.pin_bl = GPIO_NUM_14;
      cfg.invert = false;
      _light_instance.config(cfg);
      _panel_instance.light(&_light_instance);
    }
    setPanel(&_panel_instance);
  }
};
