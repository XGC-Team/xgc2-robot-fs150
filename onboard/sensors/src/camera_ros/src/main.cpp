#include <opencv2/core/core.hpp>

#include <iostream>
#include "v4l2.h"

#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#include <thread>
#include <signal.h>
#include <limits>

#include <chrono>
#include <sys/time.h>
#include <ctime>

#include "ros/ros.h"
#include <sensor_msgs/Image.h>
#include <image_transport/image_transport.h>
#include <cv_bridge/cv_bridge.h>

bool is_exit = false;

void signalHandler(int signal)
{

  std::cout << "recv Ctrl + C signal" << std::endl;
  is_exit = true;
}

void Int2UnChar(std::vector<uchar> &out, std::vector<int> &in)
{
  for (size_t i = 0; i < in.size(); ++i)
  {
    out.push_back(((uchar *)(&in[i]))[0]);
    out.push_back(((uchar *)(&in[i]))[1]);
    out.push_back(((uchar *)(&in[i]))[2]);
    out.push_back(((uchar *)(&in[i]))[3]);
  }
}

void SendImgThread(dronyee::v4l2 *cam, const image_transport::Publisher *pub)
{

  // 初始化 v4l2
  int ret;
  int width = 640, height = 480,
      format = V4L2_PIX_FMT_NV12; // V4L2_PIX_FMT_NV12 V4L2_PIX_FMT_YUYV
  std::cout << "cam objects" << cam->video_name << std::endl;
  ret = cam->v4l2Capability();
  if (ret < 0)
  {
    std::cout << "v4l2Capability error" << std::endl;
  }
  else
  {
    std::cout << "v4l2Capability success" << std::endl;
  }

  cam->getAllFormat();

  ret = cam->setParameters(width, height, format);
  if (ret < 0)
  {
    std::cout << "setParameters error" << std::endl;
  }
  else
  {
    std::cout << "setParameters success" << std::endl;
  }

  cam->getParameters();
  ret = cam->mmapBuffersPreview1();
  if (ret < 0)
  {
    std::cout << "mmapBuffersPreview error" << std::endl;
  }
  else
  {
    std::cout << "mmapBuffersPreview success" << std::endl;
  }

  ret = cam->startPreview();
  if (ret < 0)
  {
    std::cout << "startPreview error" << std::endl;
  }
  else
  {
    std::cout << "startPreview success" << std::endl;
  }
  std::cout << "start read the device " << std::endl;
  static uint32_t seq_id = 0;

  while (!ros::isShuttingDown() && !is_exit)
  {
    int bytesused;
    cv::Mat img;
    bool read_cam = cam->GetFrame(bytesused, img);
    if (!read_cam)
    {
      std::cout << "not read data" << std::endl;
      return;
      // continue;
    }

    sensor_msgs::ImagePtr msg = cv_bridge::CvImage(std_msgs::Header(), "bgr8", img).toImageMsg();
    msg->header.seq = seq_id;
    msg->header.stamp = ros::Time::now();
    pub->publish(msg);
    ros::spinOnce();
    auto ret = cam->UnGetFrame();
    if (ret < 0)
    {
      std::cout << "UnGetFrame error" << std::endl;
    }
    ++seq_id;
  }

  delete cam;
}

int main(int argc, char **argv)
{
  signal(SIGINT, signalHandler);
  // signal(SIGABRT, signalHandler);
  // signal(SIGKILL, signalHandler);
  // signal(SIGSEGV, signalHandler);

  ros::init(argc, argv, "camera_ros");
  ros::NodeHandle nh;

  std::string cfg_name;
  nh.param<std::string>("cfg_name", cfg_name, "config.yaml");
  ROS_INFO("the name of config file is %s", cfg_name.c_str());
  cv::FileStorage fs(cfg_name, cv::FileStorage::READ);

  image_transport::ImageTransport it(nh);

  if (!fs.isOpened())
  {
    std::cerr << "Failed to open file!" << std::endl;
    return -1;
  }
  // std::vector<dronyee::v4l2 *> cameras;
  std::vector<std::thread *> ths;
  // 从文件中读取数据
  cv::FileNode camera1 = fs["camera1"];
  cv::FileNode camera2 = fs["camera2"];

  bool cam_enable = false;
  camera1["enable"] >> cam_enable;
  if (cam_enable)
  {
    std::cout << "open the camera1" << std::endl;
    std::string device;
    camera1["file_name"] >> device;
    dronyee::v4l2 *cam = new dronyee::v4l2(device);
    std::cout << "device: " << cam->video_name << std::endl;

    static image_transport::Publisher img_pub_1 = it.advertise("camera1/image", 1);
    //     cameras.push_back(cam);
    auto t =
        new std::thread(SendImgThread, cam, &img_pub_1);
    ths.push_back(t);
  }
  cam_enable = false;
  camera2["enable"] >> cam_enable;
  if (cam_enable)
  {
    std::cout << "open the camera2" << std::endl;
    std::string device;
    camera2["file_name"] >> device;
    dronyee::v4l2 *cam = new dronyee::v4l2(device);
    ;
    std::cout << "device: " << cam->video_name << std::endl;
    static image_transport::Publisher img_pub_2 = it.advertise("camera2/image", 1);
    auto t =
        new std::thread(SendImgThread, cam, &img_pub_2);
    ths.push_back(t);
  }

  if (ths.size() == 1)
  {
    ths[0]->join();
    delete ths[0];
  }
  if (ths.size() > 1)
  {
    ths[0]->detach();
    ths[1]->join();
    delete ths[0];
    delete ths[1];
  }
  ros::spin();
  ros::shutdown();
  return 0;
}
