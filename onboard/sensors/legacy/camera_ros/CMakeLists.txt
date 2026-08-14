cmake_minimum_required(VERSION 3.0.2)
project(camera_ros)

find_package(catkin REQUIRED COMPONENTS
    roscpp
    sensor_msgs
    cv_bridge
    image_transport
    )

find_package(OpenCV REQUIRED)

catkin_package(
   #INCLUDE_DIRS include
   #LIBRARIES px4ctrl
   #CATKIN_DEPENDS
   #DEPENDS std_msgs
)

include_directories(
    include
    ${OpenCV_INCLUDE_DIRS}
    ${catkin_INCLUDE_DIRS}
)

add_executable(${PROJECT_NAME}_node
    src/v4l2.cpp
    src/main.cpp
    )
add_dependencies(${PROJECT_NAME}_node ${${PROJECT_NAME}_EXPORTED_TARGETS} ${catkin_EXPORTED_TARGETS})

target_link_libraries(${PROJECT_NAME}_node
    ${OpenCV_LIBS}
    ${catkin_LIBRARIES}
    pthread
    )

install(TARGETS ${PROJECT_NAME}_node
  RUNTIME DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)
install(DIRECTORY launch cfg
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
