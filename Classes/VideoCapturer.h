//
//  VideoCaptuer.h
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/8.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface VideoConifg : NSObject
//默认15
@property (nonatomic, assign) NSInteger fps;
//默认1280*720
@property (nonatomic, assign) CGSize videoSize;
//默认，前置摄像头
@property (nonatomic, assign) AVCaptureDevicePosition devicePositon;
//是否镜像， 默认是镜像, macOS可以设置，但是不生效
@property (nonatomic, assign) BOOL mirror;
@end


@class VideoCapturer;

@protocol VideoCaptuerDelegate<NSObject>
@optional
- (void)videoCapturerDidStart:(VideoCapturer *)capturer;
- (void)videoCapturerDidStop:(VideoCapturer *)capturer;
- (void)videoCapturer:(VideoCapturer *)capturer didGotSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end



@interface VideoCapturer : NSObject

- (instancetype)initWithConfig:(VideoConifg *)config delegate:(id<VideoCaptuerDelegate>)delegate;

@property (nonatomic, strong) VideoConifg *videoConfig;
@property (nonatomic, weak) id<VideoCaptuerDelegate>delegate;

- (void)changeCaptureDevice:(AVCaptureDevice *)captureDevice;
- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
