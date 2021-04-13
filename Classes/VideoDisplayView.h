//
//  VideoDisplayView.h
//
//
//  Created by yxibng on 2019/10/16.
//
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
typedef UIView VIEW_CLASS;
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef NSView VIEW_CLASS;
#endif

#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoDisplayView : VIEW_CLASS

@property (nonatomic, weak) VIEW_CLASS *canvas;
@property (nonatomic, copy) AVLayerVideoGravity gravity;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
