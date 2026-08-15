cmake_minimum_required(VERSION 3.0.2)
project(fs150_mocap)

find_package(catkin REQUIRED)
catkin_package()

catkin_install_python(PROGRAMS
  scripts/vision_pose_forward
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
