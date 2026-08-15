cmake_minimum_required(VERSION 3.0.2)
project(fs150_onboard_autostart)

find_package(catkin REQUIRED)
catkin_package()

install(PROGRAMS
  scripts/wait-device
  scripts/start-communication
  scripts/start-mavros
  scripts/start-camera
  scripts/start-media-edge
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(FILES
  config/onboard.env
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

install(DIRECTORY systemd
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
