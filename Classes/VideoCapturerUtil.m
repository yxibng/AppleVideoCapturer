//
//  VideoCapturerUtil.m
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/8.
//

#import "VideoCapturerUtil.h"

//最高60FPS
const Float64 kFramerateLimit = 60.0;

@implementation VideoCapturerUtil

//video capture device with specified positon
+ (AVCaptureDevice *)videoCaptureDeviceWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *videoDevice;
#if TARGET_OS_IOS
    
    if (@available(iOS 10.0, *)) {
        NSArray<AVCaptureDeviceType> *deviceType_13_0;
        if (@available(iOS 13.0, *)) {
            deviceType_13_0 = @[AVCaptureDeviceTypeBuiltInUltraWideCamera,
                                AVCaptureDeviceTypeBuiltInDualWideCamera,
                                AVCaptureDeviceTypeBuiltInTripleCamera];
        } else {
            deviceType_13_0 = @[];
        }
        
        NSArray<AVCaptureDeviceType> *deviceType_11_1;
        if (@available(iOS 11.1, *)) {
            deviceType_11_1 = @[AVCaptureDeviceTypeBuiltInTrueDepthCamera];
        } else {
            deviceType_11_1 = @[];
        }
        
        NSArray<AVCaptureDeviceType> *deviceType_10_2;
        if (@available(iOS 10.2, *)) {
            deviceType_10_2 = @[AVCaptureDeviceTypeBuiltInDualCamera];
        } else {
            deviceType_10_2 = @[];
        }
        
        NSArray<AVCaptureDeviceType> *deviceType_10_0;
        if (@available(iOS 10.0, *)) {
            deviceType_10_0 = @[AVCaptureDeviceTypeBuiltInWideAngleCamera,
                                AVCaptureDeviceTypeBuiltInTelephotoCamera];
        } else {
            deviceType_10_0 = @[];
        }
        
        NSArray *osTypes = @[deviceType_13_0, deviceType_11_1, deviceType_10_2, deviceType_10_0];
        NSMutableArray<AVCaptureDeviceType> *deviceTypes = [NSMutableArray array];
        for (NSArray *types in osTypes) {
            [deviceTypes addObjectsFromArray:types];
        }
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                                                                          mediaType:AVMediaTypeVideo
                                                                                                           position:position];
        for (AVCaptureDevice *device in session.devices) {
            if (device.position == position) {
                videoDevice = device;
                break;
            }
        }
    } else {
        NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in cameras) {
            if (device.position == position) {
                videoDevice = device;
                break;
            }
        }
    }
#elif TARGET_OS_OSX
    videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
#endif
    return videoDevice;
}


//all video capture devices
+ (NSArray<AVCaptureDevice *> *)videoCaptureDevices
{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
}
//search for AVCaptureDevice with uniqueID
+ (AVCaptureDevice *)videoCaptureDeviceWithID:(NSString *)uniqueID
{
    if (!uniqueID) {
        return nil;
    }
    return [AVCaptureDevice deviceWithUniqueID:uniqueID];
}


+ (void)configCaptureDevice:(AVCaptureDevice *)captureDevice expectedFrameRate:(NSInteger)expetedFrameRate videoSize:(CGSize)videoSize {
    
    //采集nv12
    FourCharCode pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    AVCaptureDeviceFormat *format = [self selectFormatForDevice:captureDevice targetWidth:videoSize.width targetHeight:videoSize.height preferredOutputPixelFormat:pixelFormat];
    
    AVFrameRateRange *range = [self selectedRangeForFormat:format expectedFps:expetedFrameRate];
    CMTime minDuration = range.minFrameDuration;
    CMTime maxDuration = range.maxFrameDuration;
    if (range.maxFrameRate >= expetedFrameRate && range.minFrameRate <= expetedFrameRate) {
        minDuration = CMTimeMake(1, (int32_t)expetedFrameRate);
        maxDuration = CMTimeMake(1, (int32_t)expetedFrameRate);
    }
    CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    NSLog(@"format size = (%d,%d) , range = %@, real max rate = %f, min rate = %f", dimension.width, dimension.height, range, 1.0/CMTimeGetSeconds(minDuration), 1.0/CMTimeGetSeconds(maxDuration));
    
    if ([captureDevice lockForConfiguration:nil]) {
        //设置activeFormat，此时 iOS session 的preset 会自动改为 AVCaptureSessionPresetInputPriority
        captureDevice.activeFormat = format;
        captureDevice.activeVideoMaxFrameDuration = minDuration;
        captureDevice.activeVideoMinFrameDuration = maxDuration;
        [captureDevice unlockForConfiguration];
    }
}

/*
 找到 分辨率、 采样格式 最接近的 format
 */
+ (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device
                                     targetWidth:(int)targetWidth
                                    targetHeight:(int)targetHeight
                      preferredOutputPixelFormat:(FourCharCode)preferredOutputPixelFormat
{
    NSArray<AVCaptureDeviceFormat *> *formats = [device formats];
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;
    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == preferredOutputPixelFormat) {
            selectedFormat = format;
        }
    }
    return selectedFormat;
}

+ (AVFrameRateRange *)selectedRangeForFormat:(AVCaptureDeviceFormat *)format expectedFps:(NSInteger)expectedFps {

    //根据最大帧率升序排列
    NSArray *ranges = [format.videoSupportedFrameRateRanges sortedArrayUsingComparator:^NSComparisonResult(AVFrameRateRange *  _Nonnull obj1, AVFrameRateRange *  _Nonnull obj2) {
        if (obj1.maxFrameRate > obj2.maxFrameRate) {
            return NSOrderedDescending;
        } else if (obj1.maxFrameRate < obj1.maxFrameRate) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
        
    }];
    //比最大帧率还大
    AVFrameRateRange *highRange = ranges.lastObject;
    if (expectedFps >= highRange.maxFrameRate) {
        return highRange;
    }
    
    //比最小帧率还小
    AVFrameRateRange *lowRange = ranges.firstObject;
    if (expectedFps <= lowRange.minFrameRate) {
        return lowRange;
    }
    //寻找接近的
    AVFrameRateRange *range = nil;
    for (AVFrameRateRange *fpsRange in ranges) {
        if (fpsRange.maxFrameRate >= expectedFps) {
            range = fpsRange;
            break;
        }
    }
    if (!range) {
        range = ranges.lastObject;
    }
    return range;
}

@end
