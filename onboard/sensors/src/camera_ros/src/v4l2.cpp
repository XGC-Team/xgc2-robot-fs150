#include "v4l2.h"

namespace dronyee
{
    v4l2::v4l2(const std::string &device)
    {
        //mVideoInfo = (struct VideoInfo *)calloc(1, sizeof(struct VideoInfo));
        
        video_name = device;
		std::cout << "opencv device : " << device << std::endl;
		/*
        this->fd = open("/dev/video14", O_RDWR);
        if (-1 == this->fd)
        {
            std::cout << "cannot open " << video_name << std::endl;
            exit(1);
        }*/
    }

    v4l2::~v4l2()
    {

        stopPreview();
        CLEAR(mVideoInfo);
        if (mVideoInfo != nullptr)
        {
            mVideoInfo = nullptr;
        }
        free(mVideoInfo);
        close(fd);
    }

    int v4l2::v4l2Capability()
    {
        mVideoInfo = (struct VideoInfo *)calloc(1, sizeof(struct VideoInfo));
		/*
        struct v4l2_capability cap;
  		memset(&cap,0,sizeof(cap));
		fd = open(video_name.c_str(), O_RDWR);
		std::cout << "fd : " << fd << std::endl;
  		auto ret = ioctl(fd,VIDIOC_QUERYCAP,&mVideoInfo->cap);
  		if(ret < 0)
  			{
  			std::cout << "xxxxxxxxxxxxxxxxxxxxxx" << std::endl;
  			return -1;
  			}
  		std::cout << "open finished " << std::endl;
		return -1;
		*/
		fd = open(video_name.c_str(), O_RDWR);
        auto ret = ioctl(fd, VIDIOC_QUERYCAP, &mVideoInfo->cap);
        if (ret == -1)
        {
            std::cout << "获取摄像头基本信息失败" << std::endl;
            return ret;
        }
        if (!(mVideoInfo->cap.capabilities & V4L2_CAP_VIDEO_CAPTURE))
        {
            std::cout << "该设备不是单平面视频采集设备" << std::endl;
        }
        if ((mVideoInfo->cap.capabilities & V4L2_CAP_VIDEO_CAPTURE) == V4L2_CAP_VIDEO_CAPTURE)
        {
            type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
            std::cout << "该设备为单平面视频采集设备" << std::endl;
        }
        else if ((mVideoInfo->cap.capabilities & V4L2_CAP_VIDEO_CAPTURE_MPLANE) == V4L2_CAP_VIDEO_CAPTURE_MPLANE)
        {
            type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
            std::cout << "该设备为多平面视频采集设备" << std::endl;
        }
        else
        {
            std::cout << "该设备不是视频采集设备" << std::endl;
            return -1;
        }
        if ((mVideoInfo->cap.capabilities & V4L2_CAP_STREAMING) == V4L2_CAP_STREAMING)
        {
            std::cout << "该设备支持流IO操作" << std::endl;
        }
        else
        {
            std::cout << "该设备不支持流IO操作" << std::endl;
            return -1;
        }
        printf("驱动：%s\n显卡：%s\n总线：%s\n版本：%u.%u.%u\n", mVideoInfo->cap.driver, mVideoInfo->cap.card, mVideoInfo->cap.bus_info, (mVideoInfo->cap.version >> 16) & 0XFF, (mVideoInfo->cap.version >> 8) & 0XFF, mVideoInfo->cap.version & 0XFF);
        return 0;
    }

    void v4l2::getAllFormat()
    {
        mVideoInfo->fmtdesc.index = 0;
        mVideoInfo->fmtdesc.type = type;
        std::cout << "支持的像素格式:" << std::endl;
        while (ioctl(fd, VIDIOC_ENUM_FMT, &mVideoInfo->fmtdesc) != -1)
        {
            std::cout << mVideoInfo->fmtdesc.index + 1 << " " << (char *)(mVideoInfo->fmtdesc.description) << std::endl;
            // fmt[mVideoInfo->fmtdesc.index] = mVideoInfo->fmtdesc.pixelformat;
            mVideoInfo->fmtdesc.index++;
        }
        std::cout << "support " << mVideoInfo->fmtdesc.index << " devices!" << std::endl;
        // num = mVideoInfo->fmtdesc.index;
    }

    int v4l2::setParameters(int width, int height, int format)
    {
        std::cout << "setParameters1" << std::endl;
        CLEAR(mVideoInfo->format);
        mVideoInfo->format.type = type;

        switch (mVideoInfo->format.type)
        {
        case V4L2_BUF_TYPE_VIDEO_CAPTURE:
        {
            std::cout << "format类型为：V4L2_BUF_TYPE_VIDEO_CAPTURE" << std::endl;
            mVideoInfo->format.fmt.pix.width = width;
            mVideoInfo->format.fmt.pix.height = height;
            mVideoInfo->format.fmt.pix.pixelformat = format;
            mVideoInfo->format.fmt.pix.field = V4L2_FIELD_INTERLACED;
            break;
        }
        case V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE:
        {
            std::cout << "format类型为：V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE" << std::endl;
            mVideoInfo->format.fmt.pix_mp.width = width;
            mVideoInfo->format.fmt.pix_mp.height = height;
            mVideoInfo->format.fmt.pix_mp.pixelformat = format;
            // mVideoInfo->format.fmt.pix_mp.num_planes = 1;
            mVideoInfo->format.fmt.pix_mp.field = V4L2_FIELD_INTERLACED;
            // mVideoInfo->format.fmt.pix_mp.plane_fmt[0].bytesperline = 0;

            break;
        }
        default:
            break;
        }

        mVideoInfo->width = width;
        mVideoInfo->height = height;
        mVideoInfo->formatIn = format;
        img_width = uint16_t(width);
        img_height = uint16_t(height);
        std::cout << "setParameters2" << std::endl;


        auto ret = ioctl(fd, VIDIOC_S_FMT, &mVideoInfo->format);
        if (ret < 0)
        {
            std::cout << "VIDIOC_S_FMT" << std::endl;
            return ret;
        }
        std::cout << "setParameters3" << std::endl;
        return ret;
    }
    int v4l2::getParameters()
    {
        // CLEAR(mVideoInfo->format);
        mVideoInfo->format.type = type;
        if (ioctl(fd, VIDIOC_G_FMT, &mVideoInfo->format) == -1)
        {
            std::cout << "获取摄像头格式信息失败" << std::endl;
            exit(0);
        }

        printf("fmt分辨率: %d×%d\n", mVideoInfo->format.fmt.pix.width, mVideoInfo->format.fmt.pix.height);
        printf("fmt_mp分辨率: %d×%d\n", mVideoInfo->format.fmt.pix_mp.width, mVideoInfo->format.fmt.pix_mp.height);

        printf("像素格式: ");
        switch (mVideoInfo->format.fmt.pix.pixelformat)
        {
        case V4L2_PIX_FMT_MJPEG:
            printf("V4L2_PIX_FMT_MJPEG\n");
            break;
        case V4L2_PIX_FMT_JPEG:
            printf("V4L2_PIX_FMT_JPEG\n");
            break;
        case V4L2_PIX_FMT_MPEG:
            printf("V4L2_PIX_FMT_MPEG\n");
            break;
        case V4L2_PIX_FMT_MPEG1:
            printf("V4L2_PIX_FMT_MPEG1\n");
            break;
        case V4L2_PIX_FMT_MPEG2:
            printf("V4L2_PIX_FMT_MPEG2\n");
            break;
        case V4L2_PIX_FMT_MPEG4:
            printf("V4L2_PIX_FMT_MPEG4\n");
            break;
        case V4L2_PIX_FMT_H264:
            printf("V4L2_PIX_FMT_H264\n");
            break;
        case V4L2_PIX_FMT_XVID:
            printf("V4L2_PIX_FMT_XVID\n");
            break;
        case V4L2_PIX_FMT_RGB24:
            printf("V4L2_PIX_FMT_RGB24\n");
            break;
        case V4L2_PIX_FMT_BGR24:
            printf("V4L2_PIX_FMT_BGR24\n");
            break;
        case V4L2_PIX_FMT_YUYV:
            printf("V4L2_PIX_FMT_YUYV\n");
            break;
        case V4L2_PIX_FMT_YYUV:
            printf("V4L2_PIX_FMT_YYUV\n");
            break;
        case V4L2_PIX_FMT_YVYU:
            printf("V4L2_PIX_FMT_YVYU\n");
            break;
        case V4L2_PIX_FMT_YUV444:
            printf("V4L2_PIX_FMT_YUV444\n");
            break;
        case V4L2_PIX_FMT_YUV410:
            printf("V4L2_PIX_FMT_YUV410\n");
            break;
        case V4L2_PIX_FMT_YUV420:
            printf("V4L2_PIX_FMT_YUV420\n");
            break;
        case V4L2_PIX_FMT_YVU420:
            printf("V4L2_PIX_FMT_YVU420\n");
            break;
        case V4L2_PIX_FMT_YUV422P:
            printf("V4L2_PIX_FMT_YUV422P\n");
            break;
        case V4L2_PIX_FMT_NV12:
            printf("V4L2_PIX_FMT_NV12\n");
            break;
        default:
            printf("未知\n");
        }
        return 0;
    }

    int v4l2::mmapBuffersPreview1()
    {
        CLEAR(mVideoInfo->rb);
        CLEAR(mVideoInfo->buf);
        mVideoInfo->rb.type = type;
        mVideoInfo->rb.memory = V4L2_MEMORY_MMAP;
        mVideoInfo->rb.count = BUFFER_COUNT;
        auto ret = ioctl(fd, VIDIOC_REQBUFS, &mVideoInfo->rb);
        if (ret == -1)
        {
            std::cout << "VIDIOC_REQBUFS" << std::endl;
            return ret;
        }
        if (mVideoInfo->rb.count < 2)
        {
            std::cout << "缓冲区内存不足" << std::endl;
            return -1;
        }

        buffers = (struct buffer *)calloc(mVideoInfo->rb.count, sizeof(*buffers));
        for (n_buffers = 0; n_buffers < mVideoInfo->rb.count; ++n_buffers)
        {
            struct v4l2_plane planes[FMT_NUM_PLANES];
            CLEAR(planes);

            mVideoInfo->buf.type = type;
            mVideoInfo->buf.memory = V4L2_MEMORY_MMAP;
            mVideoInfo->buf.index = n_buffers;

            if (V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE == type)
            {
                mVideoInfo->buf.m.planes = planes;
                mVideoInfo->buf.length = FMT_NUM_PLANES;
            }

            ret = ioctl(fd, VIDIOC_QUERYBUF, &mVideoInfo->buf);
            if (ret < 0)
            {
                std::cout << "VIDIOC_QUERYBUF" << std::endl;
                return ret;
            }

            if (V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE == type)
            {
                buffers[n_buffers].length = mVideoInfo->buf.length;
                buffers[n_buffers].start = mmap(NULL, mVideoInfo->buf.m.planes[0].length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mVideoInfo->buf.m.planes[0].m.mem_offset);

                // mVideoInfo->mem[n_buffers] = mmap(NULL, mVideoInfo->buf.m.planes[0].length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mVideoInfo->buf.m.planes[0].m.mem_offset);
            }
            else
            {
                buffers[n_buffers].length = mVideoInfo->buf.length;
                buffers[n_buffers].start = mmap(NULL, mVideoInfo->buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mVideoInfo->buf.m.offset);
                // mVideoInfo->mem[n_buffers] = mmap(NULL, mVideoInfo->buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, mVideoInfo->buf.m.offset);
            }
            if (MAP_FAILED == buffers[n_buffers].start)
                std::cout << "mmap" << std::endl;
        }
        //  n_buffers = BUFFER_COUNT;
        std::cout << "mmapBuffersPreview1" << std::endl;
        return 0;
        // cv::Mat raw_input(mVideoInfo->format.fmt.pix.height, mVideoInfo->format.fmt.pix.width, CV_8UC2, mVideoInfo->mem[n_buffers]);
    }

    int v4l2::startPreview()
    {
        for (int i = 0; i < n_buffers; i++)
        {
            CLEAR(mVideoInfo->buf);
            mVideoInfo->buf.index = i;
            mVideoInfo->buf.type = type;
            mVideoInfo->buf.memory = V4L2_MEMORY_MMAP; //缓冲帧放入缓冲队列
            if (V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE == type)
            {
                struct v4l2_plane planes[FMT_NUM_PLANES];

                mVideoInfo->buf.m.planes = planes;
                mVideoInfo->buf.length = FMT_NUM_PLANES;
            }
            auto ret = ioctl(fd, VIDIOC_QBUF, &mVideoInfo->buf);
            if (ret == -1)
            {
                std::cout << "ioctl VIDIOC_QBUF failed" << std::endl;
                return -1;
            }
        }
        enum v4l2_buf_type bufType;
        bufType = type;
        auto ret = ioctl(fd, VIDIOC_STREAMON, &bufType);
        if (ret == -1)
        {
            std::cout << "ioctl VIDIOC_STREAMON failed" << std::endl;
            return -1;
        }
        std::cout << "startPreview" << std::endl;
        return ret;
    }

    bool v4l2::GetFrame(int &bytesused,cv::Mat &img)
    {
        CLEAR(mVideoInfo->buf);
        // int bytesused;

        mVideoInfo->buf.type = type;
        mVideoInfo->buf.memory = V4L2_MEMORY_MMAP;
        if (V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE == type)
        {
            struct v4l2_plane planes[FMT_NUM_PLANES];
            mVideoInfo->buf.m.planes = planes;
            mVideoInfo->buf.length = FMT_NUM_PLANES;
        }

        auto ret = ioctl(fd, VIDIOC_DQBUF, &mVideoInfo->buf);
        if (ret == -1)
        {
            std::cout << "ioctl VIDIOC_DQBUF failed." << std::endl;
            return false;
        }

        if (V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE == type)
            bytesused = mVideoInfo->buf.m.planes[0].bytesused;
        else
            bytesused = mVideoInfo->buf.bytesused;

        //  process_buffer(&(mVideoInfo->mem[mVideoInfo->buf.index]), bytesused);
        /*
                if (fp)
                {
                    fwrite(buffers[mVideoInfo->buf.index].start, bytesused, 1, fp);
                    fflush(fp);
                }
                */

        cv::Mat yuvmat(cv::Size(mVideoInfo->width, mVideoInfo->height * 3 / 2), CV_8UC1, buffers[mVideoInfo->buf.index].start);
        cv::Mat rgbmat(cv::Size(mVideoInfo->width, mVideoInfo->height), CV_8UC3);
        cv::cvtColor(yuvmat, rgbmat, cv::COLOR_YUV2BGR_NV12);
        img = rgbmat.clone();
        /*这里需要用到压缩*/

        // std::cout << "GetFrame" << std::endl;
        return true;
    }

    int v4l2::UnGetFrame()
    {
        auto ret = ioctl(fd, VIDIOC_QBUF, &mVideoInfo->buf);
        //std::cout << "UnGetFrame" << std::endl;
        return ret;
    }

    int v4l2::stopPreview()
    {

        v4l2_buf_type bufType = type;
        auto ret = ioctl(fd, VIDIOC_STREAMOFF, &bufType);
        if (ret == -1)
        {
            //std::cout << "VIDIOC_STREAMOFF" << std::endl;
            return ret;
        }
        std::cout << "stopPreview" << std::endl;
        for (int i = 0; i < n_buffers; i++)
        {
            munmap(buffers[i].start, mVideoInfo->buf.length);
        }
    }
}
