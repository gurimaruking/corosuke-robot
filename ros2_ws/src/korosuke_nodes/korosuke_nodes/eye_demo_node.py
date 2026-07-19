#!/usr/bin/env python3
"""
eye_demo_node — M2 動作実証。/korosuke/eye_cmd に感情/視線/まばたきを順に発行。
vision が無くても「ROS 2 topic を出すと目が反応する」ことを見せるデモ。
  ros2 run korosuke_nodes eye_demo
"""
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from korosuke_msgs.msg import EyeCmd

SEQ = [
    ('neutral',  0.0,  0.0, False),
    ('happy',    0.0,  0.0, True),
    ('happy',    0.6,  0.0, False),
    ('surprised',-0.6, 0.0, True),
    ('sad',      0.0,  0.3, False),
    ('angry',    0.0, -0.2, True),
    ('sleepy',   0.0,  0.4, False),
    ('neutral',  0.0,  0.0, True),
]


class EyeDemo(Node):
    def __init__(self):
        super().__init__('eye_demo_node')
        self.pub = self.create_publisher(EyeCmd, '/korosuke/eye_cmd', 10)
        self.i = 0
        self.create_timer(1.5, self.tick)
        self.get_logger().info('eye_demo_node 起動 — 1.5秒ごとに表情を発行')

    def tick(self):
        emo, gx, gy, blink = SEQ[self.i % len(SEQ)]
        m = EyeCmd(emotion=emo, gaze_x=float(gx), gaze_y=float(gy), blink=blink)
        self.pub.publish(m)
        self.get_logger().info(f'-> emo={emo} gaze=({gx},{gy}) blink={blink}')
        self.i += 1


def main(args=None):
    rclpy.init(args=args)
    node = EyeDemo()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass   # SIGINT/SIGTERM(timeout等)はどちらも正常終了扱い
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
