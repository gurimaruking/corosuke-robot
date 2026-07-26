#!/usr/bin/env python3
"""
serial_bridge_node — ROS 2 -> ESP32-S3 目コプロセッサ (UART/USB)

コロ助の目ファーム(firmware/corosuke_eyes)は「テキスト行」プロトコル:
  emo <neutral|happy|sad|angry|surprised|sleepy|thinking|dead>
  gaze <x> <y>        (-1.0..1.0)
  blink
  idle <on|off>
本ノードは /korosuke/eye_cmd (korosuke_msgs/EyeCmd) を購読して、上記行を
115200bps で書き込むだけ。デバイス未接続でも起動し、定期的に再接続を試みる。
差分だけ送るので UART は詰まらない。
"""
import glob
import rclpy
from rclpy.node import Node
from korosuke_msgs.msg import EyeCmd

try:
    import serial  # pyserial
except ImportError:
    serial = None


class SerialBridge(Node):
    def __init__(self):
        super().__init__('serial_bridge_node')
        self.declare_parameter('port', 'auto')     # 'auto' で ttyUSB*/ttyACM* 自動選択
        self.declare_parameter('baud', 115200)
        self.declare_parameter('idle_on_start', True)
        self._ser = None
        self._last_emo = None
        self._last_gaze = None
        self.create_subscription(EyeCmd, '/korosuke/eye_cmd', self.on_eye, 10)
        # 1秒ごとに接続維持を試みる
        self.create_timer(1.0, self._ensure_open)
        self.get_logger().info('serial_bridge_node 起動 (目UARTブリッジ)')

    # ---- シリアル接続維持 ----
    def _pick_port(self):
        p = self.get_parameter('port').value
        if p != 'auto':
            return p
        cands = sorted(glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*'))
        return cands[0] if cands else None

    def _ensure_open(self):
        if self._ser and self._ser.is_open:
            return
        if serial is None:
            self.get_logger().warn('pyserial 未インストール', once=True)
            return
        port = self._pick_port()
        if not port:
            self.get_logger().warn('目デバイス(ttyUSB/ACM)が見つからない — 接続待ち', throttle_duration_sec=10)
            return
        try:
            self._ser = serial.Serial(port, self.get_parameter('baud').value, timeout=0.2)
            self.get_logger().info(f'目デバイス接続: {port}')
            self._last_emo = self._last_gaze = None
            if self.get_parameter('idle_on_start').value:
                self._write('idle on')
        except Exception as e:  # noqa
            self.get_logger().warn(f'接続失敗 {port}: {e}', throttle_duration_sec=10)
            self._ser = None

    def _write(self, line: str):
        if not (self._ser and self._ser.is_open):
            return
        try:
            self._ser.write((line + '\n').encode('ascii', 'ignore'))
        except Exception as e:  # noqa
            self.get_logger().warn(f'書込み失敗: {e}')
            try:
                self._ser.close()
            finally:
                self._ser = None

    # ---- EyeCmd 受信 ----
    def on_eye(self, msg: EyeCmd):
        self._ensure_open()
        emo = (msg.emotion or '').strip().lower()
        valid = {'neutral', 'happy', 'sad', 'angry', 'surprised', 'sleepy',
                 'thinking', 'dead'}   # thinking=考え中(LLM推論中), dead=✕✕(終了)
        if emo in valid and emo != self._last_emo:
            self._write(f'emo {emo}')
            self._last_emo = emo
        gaze = (round(msg.gaze_x, 2), round(msg.gaze_y, 2))
        if gaze != self._last_gaze:
            self._write(f'gaze {gaze[0]} {gaze[1]}')
            self._last_gaze = gaze
        if msg.blink:
            self._write('blink')


def main(args=None):
    rclpy.init(args=args)
    node = SerialBridge()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if node._ser:
            try:
                node._ser.close()
            except Exception:  # noqa
                pass
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
