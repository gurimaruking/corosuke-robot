#!/usr/bin/env python3
"""
voice_node — コロ助の声 (**完全オンデバイス** TTS = Open JTalk)

入力: /korosuke/say_text (std_msgs/String)
動作: Open JTalk で日本語テキストを動的合成(→WAV)し、aplay 等で再生する。
      VOICEVOX(別サーバ)には依存しない。モノリス scripts/korosuke_monitor.py
      と同じバイナリ/辞書/音声・同じ声パラメータ(-fm/-a/-r)を使う。
      open_jtalk や再生プレイヤが無くてもクラッシュせずログのみ
      (デモは目+セリフ表示で成立)。

パラメータ:
  oj_bin   (default personality.OJ_BIN = "open_jtalk")
  oj_dic   (default personality.OJ_DIC)
  oj_voice (default personality.OJ_VOICE)
  fm       声の高さ  (default personality.OJ_FM = 9)
  a        声道長    (default personality.OJ_A  = 0.40)
  r        話速      (default personality.OJ_R  = 1.12)
"""
import os
import shutil
import tempfile
import threading
import subprocess

import rclpy
from rclpy.node import Node
from std_msgs.msg import String

from korosuke_nodes.personality import OJ_BIN, OJ_DIC, OJ_VOICE, OJ_FM, OJ_A, OJ_R


class Voice(Node):
    def __init__(self):
        super().__init__('voice_node')
        self.declare_parameter('oj_bin', OJ_BIN)
        self.declare_parameter('oj_dic', OJ_DIC)
        self.declare_parameter('oj_voice', OJ_VOICE)
        self.declare_parameter('fm', OJ_FM)
        self.declare_parameter('a', OJ_A)
        self.declare_parameter('r', OJ_R)
        self.create_subscription(String, '/korosuke/say_text', self.on_say, 10)
        self._player = self._find_player()
        self._lock = threading.Lock()
        self.get_logger().info(
            f'voice_node 起動 (on-device Open JTalk, player={self._player})')

    def _find_player(self):
        for p in ('aplay', 'paplay', 'ffplay'):
            if shutil.which(p):
                return p
        return None

    def on_say(self, msg: String):
        text = (msg.data or '').strip()
        if text:
            threading.Thread(target=self._speak, args=(text,), daemon=True).start()

    def _speak(self, text: str):
        oj = self.get_parameter('oj_bin').value
        if not shutil.which(oj):
            self.get_logger().warn('open_jtalk 未インストール(セリフのみ)', once=True)
            return
        with self._lock:
            wav = None
            try:
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
                    wav = f.name
                p = subprocess.run(
                    [oj,
                     '-x', self.get_parameter('oj_dic').value,
                     '-m', self.get_parameter('oj_voice').value,
                     '-fm', str(self.get_parameter('fm').value),
                     '-a', str(self.get_parameter('a').value),
                     '-r', str(self.get_parameter('r').value),
                     '-ow', wav],
                    input=(text + '\n').encode('utf-8'),
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                if p.returncode == 0 and os.path.exists(wav) and os.path.getsize(wav) > 0:
                    self._play(wav)
                else:
                    self.get_logger().warn('Open JTalk 合成失敗(セリフのみ)',
                                           throttle_duration_sec=10)
            except Exception as e:  # noqa
                self.get_logger().warn(f'TTS失敗(セリフのみ): {e}',
                                       throttle_duration_sec=10)
            finally:
                if wav:
                    try:
                        os.unlink(wav)
                    except OSError:
                        pass

    def _play(self, wav: str):
        if not self._player:
            self.get_logger().warn('再生プレイヤ(aplay等)無し', once=True)
            return
        subprocess.run([self._player, wav], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main(args=None):
    rclpy.init(args=args)
    node = Voice()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
