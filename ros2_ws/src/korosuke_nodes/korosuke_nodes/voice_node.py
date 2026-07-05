#!/usr/bin/env python3
"""
voice_node — コロ助の声 (VOICEVOX ずんだもん)

入力: /korosuke/say_text (std_msgs/String)
動作: VOICEVOX の /audio_query → /synthesis で WAV を得て再生(aplay)。
      速め・高めに調整してコロ助っぽく。VOICEVOX が居なくてもクラッシュせず
      ログのみ(デモは目+セリフ表示で成立)。

パラメータ:
  voicevox_host (default http://localhost:50021)
  speaker       (default 3 = ずんだもん)
  speed         (default 1.2)  pitch (default 0.05)
"""
import os
import json
import shutil
import tempfile
import threading
import subprocess
import urllib.parse
import urllib.request

import rclpy
from rclpy.node import Node
from std_msgs.msg import String

from korosuke_nodes.personality import VOICEVOX_SPEAKER_ID


class Voice(Node):
    def __init__(self):
        super().__init__('voice_node')
        self.declare_parameter('voicevox_host', os.environ.get('VOICEVOX_HOST', 'http://localhost:50021'))
        self.declare_parameter('speaker', VOICEVOX_SPEAKER_ID)
        self.declare_parameter('speed', 1.2)
        self.declare_parameter('pitch', 0.05)
        self.create_subscription(String, '/korosuke/say_text', self.on_say, 10)
        self._player = self._find_player()
        self._lock = threading.Lock()
        self.get_logger().info(f'voice_node 起動 (VOICEVOX={self.get_parameter("voicevox_host").value}, player={self._player})')

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
        host = self.get_parameter('voicevox_host').value
        spk = int(self.get_parameter('speaker').value)
        try:
            # 1) audio_query
            q = urllib.parse.urlencode({'text': text, 'speaker': spk})
            req = urllib.request.Request(f'{host}/audio_query?{q}', method='POST')
            with urllib.request.urlopen(req, timeout=10) as r:
                query = json.loads(r.read().decode('utf-8'))
            query['speedScale'] = float(self.get_parameter('speed').value)
            query['pitchScale'] = float(self.get_parameter('pitch').value)
            # 2) synthesis
            req2 = urllib.request.Request(
                f'{host}/synthesis?speaker={spk}',
                data=json.dumps(query).encode('utf-8'),
                headers={'Content-Type': 'application/json'}, method='POST')
            with urllib.request.urlopen(req2, timeout=30) as r:
                wav = r.read()
            self._play(wav)
        except Exception as e:  # noqa
            self.get_logger().warn(f'VOICEVOX無し/失敗(セリフのみ): {e}', throttle_duration_sec=10)

    def _play(self, wav: bytes):
        if not self._player:
            self.get_logger().warn('再生プレイヤ(aplay等)無し', once=True)
            return
        with self._lock:
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
                f.write(wav)
                path = f.name
            try:
                subprocess.run([self._player, path], check=False,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            finally:
                try:
                    os.unlink(path)
                except OSError:
                    pass


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
