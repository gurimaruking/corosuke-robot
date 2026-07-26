from setuptools import setup
import os
from glob import glob

package_name = 'korosuke_nodes'

setup(
    name=package_name,
    version='1.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
        (os.path.join('share', package_name, 'web'), glob('web/*.html')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Kazuki Murata',
    maintainer_email='murata@tenpa.jp',
    description='Korosuke cognitive core nodes on RDK X5',
    license='CC BY 4.0',
    entry_points={
        'console_scripts': [
            'serial_bridge = korosuke_nodes.serial_bridge_node:main',
            'vision       = korosuke_nodes.vision_node:main',
            'brain        = korosuke_nodes.brain_node:main',
            'dialogue     = korosuke_nodes.dialogue_node:main',
            'voice        = korosuke_nodes.voice_node:main',
            'eye_demo     = korosuke_nodes.eye_demo_node:main',
        ],
    },
)
