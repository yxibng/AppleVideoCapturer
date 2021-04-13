//
//  ViewController.m
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/8.
//

#import "ViewController.h"
#import "VideoCapturerUtil.h"
#import "VideoCapturer.h"
#import "VideoDisplayView.h"

@interface ViewController()<VideoCaptuerDelegate>
@property (weak) IBOutlet NSPopUpButton *camerasPopUpButton;
@property (nonatomic, strong) NSArray<AVCaptureDevice *> *cameras;
@property (nonatomic, strong) VideoCapturer *videoCapturer;
@property (weak) IBOutlet VideoDisplayView *displayView;
@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cameras = [VideoCapturerUtil videoCaptureDevices];
    
    [self.camerasPopUpButton removeAllItems];
    
    for (AVCaptureDevice *device in self.cameras) {
        NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle:device.localizedName action:@selector(changeCaptureDevice:) keyEquivalent:@""];
        [newItem setTarget:self];
        [[self.camerasPopUpButton menu] addItem:newItem];
    }
    
    AVCaptureDevice *device = self.cameras.firstObject;
    if(!device) {
        return;
    }
    
    VideoConifg *config = [[VideoConifg alloc] init];
    config.videoSize = CGSizeMake(1280, 720);
    config.devicePositon = AVCaptureDevicePositionUnspecified;
    config.fps = 15;
    config.mirror = NO;

    _videoCapturer = [[VideoCapturer alloc] initWithConfig:config delegate:self];
    [_videoCapturer changeCaptureDevice:device];
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)startCapturing:(id)sender {
    [self.videoCapturer start];
}

- (IBAction)stopCapturing:(id)sender {
    [self.videoCapturer stop];
}

- (void)changeCaptureDevice:(id)sender {
    
    NSInteger index = [self.camerasPopUpButton indexOfSelectedItem];
    
    if (index < 0 || index >= self.cameras.count) {
        return;
    }

    AVCaptureDevice *device = [self.cameras objectAtIndex:index];
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
    [self.displayView displayPixelBuffer:pixelBuffer];
}




@end
