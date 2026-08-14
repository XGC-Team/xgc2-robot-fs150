#pragma once
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h> //memset
#include <fcntl.h>  //open
#include <unistd.h> //close

#include <linux/videodev2.h> //v4l2
#include <sys/ioctl.h>       //ioctl
#include <sys/mman.h>        //mmap

#include <iostream>

#include <stdio.h>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/opencv.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>


#define CLEAR(x) memset(&(x), 0, sizeof(x))
#define FMT_NUM_PLANES 1
#define BUFFER_COUNT 4
//打开设备－> 检查和设置设备属性－> 设置相关参数－> 获取数据方法－> 循环获取数据－> 关闭设备。
namespace dronyee
{

    struct VideoInfo
    {
        struct v4l2_capability cap;    // 视频设备的基本功能等信息
        struct v4l2_format format;     // 帧格式、长宽等信息
        struct v4l2_fmtdesc fmtdesc;   // 枚举当前设备所支持的所有的帧格式
        struct v4l2_buffer buf;        // 驱动中的一帧图像缓存
        struct v4l2_requestbuffers rb; // 申请帧缓存
        void *mem[BUFFER_COUNT];       // 驱动映射后的应用层使用的地址  //=num
        bool isStreaming;              //当前是否有数据流
        int width;                     // 帧宽,可校验用
        int height;                    // 帧高
        int formatIn;                  // 设置的帧格式类型
        int framesizeIn;               //帧图像大小
    };
    struct buffer
    {
        void *start;
        size_t length;
        struct v4l2_buffer v4l2_buf;
    };

    class v4l2
    {
    private:
        VideoInfo *mVideoInfo;
        int fd;
        //int ret;
        enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        int n_buffers;
        struct buffer *buffers;
        FILE *fp = NULL;

    public:
        //打开设备  /dev/video0
        v4l2(const std::string &device);
        ~v4l2();

        //初始化接口，获取基本的设备信息
        int v4l2Capability();
        //获取所有支持的帧格式     Num为引用值，获取支持的帧格式数量  fmt 为获取到的帧格式的实际值
        void getAllFormat();
        //设置帧图像的相关信息，帧长、帧宽以及帧格式
        int setParameters(int width, int height, int format);
        //获取验证帧图像的相关信息，帧长、帧宽以及帧格式
        int getParameters();
        //	申请缓存帧图形的buffer并映射到应用程序（用户空间）// num建议小于5
        int mmapBuffersPreview1();
        int mmapBuffersPreview2(int num);
        //将前面申请的帧缓存buf加入视频采集输出队列
        //启动视频设备开始采集（重复）
        int startPreview();

        //从视频采集输出队列中取出已含有采集数据的帧缓冲区（重复）
        bool GetFrame(int &bytesused,cv::Mat &img);

        //讲取过的帧缓冲区重新挂入输入队列（重复）
        int UnGetFrame();

    private:
        //关闭视频设备并断开内存映射
        int stopPreview();

    public:
        std::string video_name;  // /dev/video 下的文件描述符
        uint16_t img_width;
        uint16_t img_height;
		std::vector<int> param;
    };

}
