//
//  MetalVideoRenderer.m
//  VideoCaptuer
//
//  Created by yxibng on 2021/4/29.
//

#import "MetalVideoRenderer.h"
#import "SGMetal/SGMetal.h"

@interface MetalVideoRenderer()<MTKViewDelegate>
@property (nonatomic, strong, readonly) MTKView *metalView;
@property (nonatomic, strong, readonly) NSLock *lock;
@property (nonatomic, strong, readonly) SGMetalRenderer *renderer;
@property (nonatomic, strong, readonly) SGMetalModel *planeModel;
@property (nonatomic, strong, readonly) SGMetalProjection *projection;
@property (nonatomic, strong, readonly) SGMetalRenderPipeline *pipeline;
@property (nonatomic, strong, readonly) SGMetalTextureLoader *textureLoader;
@property (nonatomic, strong, readonly) SGMetalRenderPipelinePool *pipelinePool;

@property (nonatomic) CVPixelBufferRef pixelBuffer;

@property (nonatomic, strong) NSMutableArray *pixelBuffers;

@end
@implementation MetalVideoRenderer

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupDrawingLoop];
    }
    return self;
}

- (void)setupDrawingLoop {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    _renderer = [[SGMetalRenderer alloc] initWithDevice:device];
    _planeModel = [[SGMetalPlaneModel alloc] initWithDevice:device];
    _projection = [[SGMetalProjection alloc] initWithDevice:device];
    _textureLoader = [[SGMetalTextureLoader alloc] initWithDevice:device];
    _pipelinePool = [[SGMetalRenderPipelinePool alloc] initWithDevice:device];
    
    _metalView = [[MTKView alloc] initWithFrame:CGRectZero device:device];
    _metalView.preferredFramesPerSecond = 30;
    _metalView.translatesAutoresizingMaskIntoConstraints = NO;
    _metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalView.delegate = self;
    
    _lock = [[NSLock alloc] init];
    
    _gravity = AVLayerVideoGravityResizeAspect;

    _pixelBuffers = [NSMutableArray new];
}

- (void)setCanvas:(VIEW_CLASS *)canvas {
    _canvas = canvas;
    if (!canvas) {
        [self.metalView removeFromSuperview];
        return;
    }
    
    [canvas addSubview:self.metalView];
    
#if TARGET_OS_IOS
    [canvas sendSubviewToBack:self.metalView];
#endif
    
    NSLayoutConstraint *c1 = [NSLayoutConstraint constraintWithItem:self->_metalView
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self->_canvas
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0
                                                           constant:0.0];
    NSLayoutConstraint *c2 = [NSLayoutConstraint constraintWithItem:self->_metalView
                                                          attribute:NSLayoutAttributeLeft
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self->_canvas
                                                          attribute:NSLayoutAttributeLeft
                                                         multiplier:1.0
                                                           constant:0.0];
    NSLayoutConstraint *c3 = [NSLayoutConstraint constraintWithItem:self->_metalView
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self->_canvas
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0
                                                           constant:0.0];
    NSLayoutConstraint *c4 = [NSLayoutConstraint constraintWithItem:self->_metalView
                                                          attribute:NSLayoutAttributeRight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self->_canvas
                                                          attribute:NSLayoutAttributeRight
                                                         multiplier:1.0
                                                           constant:0.0];
    [self->_canvas addConstraints:@[c1, c2, c3, c4]];
}





- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer {
 
    if (!pixelBuffer) {
        return;
    }
    [self.lock lock];
    [self.pixelBuffers addObject:(__bridge id)pixelBuffer];
    [self.lock unlock];
    [self.metalView draw];

}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    

}

SGMetalViewportMode SGScaling2Viewport(AVLayerVideoGravity gravity) {
    if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        return SGMetalViewportModeResize;
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        return SGMetalViewportModeResizeAspect;
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        return SGMetalViewportModeResizeAspectFill;
    }
    return SGMetalViewportModeResize;
}


- (void)drawInMTKView:(nonnull MTKView *)view {
    [self.lock lock];
    CVPixelBufferRef buffer = (__bridge CVPixelBufferRef)(self.pixelBuffers.firstObject);
    if (!buffer) {
        [self.lock unlock];
        return;
    }
    
    int width = (int)CVPixelBufferGetWidth(buffer);
    int height = (int)CVPixelBufferGetHeight(buffer);
    OSType cv_format = CVPixelBufferGetPixelFormatType(buffer);
    GLKMatrix4 baseMatrix = GLKMatrix4Identity;    
    NSArray<id<MTLTexture>> *textures = [self->_textureLoader texturesWithCVPixelBuffer:buffer];
    
    if (!textures.count) {
        [self.pixelBuffers removeObjectAtIndex:0];
        [self.lock unlock];
        return;
    }
    
    MTLViewport viewports[2] = {};
    NSArray<SGMetalProjection *> *projections = nil;
    CGSize drawableSize = [self->_metalView drawableSize];
    id <CAMetalDrawable> drawable = [self->_metalView currentDrawable];
    if (drawableSize.width == 0 || drawableSize.height == 0) {
        [self.pixelBuffers removeObjectAtIndex:0];
        [self.lock unlock];
        return;
    }
    
    
    
    
    MTLSize textureSize = MTLSizeMake(width, height, 0);
    MTLSize layerSize = MTLSizeMake(drawable.texture.width, drawable.texture.height, 0);
    
    self->_projection.matrix = baseMatrix;
    projections = @[self->_projection];
    viewports[0] = [SGMetalViewport viewportWithLayerSize:layerSize textureSize:textureSize mode:SGScaling2Viewport(self->_gravity)];
    
    SGMetalRenderPipeline *pipeline = [self->_pipelinePool pipelineWithCVPixelFormat:cv_format];
    if (projections.count) {
        id<MTLCommandBuffer> commandBuffer = [self.renderer drawModel:self.planeModel
                                                            viewports:viewports
                                                             pipeline:pipeline
                                                          projections:projections
                                                        inputTextures:textures
                                                        outputTexture:drawable.texture];
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];
    }
    [self.pixelBuffers removeObjectAtIndex:0];
    [self.lock unlock];
}

@end
