//
//  MetalVideoRenderer.h
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/29.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
typedef UIView VIEW_CLASS;
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef NSView VIEW_CLASS;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface MetalVideoRenderer : NSObject

@property (nonatomic, weak) VIEW_CLASS *canvas;
@property (nonatomic, copy) AVLayerVideoGravity gravity;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
