#!/usr/bin/env python3
"""
brain_node — コロ助の頭。
入力: /korosuke/face_pose (FacePose)
出力:
  /korosuke/eye_cmd (EyeCmd)      … 検出した人を目で追う。居れば happy、不在で neutral。
  /korosuke/greet   (std_msgs/String) … 人が新たに現れたら発話トリガ("こんにちは")

視線は顔位置を反転して自然な追従に。人の出入りにヒステリシスを持たせ、
現れた瞬間に1回だけ挨拶する(連呼しない)。
"""
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from korosuke_msgs.msg import EyeCmd, FacePose


class Brain(Node):
    def __init__(self):
        super().__init__('brain_node')
        self.declare_parameter('greet_text', 'だれか来たナリ！')
        self.eye = self.create_publisher(EyeCmd, '/korosuke/eye_cmd', 10)
        self.greet = self.create_publisher(String, '/korosuke/greet', 10)
        self.create_subscription(FacePose, '/korosuke/face_pose', self.on_face, 10)
        self._present = False
        self._absent_count = 0
        self._blink_toggle = False
        self.get_logger().info('brain_node 起動')

    def on_face(self, f: FacePose):
        cmd = EyeCmd()
        if f.detected:
            # 顔の水平/垂直を視線へ(少し控えめに、上下は反転しすぎない)
            cmd.emotion = 'happy'
            cmd.gaze_x = max(-1.0, min(1.0, f.x))
            cmd.gaze_y = max(-1.0, min(1.0, 0.4 * f.y))
            cmd.blink = False
            self._absent_count = 0
            if not self._present:
                self._present = True
                self.get_logger().info('人を検出 → 挨拶')
                self.greet.publish(String(data=self.get_parameter('greet_text').value))
                cmd.blink = True   # 気づいた合図に1回まばたき
        else:
            # 数フレーム連続で不在なら neutral に戻す(チラつき防止)
            self._absent_count += 1
            if self._absent_count >= 8:
                self._present = False
            cmd.emotion = 'neutral' if not self._present else 'happy'
            cmd.gaze_x = 0.0
            cmd.gaze_y = 0.0
            cmd.blink = False
        self.eye.publish(cmd)


def main(args=None):
    rclpy.init(args=args)
    node = Brain()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
