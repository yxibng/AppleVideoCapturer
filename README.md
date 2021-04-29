# AppleVideoCapturer
demo shows how to capture video data from camera in macos and ios platform.

1. 配置AVCaptureSession， 添加AVCaptureVideoDataOutput 采集视频数据
2.  配置iOS 采集视频的方向（与statusbar的方向一致），镜像模式，响应屏幕旋转
3.  ios切换前后置摄像头，macOS切换采集设备
4. 配置采集的帧率，分辨率， iOS支持高帧率采集
5. 通过AVSampleBufferDisplayLayer来预览采集的数据
6. iOS处理响应采集打断与恢复，运行错误等
7. macOS 处理采集设备插拔事件
8. 支持 metal 渲染， 使用了 https://github.com/libobjc/SGPlayer
