cmake_minimum_required(VERSION 3.8)
project(korosuke_msgs)

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/EyeCmd.msg"
  "msg/FacePose.msg"
)

ament_package()
