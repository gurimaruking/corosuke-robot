"""
コロ助 統合デモ launch (完全オンデバイス)
  vision → brain → (eye_cmd → serial_bridge → 目) / (greet/user_text → dialogue → voice)
  dialogue = TinySwallow(llama.cpp) / voice = Open JTalk。クラウド非依存。

使い方:
  ros2 launch korosuke_nodes korosuke.launch.py
オプション(引数):
  camera:=0  eye_port:=auto  with_voice:=true  with_dialogue:=true
  with_web:=true   … rosbridge(WebSocket 9090)を同時起動。
                     ブラウザで web/console.html を開き ws://<board-ip>:9090 に接続すると
                     話しかけ/目の表情/監視をWebから操作できる。
                     ※ 事前に `sudo apt install ros-humble-rosbridge-suite` が必要。
"""
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration


def generate_launch_description():
    camera = LaunchConfiguration('camera')
    eye_port = LaunchConfiguration('eye_port')
    with_voice = LaunchConfiguration('with_voice')
    with_dialogue = LaunchConfiguration('with_dialogue')
    with_web = LaunchConfiguration('with_web')

    from launch_ros.actions import Node
    return LaunchDescription([
        DeclareLaunchArgument('camera', default_value='0'),
        DeclareLaunchArgument('eye_port', default_value='auto'),
        DeclareLaunchArgument('with_voice', default_value='true'),
        DeclareLaunchArgument('with_dialogue', default_value='true'),
        DeclareLaunchArgument('with_web', default_value='false'),

        Node(package='korosuke_nodes', executable='vision', name='vision_node',
             parameters=[{'camera': camera}], output='screen'),
        Node(package='korosuke_nodes', executable='brain', name='brain_node',
             output='screen'),
        Node(package='korosuke_nodes', executable='serial_bridge', name='serial_bridge_node',
             parameters=[{'port': eye_port}], output='screen'),
        Node(package='korosuke_nodes', executable='dialogue', name='dialogue_node',
             condition=IfCondition(with_dialogue), output='screen'),
        Node(package='korosuke_nodes', executable='voice', name='voice_node',
             condition=IfCondition(with_voice), output='screen'),

        # --- Web操作卓(rosbridge): with_web:=true のときだけ起動 ---
        # 生WebSocketのrosbridgeプロトコルで web/console.html から pub/sub する。
        # rosapi はトピック一覧等の補助(pub/subだけなら無くても可)。
        Node(package='rosbridge_server', executable='rosbridge_websocket',
             name='rosbridge_websocket', output='screen',
             parameters=[{'port': 9090}],
             condition=IfCondition(with_web)),
        Node(package='rosapi', executable='rosapi_node', name='rosapi',
             condition=IfCondition(with_web)),
    ])
