//
//  VideoCaptuer.m
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/8.
//

#import "VideoCapturer.h"
#import "VideoCapturerUtil.h"

#if TARGET_OS_IPHONE
#import<UIKit/UIKit.h>
#endif


typedef NS_ENUM(NSInteger, AVCamSetupResult) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

static void*  SystemPressureContext = &SystemPressureContext;

static AVCaptureVideoOrientation videoOrientation() {
#if TARGET_OS_IPHONE
    UIInterfaceOrientation statusBarOrientation = UIApplication.sharedApplication.statusBarOrientation;
    if (statusBarOrientation == UIInterfaceOrientationUnknown) {
        return AVCaptureVideoOrientationPortrait;
    }
    return (AVCaptureVideoOrientation)statusBarOrientation;;
#endif
    return AVCaptureVideoOrientationPortrait;
}


@implementation VideoConifg

- (instancetype)init
{
    self = [super init];
    if (self) {
        _fps = 15;
        _videoSize = CGSizeMake(1280, 720);
        _devicePositon = AVCaptureDevicePositionFront;
        _mirror = YES;
    }
    return self;
}

@end


@interface VideoCapturer()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
//config session queue
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
//config result
@property (nonatomic, assign) AVCamSetupResult setupResult;
//是否正在运行
@property (nonatomic, assign) BOOL sessionRunning;

//input device
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;
//切换摄像头位置
@property (nonatomic, assign) AVCaptureDevicePosition position;

//output
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
//output call back queue
@property (nonatomic, strong) dispatch_queue_t sampleBufferCallbackQueue;
//输出视频方向
@property (nonatomic, assign) AVCaptureVideoOrientation videoOrientation;

@end


@implementation VideoCapturer

- (void)dealloc {
    if (@available(iOS 11.0, *)) {
        [self removeObserver:self forKeyPath:@"videoDeviceInput.device.systemPressureState"];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (instancetype)initWithConfig:(VideoConifg *)config delegate:(nonnull id<VideoCaptuerDelegate>)delegate
{
    self = [super init];
    if (self) {
        
        _videoConfig = config;
        _delegate = delegate;
        
        _session = [[AVCaptureSession alloc] init];
        _sessionQueue = dispatch_queue_create("com.videocapturer.sessionqueue", DISPATCH_QUEUE_SERIAL);
        _sampleBufferCallbackQueue = dispatch_queue_create("com.videocapturer.samplebuffer.callbackqueueu", DISPATCH_QUEUE_SERIAL);
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        _setupResult = AVCamSetupResultSuccess;
#if TARGET_OS_IPHONE
        [center addObserver:self
                   selector:@selector(statusBarOrientationDidChange:)
                       name:UIApplicationDidChangeStatusBarOrientationNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruption:)
                       name:AVCaptureSessionWasInterruptedNotification
                     object:self.session];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruptionEnded:)
                       name:AVCaptureSessionInterruptionEndedNotification
                     object:self.session];
        /*
         监听采集系统压力，针对不同的压力做处理
         */
        if (@available(iOS 11.0, *)) {
            [self addObserver:self forKeyPath:@"videoDeviceInput.device.systemPressureState"
                      options:NSKeyValueObservingOptionNew context:SystemPressureContext];
        }
#endif
        [center addObserver:self
                   selector:@selector(handleCaptureSessionRuntimeError:)
                       name:AVCaptureSessionRuntimeErrorNotification
                     object:self.session];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStartRunning:)
                       name:AVCaptureSessionDidStartRunningNotification
                     object:self.session];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStopRunning:)
                       name:AVCaptureSessionDidStopRunningNotification
                     object:self.session];
        [center addObserver:self
                   selector:@selector(deviceConnectNotification:)
                       name:AVCaptureDeviceWasConnectedNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(deviceDisconnectNotification:)
                       name:AVCaptureDeviceWasDisconnectedNotification
                     object:nil];
        
        
        /*
         Check video authorization status. Video access is required and audio
         access is optional. If audio access is denied, audio is not recorded
         during movie recording.
         */
#if TARGET_OS_OSX
        
        if (@available(macOS 10.14, *)) {
#endif
            switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
            {
                case AVAuthorizationStatusAuthorized:
                {
                    // The user has previously granted access to the camera.
                    break;
                }
                case AVAuthorizationStatusNotDetermined:
                {
                    /*
                     The user has not yet been presented with the option to grant
                     video access. We suspend the session queue to delay session
                     setup until the access request has completed.
                     
                     Note that audio access will be implicitly requested when we
                     create an AVCaptureDeviceInput for audio during session setup.
                     */
                    dispatch_suspend(self.sessionQueue);
                    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                        if (!granted) {
                            self.setupResult = AVCamSetupResultCameraNotAuthorized;
                        }
                        dispatch_resume(self.sessionQueue);
                    }];
                    break;
                }
                default:
                {
                    // The user has previously denied access.
                    self.setupResult = AVCamSetupResultCameraNotAuthorized;
                    break;
                }
            }
#if TARGET_OS_OSX
        }
#endif
        dispatch_async(self.sessionQueue, ^{
            [self configureSession];
        });
    }
    return self;
}

- (void)configureSession {
    
    if (self.setupResult != AVCamSetupResultSuccess) {
        return;
    }
    AVCaptureDevice *captureDevice = [VideoCapturerUtil videoCaptureDeviceWithPosition:self.videoConfig.devicePositon];
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    [self.session beginConfiguration];
    //add input
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
        self.videoDeviceInput = deviceInput;
    } else {
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    //config fps, video size
    [VideoCapturerUtil configCaptureDevice:captureDevice expectedFrameRate:self.videoConfig.fps videoSize:self.videoConfig.videoSize];
    
    //add output
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setSampleBufferDelegate:self queue:self.sampleBufferCallbackQueue];
#if TARGET_OS_OSX
    /*
     参考：https://stackoverflow.com/questions/15608931/mac-osx-avfoundation-video-capture
     例如 target 640*360, 此时只能采集(640*480)，这里设置了之后，会真正输出 640*360
     */
    NSDictionary *settings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                               (NSString *)kCVPixelBufferWidthKey : @(self.videoConfig.videoSize.width),
                               (NSString *)kCVPixelBufferHeightKey : @(self.videoConfig.videoSize.height)
                               
    };
#else
    NSDictionary *settings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
#endif
    dataOutput.videoSettings = settings;
    
    if ([self.session canAddOutput:dataOutput]) {
        [self.session addOutput:dataOutput];
        self.videoOutput = dataOutput;
    } else {
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    //配置采集方向
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.videoOrientation = videoOrientation();
    });
    AVCaptureConnection *connection = [dataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.supportsVideoOrientation) {
        connection.videoOrientation = self.videoOrientation;
    }
    //设置镜像模式， macOS 支持，但是不生效
    if (connection.supportsVideoMirroring) {
        connection.videoMirrored = self.videoConfig.mirror;
    }
    
    self.setupResult = AVCamSetupResultSuccess;
    [self.session commitConfiguration];
    
}


- (void)start {
    dispatch_async(self.sessionQueue, ^{
        if (self.setupResult != AVCamSetupResultSuccess) {
            return;
        }
        if (self.session.isRunning) {
            return;
        }
        [self.session startRunning];
        self.sessionRunning = self.session.isRunning;
    });
}

- (void)stop {
    dispatch_async(self.sessionQueue, ^{
        if (self.setupResult != AVCamSetupResultSuccess) {
            return;
        }
        if (!self.session.isRunning) {
            return;
        }
        [self.session stopRunning];
        self.sessionRunning = self.session.isRunning;
    });
}

- (void)changeCaptureDevice:(AVCaptureDevice *)captureDevice {
    if (!captureDevice) {
        return;
    }
    
    dispatch_async(self.sessionQueue, ^{
        if (self.setupResult != AVCamSetupResultSuccess) {
            return;
        }
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
        [self.session beginConfiguration];
        [self.session removeInput:self.videoDeviceInput];
        if ([self.session canAddInput:input]) {
            [self.session addInput:input];
            self.videoDeviceInput = input;
            [VideoCapturerUtil configCaptureDevice:captureDevice expectedFrameRate:self.videoConfig.fps videoSize:self.videoConfig.videoSize];
            self.videoConfig.devicePositon = captureDevice.position;
        } else {
            [self.session addInput:self.videoDeviceInput];
        }
        
        //更改设备之后，需要重新更新采集方向
        AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.supportsVideoOrientation) {
            connection.videoOrientation = self.videoOrientation;
        }
        //更新镜像模式， macOS 支持，但是不生效
        if (connection.supportsVideoMirroring) {
            connection.videoMirrored = self.videoConfig.mirror;
        }
        [self.session commitConfiguration];
    });
}

#pragma mark -
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([self.delegate respondsToSelector:@selector(videoCapturer:didGotSampleBuffer:)]) {
        [self.delegate videoCapturer:self didGotSampleBuffer:sampleBuffer];
    }
}

#pragma mark -
- (void)observeValueForKeyPath:(NSString*)keyPath
                       ofObject:(id)object
                         change:(NSDictionary*)change
                        context:(void*)context
{
    if (context == SystemPressureContext) {
#if TARGET_OS_IOS
        if (@available(iOS 11.1, *)) {
            AVCaptureSystemPressureState* systemPressureState = change[NSKeyValueChangeNewKey];
            [self setRecommendedFrameRateRangeForPressureState:systemPressureState];
        }
#endif
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)setRecommendedFrameRateRangeForPressureState:(AVCaptureSystemPressureState*)systemPressureState API_AVAILABLE(ios(11.1)) API_UNAVAILABLE(watchos, tvos, macos) {
    /*
     The frame rates used here are for demonstrative purposes only for this app.
     Your frame rate throttling may be different depending on your app's camera configuration.
     */
    AVCaptureSystemPressureLevel pressureLevel = [systemPressureState level];
    if (pressureLevel == AVCaptureSystemPressureLevelSerious || pressureLevel == AVCaptureSystemPressureLevelCritical) {
        NSLog(@"WARNING: Reached elevated system pressure level: %@. Throttling frame rate.", pressureLevel);
        if (self.sessionRunning && [self.videoDeviceInput.device lockForConfiguration:nil]) {
            self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTimeMake(1, 20);
            self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTimeMake(1, 15);
            [self.videoDeviceInput.device unlockForConfiguration];
        }
    }
    else if (pressureLevel == AVCaptureSystemPressureLevelShutdown) {
        NSLog(@"Session stopped running due to shutdown system pressure level.");
    }
}


#pragma mark -
#if TARGET_OS_IPHONE
- (void)statusBarOrientationDidChange:(NSNotification *)notification {
    if ([NSThread isMainThread]) {
        self.videoOrientation = videoOrientation();
        [self.videoOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation = self.videoOrientation;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.videoOrientation = videoOrientation();
            [self.videoOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation = self.videoOrientation;
        });
    }
}
- (void)handleCaptureSessionInterruption:(NSNotification *)notification {
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    
    if (reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
        reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient) {
        //被其他APP占用而打断
        
    } else  if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps) {
        //IPAD 分屏，两个app 同时使用 摄像头的情况
        
    } else {
        if (@available(iOS 11.1, *)) {
            if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableDueToSystemPressure) {
                NSLog(@"Session stopped running due to shutdown system pressure level.");
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
- (void)handleCaptureSessionInterruptionEnded:(NSNotification *)notification {
    
}
#endif

- (void)handleCaptureSessionRuntimeError:(NSNotification *)notification {
    
    NSError* error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog(@"Capture session runtime error: %@", error);
    // If media services were reset, and the last start succeeded, restart the session.
#if TARGET_OS_IPHONE
    if (error.code == AVErrorMediaServicesWereReset) {
        dispatch_async(self.sessionQueue, ^{
            if (self.sessionRunning) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
        });
    }
#endif
}

- (void)handleCaptureSessionDidStartRunning:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(videoCapturerDidStart:)]) {
        [self.delegate videoCapturerDidStart:self];
    }
}

- (void)handleCaptureSessionDidStopRunning:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(videoCapturerDidStop:)]) {
        [self.delegate videoCapturerDidStop:self];
    }
}

- (void)deviceConnectNotification:(NSNotification *)notification
{
    AVCaptureDevice *device = notification.object;
    NSLog(@"device conenct, id: %@, name: %@", device.uniqueID, device.localizedName);
}

- (void)deviceDisconnectNotification:(NSNotification *)notification
{
    AVCaptureDevice *device = notification.object;
    
    if ([device.uniqueID isEqualToString:self.videoDeviceInput.device.uniqueID]) {
        
        //找到下一个采集设备
        AVCaptureDevice *next = [VideoCapturerUtil videoCaptureDeviceWithPosition:AVCaptureDevicePositionFront];
        if (next) {
            [self changeCaptureDevice:next];
        }
    }
    
    

}


@end
