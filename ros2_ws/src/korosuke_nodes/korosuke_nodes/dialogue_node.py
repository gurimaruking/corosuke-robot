#!/usr/bin/env python3
"""
dialogue_node — コロ助の対話脳 (on-device, LLM = Claude haiku)

入力:
  /korosuke/greet     (std_msgs/String) … brain が人検出時に出す発話トリガ
  /korosuke/user_text (std_msgs/String) … STT や手入力からのユーザー発話
出力:
  /korosuke/say_text  (std_msgs/String) … コロ助のセリフ("〜ナリ") → voice_node へ
  /korosuke/eye_cmd   (EyeCmd)          … セリフに合った表情 → 目に反映

APIキー(ANTHROPIC_API_KEY)が無い/ネット不通なら、定型の「ナリ」応答にフォールバック。
依存を増やさないため標準ライブラリ urllib のみ使用。LLM呼出は別スレッドで
実行し、ROS のスピンをブロックしない。
"""
import os
import json
import threading
import urllib.request
import urllib.error

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from korosuke_msgs.msg import EyeCmd

from korosuke_nodes.personality import (
    COROSUKE_SYSTEM_PROMPT, detect_eye_emotion,
)

FALLBACK_GREET = "ワガハイはコロ助ナリ！よろしくナリ！"
FALLBACK_REPLY = "なるほどナリ！ワガハイもそう思うナリ！"
MODEL = "claude-3-haiku-20240307"


class Dialogue(Node):
    def __init__(self):
        super().__init__('dialogue_node')
        self.declare_parameter('model', MODEL)
        self.declare_parameter('max_tokens', 120)
        self.say = self.create_publisher(String, '/korosuke/say_text', 10)
        self.eye = self.create_publisher(EyeCmd, '/korosuke/eye_cmd', 10)
        self.create_subscription(String, '/korosuke/greet', self.on_greet, 10)
        self.create_subscription(String, '/korosuke/user_text', self.on_user, 10)
        self.history = []          # [{role, content}]
        self.api_key = os.environ.get('ANTHROPIC_API_KEY', '').strip()
        self._busy = False
        if self.api_key:
            self.get_logger().info('dialogue_node 起動 (Claude haiku on-device)')
        else:
            self.get_logger().warn('ANTHROPIC_API_KEY 未設定 → 定型ナリ応答モード')

    # ---- トリガ ----
    def on_greet(self, msg: String):
        # 挨拶は即レスしたいので、まず定型を出しつつLLMにも投げる
        self._emit(FALLBACK_GREET)
        self._ask_async("(あなたの前に人が現れた。元気よく短く挨拶して)")

    def on_user(self, msg: String):
        text = (msg.data or '').strip()
        if text:
            self._ask_async(text)

    # ---- LLM 呼び出し(別スレッド) ----
    def _ask_async(self, user_text: str):
        if self._busy or not self.api_key:
            if not self.api_key:
                self._emit(FALLBACK_REPLY)
            return
        self._busy = True
        threading.Thread(target=self._ask, args=(user_text,), daemon=True).start()

    def _ask(self, user_text: str):
        try:
            self.history.append({"role": "user", "content": user_text})
            self.history = self.history[-20:]
            body = json.dumps({
                "model": self.get_parameter('model').value,
                "max_tokens": int(self.get_parameter('max_tokens').value),
                "system": COROSUKE_SYSTEM_PROMPT,
                "messages": self.history,
            }).encode('utf-8')
            req = urllib.request.Request(
                "https://api.anthropic.com/v1/messages", data=body,
                headers={
                    "Content-Type": "application/json",
                    "x-api-key": self.api_key,
                    "anthropic-version": "2023-06-01",
                }, method="POST")
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read().decode('utf-8'))
            reply = data["content"][0]["text"].strip()
            self.history.append({"role": "assistant", "content": reply})
            self._emit(reply)
        except Exception as e:  # noqa
            self.get_logger().warn(f'LLM失敗→定型: {e}')
            self._emit(FALLBACK_REPLY)
        finally:
            self._busy = False

    # ---- 出力(セリフ+表情) ----
    def _emit(self, text: str):
        self.say.publish(String(data=text))
        emo = detect_eye_emotion(text)
        self.eye.publish(EyeCmd(emotion=emo, gaze_x=0.0, gaze_y=0.0, blink=False))
        self.get_logger().info(f'コロ助: {text}  [emo={emo}]')


def main(args=None):
    rclpy.init(args=args)
    node = Dialogue()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
