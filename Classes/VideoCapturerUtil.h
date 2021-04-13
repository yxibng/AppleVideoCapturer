//
//  VideoCapturerUtil.h
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/8.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoCapturerUtil : NSObject
//video capture device with specified positon
+ (AVCaptureDevice *)videoCaptureDeviceWithPosition:(AVCaptureDevicePosition)position;
//all video capture devices
+ (NSArray<AVCaptureDevice *> *)videoCaptureDevices;
//search for AVCaptureDevice with uniqueID
+ (AVCaptureDevice *)videoCaptureDeviceWithID:(NSString *)uniqueID;

+ (void)configCaptureDevice:(AVCaptureDevice *)captureDevice expectedFrameRate:(NSInteger)expetedFrameRate videoSize:(CGSize)videoSize;

@end

NS_ASSUME_NONNULL_END
