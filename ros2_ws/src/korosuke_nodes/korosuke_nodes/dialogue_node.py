#!/usr/bin/env python3
"""
dialogue_node — コロ助の対話脳 (**完全オンデバイス**, LLM = TinySwallow-1.5B / llama.cpp CPU)

入力:
  /korosuke/greet     (std_msgs/String) … brain が人検出時に出す発話トリガ
  /korosuke/user_text (std_msgs/String) … STT や手入力からのユーザー発話
出力:
  /korosuke/say_text  (std_msgs/String) … コロ助のセリフ("〜ナリ") → voice_node へ
  /korosuke/eye_cmd   (EyeCmd)          … セリフに合った表情 → 目に反映

クラウドAPI(Anthropic等)には一切依存しない。モノリス
scripts/korosuke_monitor.py と同じモデル(TinySwallow Q5 gguf)・同じ人格
プロンプト・same few-shot を使い、llama.cpp(llama_cpp)でCPU推論する。
モデルが無い/ロード失敗時は定型の「ナリ」応答にフォールバックし、
パイプライン自体は止めない。推論は別スレッドで実行しスピンをブロックしない。

パラメータ:
  llm_model    gguf モデルパス (default personality.LLM_MODEL_DEFAULT)
  n_ctx        コンテキスト長 (default 1024)
  n_threads    CPUスレッド数 (default 6)
  max_tokens   生成上限 (default 64)
  temperature  (default 0.7)   top_p (default 0.9)
"""
import threading

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from korosuke_msgs.msg import EyeCmd

from korosuke_nodes.personality import (
    LLM_MODEL_DEFAULT, LLM_PERSONA, LLM_FEWSHOT, detect_eye_emotion,
)

FALLBACK_GREET = "ワガハイはコロ助ナリ！よろしくナリ！"
FALLBACK_REPLY = "なるほどナリ！ワガハイもそう思うナリ！"


class Dialogue(Node):
    def __init__(self):
        super().__init__('dialogue_node')
        self.declare_parameter('llm_model', LLM_MODEL_DEFAULT)
        self.declare_parameter('n_ctx', 1024)
        self.declare_parameter('n_threads', 6)
        self.declare_parameter('max_tokens', 64)
        self.declare_parameter('temperature', 0.7)
        self.declare_parameter('top_p', 0.9)

        self.say = self.create_publisher(String, '/korosuke/say_text', 10)
        self.eye = self.create_publisher(EyeCmd, '/korosuke/eye_cmd', 10)
        self.create_subscription(String, '/korosuke/greet', self.on_greet, 10)
        self.create_subscription(String, '/korosuke/user_text', self.on_user, 10)

        self.history = []          # [{role, content}]
        self._model = None
        self._ready = False
        self._busy = False
        # モデルロードは重い(数百MB)ので別スレッドで。ロード中もノードは生きる。
        threading.Thread(target=self._load_model, daemon=True).start()

    # ---- LLM ロード(別スレッド, 完全オンデバイス) ----
    def _load_model(self):
        path = self.get_parameter('llm_model').value
        try:
            from llama_cpp import Llama
            m = Llama(
                model_path=path,
                n_ctx=int(self.get_parameter('n_ctx').value),
                n_threads=int(self.get_parameter('n_threads').value),
                verbose=False)
            self._model = m
            self._ready = True
            self.get_logger().info(f'dialogue_node: TinySwallow ready (on-device, {path})')
        except Exception as e:  # noqa
            self.get_logger().warn(
                f'LLMロード失敗→定型ナリ応答モードで継続 ({path}): {e}')

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
        if self._busy:
            return
        if not self._ready:
            self._emit(FALLBACK_REPLY)          # まだロード中/失敗 → 定型
            return
        self._busy = True
        threading.Thread(target=self._ask, args=(user_text,), daemon=True).start()

    def _ask(self, user_text: str):
        # 考え中の目(瞳がくるくる)を出してから推論
        self.eye.publish(EyeCmd(emotion='thinking', gaze_x=0.0, gaze_y=0.0, blink=False))
        try:
            self.history.append({"role": "user", "content": user_text})
            self.history = self.history[-8:]
            r = self._model.create_chat_completion(
                messages=[{"role": "system", "content": LLM_PERSONA}]
                         + LLM_FEWSHOT
                         + self.history,
                max_tokens=int(self.get_parameter('max_tokens').value),
                temperature=float(self.get_parameter('temperature').value),
                top_p=float(self.get_parameter('top_p').value))
            reply = r["choices"][0]["message"]["content"].strip()
            if reply:
                self.history.append({"role": "assistant", "content": reply})
                self._emit(reply)
            else:
                self.eye.publish(EyeCmd(emotion='neutral', gaze_x=0.0, gaze_y=0.0, blink=False))
        except Exception as e:  # noqa
            self.get_logger().warn(f'LLM生成失敗→定型: {e}')
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
