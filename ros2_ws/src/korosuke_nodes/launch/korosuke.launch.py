"""
コロ助 統合デモ launch
  vision → brain → (eye_cmd → serial_bridge → 目) / (greet → dialogue → voice)

使い方:
  ros2 launch korosuke_nodes korosuke.launch.py
オプション(引数):
  camera:=0  eye_port:=auto  with_voice:=true  with_dialogue:=true
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

    from launch_ros.actions import Node
    return LaunchDescription([
        DeclareLaunchArgument('camera', default_value='0'),
        DeclareLaunchArgument('eye_port', default_value='auto'),
        DeclareLaunchArgument('with_voice', default_value='true'),
        DeclareLaunchArgument('with_dialogue', default_value='true'),

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
    ])
