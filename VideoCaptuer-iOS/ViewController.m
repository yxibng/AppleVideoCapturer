//
//  ViewController.m
//  VideoCaptuer-iOS
//
//  Created by yxibng on 2021/4/8.
//

#import "ViewController.h"
#import "VideoCapturer.h"
#import "VideoDisplayView.h"
#import "VideoCapturerUtil.h"
#import "MetalVideoRenderer.h"

#define  USE_METAL 1

@interface ViewController ()<VideoCaptuerDelegate>
@property (weak, nonatomic) IBOutlet VideoDisplayView *displayView;
@property (nonatomic, strong) VideoCapturer *videoCapturer;

@property (nonatomic, strong) MetalVideoRenderer *metalVideoRenderer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    VideoConifg *config = [[VideoConifg alloc] init];
    config.fps = 15;
    config.videoSize = CGSizeMake(1280, 720);
    config.mirror = NO;
    config.devicePositon = AVCaptureDevicePositionBack;
    _videoCapturer = [[VideoCapturer alloc] initWithConfig:config delegate:self];
    
    
    _metalVideoRenderer = [[MetalVideoRenderer alloc] init];
    _metalVideoRenderer.canvas = self.view;
    
    self.displayView.hidden = YES;
    
    
}

- (IBAction)startCapturing:(id)sender {
    [_videoCapturer start];
    
}
- (IBAction)stopCapturing:(id)sender {
    [_videoCapturer stop];
}
- (IBAction)switchBackAndFront:(id)sender {
    
    AVCaptureDevicePosition position = self.videoCapturer.videoConfig.devicePositon;
    AVCaptureDevice *device = nil;
    if (position == AVCaptureDevicePositionBack) {
        device = [VideoCapturerUtil videoCaptureDeviceWithPosition:AVCaptureDevicePositionFront];
    } else {
        device = [VideoCapturerUtil videoCaptureDeviceWithPosition:AVCaptureDevicePositionBack];
    }
    [self.videoCapturer changeCaptureDevice:device];
}

#pragma mark -
- (void)videoCapturerDidStart:(VideoCapturer *)capturer {
    
    NSLog(@"%s",__func__);
}
- (void)videoCapturerDidStop:(VideoCapturer *)capturer {
    NSLog(@"%s",__func__);
}
- (void)videoCapturer:(VideoCapturer *)capturer didGotSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
#if USE_METAL
    [self.metalVideoRenderer displayPixelBuffer:pixelBuffer];
#else
    self.displayView.hidden = NO;
    [self.displayView displayPixelBuffer:pixelBuffer];
#endif
}

@end
