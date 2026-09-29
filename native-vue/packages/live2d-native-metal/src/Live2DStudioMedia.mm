#import "Live2DStudioMedia.h"
#import <CoreImage/CoreImage.h>

static void* StudioPiPObservation = &StudioPiPObservation;
static void* StudioPiPSuspensionObservation = &StudioPiPSuspensionObservation;

@implementation Live2DStudioMedia
{
    AVPictureInPictureController* _pip;
    AVPictureInPictureVideoCallViewController* _pipContent;
    MTKView* _pipView;
    UIView* _sourceView; // Host owns this view and invalidates us before release.
    id<MTLDevice> _device;
    BOOL (^_renderHandler)(MTKView*);
    void (^_activeHandler)(BOOL);
    UIViewController* _exportPresenter;
    BOOL _exportRequested;
    BOOL _capturePending;
    BOOL _invalidated;
    BOOL _pipRequested;
    BOOL _pipStarting;
    CIContext* _imageContext;
    NSTimer* _pipTimer;
    CFTimeInterval _backgroundStart;
    CFTimeInterval _lastBackgroundDuration;
    NSUInteger _backgroundFrames;
    NSUInteger _lastBackgroundFrames;
    NSUInteger _backgroundDrawCalls;
    NSUInteger _lastBackgroundDrawCalls;
}
- (instancetype)init
{
    if ((self = [super init])) {
        _imageContext = [[CIContext contextWithOptions:nil] retain];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didEnterBackground:)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didBecomeActive:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}
- (void)configureSourceView:(UIView*)source device:(id<MTLDevice>)device
             renderHandler:(BOOL (^)(MTKView*))renderHandler activeHandler:(void (^)(BOOL))activeHandler
{
    _sourceView = source;
    [_device release]; _device = [device retain];
    [_renderHandler release]; _renderHandler = [renderHandler copy];
    [_activeHandler release]; _activeHandler = [activeHandler copy];
}
- (void)requestExportFrom:(UIViewController*)presenter
{
    if (!presenter) return;
    [_exportPresenter release]; _exportPresenter = [presenter retain]; _exportRequested = YES;
}
- (void)togglePictureInPicture
{
    if (_invalidated) return;
    if (_pip.pictureInPictureActive || _pipRequested || _pipStarting) {
        _pipRequested = NO; [_pip stopPictureInPicture]; return;
    }
    if (![AVPictureInPictureController isPictureInPictureSupported] || !_sourceView.window) {
        if (self.statusHandler) self.statusHandler(@"当前无法开启画中画"); return;
    }
    // iOS 18+ supports MTKView inside the PiP content controller. Only that
    // system-hosted visible view renders while the main app is backgrounded.
    NSError* error = nil;
    AVAudioSession* session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback
                options:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    if (!error) [session setActive:YES error:&error];
    if (error) { if (self.statusHandler) self.statusHandler(error.localizedDescription); return; }
    if (!_pip) {
        _pipContent = [[AVPictureInPictureVideoCallViewController alloc] init];
        _pipView = [[MTKView alloc] initWithFrame:CGRectZero device:_device];
        _pipView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        _pipView.framebufferOnly = NO;
        _pipView.preferredFramesPerSecond = 30;
        // Own the PiP clock instead of relying on the foreground view's display
        // link. MTKView remains in manual drawing mode for its whole lifetime.
        _pipView.paused = YES;
        _pipView.enableSetNeedsDisplay = NO;
        _pipView.delegate = self;
        _pipView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _pipView.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.14 alpha:1];
        [_pipContent.view addSubview:_pipView];
        AVPictureInPictureControllerContentSource* source = [[AVPictureInPictureControllerContentSource alloc]
            initWithActiveVideoCallSourceView:_sourceView contentViewController:_pipContent];
        _pip = [[AVPictureInPictureController alloc] initWithContentSource:source];
        [source release]; _pip.delegate = self;
        _pip.canStartPictureInPictureAutomaticallyFromInline = NO;
        [_pip addObserver:self forKeyPath:@"pictureInPicturePossible" options:NSKeyValueObservingOptionNew context:StudioPiPObservation];
        [_pip addObserver:self forKeyPath:@"pictureInPictureSuspended" options:NSKeyValueObservingOptionNew context:StudioPiPSuspensionObservation];
    }
    _pipContent.preferredContentSize = _sourceView.bounds.size;
    _pipView.frame = _pipContent.view.bounds;
    _pipRequested = YES;
    if (self.statusHandler) self.statusHandler(@"正在开启实时画中画");
    [self startWhenPossible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self->_invalidated && self->_pipRequested) {
            self->_pipRequested = NO;
            if (self.statusHandler) self.statusHandler(@"系统尚未允许画中画，请保持应用前台再试");
        }
    });
}
- (void)startWhenPossible
{
    if (_invalidated || !_pipRequested || !_pip.pictureInPicturePossible) return;
    _pipRequested = NO; _pipStarting = YES; [_pip startPictureInPicture];
}
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
    if (context == StudioPiPObservation) dispatch_async(dispatch_get_main_queue(), ^{ [self startWhenPossible]; });
    else if (context == StudioPiPSuspensionObservation) dispatch_async(dispatch_get_main_queue(), ^{ [self updatePiPClock]; });
    else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)drawInMTKView:(MTKView*)view
{
    if (_invalidated || !_pip.pictureInPictureActive || _pip.pictureInPictureSuspended || !_renderHandler) return;
    if (_backgroundStart > 0) _backgroundDrawCalls++;
    if (_renderHandler(view) && _backgroundStart > 0) _backgroundFrames++;
}
- (void)updatePiPClock
{
    BOOL running = !_invalidated && _pip.pictureInPictureActive && !_pip.pictureInPictureSuspended;
    if (!running) {
        [_pipTimer invalidate]; [_pipTimer release]; _pipTimer = nil;
        return;
    }
    if (!_pipTimer) {
        _pipTimer = [[NSTimer timerWithTimeInterval:1.0/30.0 target:self selector:@selector(drawPiPFrame:)
            userInfo:nil repeats:YES] retain];
        _pipTimer.tolerance = 0.002;
        [NSRunLoop.mainRunLoop addTimer:_pipTimer forMode:NSRunLoopCommonModes];
    }
    [_pipView draw];
}
- (void)drawPiPFrame:(NSTimer*)timer
{
    if (!_invalidated && _pip.pictureInPictureActive && !_pip.pictureInPictureSuspended) [_pipView draw];
}
- (void)didEnterBackground:(NSNotification*)notification
{
    if (_pip.pictureInPictureActive) {
        _backgroundStart = CACurrentMediaTime(); _backgroundFrames = 0; _backgroundDrawCalls = 0;
        [self updatePiPClock];
    }
}
- (void)finishBackgroundMeasurement
{
    if (_backgroundStart <= 0) return;
    _lastBackgroundDuration = CACurrentMediaTime() - _backgroundStart;
    _lastBackgroundFrames = _backgroundFrames; _lastBackgroundDrawCalls = _backgroundDrawCalls;
    _backgroundStart = 0;
}
- (void)didBecomeActive:(NSNotification*)notification
{
    [self finishBackgroundMeasurement];
    if (!_invalidated && _pip.pictureInPictureActive) {
        // Recover a transient drawable/GPU failure on the foreground transition.
        if (_activeHandler) _activeHandler(YES);
        [self updatePiPClock];
    }
}
- (NSDictionary*)pictureInPictureDiagnostics
{
    return @{@"active": @(_pip.pictureInPictureActive), @"suspended": @(_pip.pictureInPictureSuspended),
        @"backgroundFrames": @(_lastBackgroundFrames), @"backgroundDrawCalls": @(_lastBackgroundDrawCalls),
        @"backgroundSeconds": @(_lastBackgroundDuration)};
}
- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size {}
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController*)controller
{
    _pipStarting = NO;
    if (_activeHandler) _activeHandler(YES);
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) [self didEnterBackground:nil];
    [self updatePiPClock];
    if (self.statusHandler) self.statusHandler(@"实时画中画已开启");
}
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController*)controller
{
    _pipStarting = NO; _pipView.paused = YES;
    [self finishBackgroundMeasurement];
    [_pipTimer invalidate]; [_pipTimer release]; _pipTimer = nil;
    if (_activeHandler) _activeHandler(NO);
    if (self.statusHandler) self.statusHandler(@"画中画已关闭");
}
- (void)pictureInPictureController:(AVPictureInPictureController*)controller failedToStartPictureInPictureWithError:(NSError*)error
{
    _pipRequested = NO; _pipStarting = NO; _pipView.paused = YES;
    [_pipTimer invalidate]; [_pipTimer release]; _pipTimer = nil;
    if (_activeHandler) _activeHandler(NO);
    if (self.statusHandler) self.statusHandler(error.localizedDescription);
}
- (void)pictureInPictureController:(AVPictureInPictureController*)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{ completionHandler(YES); }

// Read back only for a requested PNG. Live PiP has no capture/copy pipeline.
- (void)captureTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if (_invalidated || _capturePending || !_exportRequested) return;
    NSUInteger width = texture.width, height = texture.height, rowBytes = (width * 4 + 255) & ~255;
    id<MTLBuffer> pixels = [texture.device newBufferWithLength:rowBytes * height options:MTLResourceStorageModeShared];
    if (!pixels) return;
    id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
    [blit copyFromTexture:texture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0)
              sourceSize:MTLSizeMake(width, height, 1) toBuffer:pixels destinationOffset:0
     destinationBytesPerRow:rowBytes destinationBytesPerImage:rowBytes * height];
    [blit endEncoding]; _capturePending = YES;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_capturePending = NO;
            if (self->_invalidated) return;
            self->_exportRequested = NO;
            if (completed.status != MTLCommandBufferStatusError) {
                NSData* data = [NSData dataWithBytes:pixels.contents length:rowBytes * height];
                CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
                CIImage* image = [CIImage imageWithBitmapData:data bytesPerRow:rowBytes size:CGSizeMake(width, height) format:kCIFormatBGRA8 colorSpace:color];
                CGColorSpaceRelease(color);
                CGImageRef cg = [self->_imageContext createCGImage:image fromRect:image.extent];
                if (cg) {
                    NSData* png = UIImagePNGRepresentation([UIImage imageWithCGImage:cg]); CGImageRelease(cg);
                    NSURL* file = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Live2D-%@.png", NSUUID.UUID.UUIDString]]];
                    if ([png writeToURL:file atomically:YES]) {
                        UIActivityViewController* share = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
                        share.popoverPresentationController.sourceView = self->_exportPresenter.view;
                        share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self->_exportPresenter.view.bounds), CGRectGetMidY(self->_exportPresenter.view.bounds), 1, 1);
                        [self->_exportPresenter presentViewController:share animated:YES completion:nil]; [share release];
                        if (self.statusHandler) self.statusHandler(@"PNG 已生成，可保存或分享");
                    }
                }
            } else if (self.statusHandler) self.statusHandler(@"PNG 渲染失败，请重试");
            [self->_exportPresenter release]; self->_exportPresenter = nil;
        });
    }];
    [pixels release];
}
- (void)invalidate
{
    if (_invalidated) return;
    _invalidated = YES; _pipRequested = NO; _pipView.paused = YES; _pipView.delegate = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_pipTimer invalidate]; [_pipTimer release]; _pipTimer = nil;
    if (_activeHandler) _activeHandler(NO);
    if (_pip) {
        [_pip removeObserver:self forKeyPath:@"pictureInPicturePossible" context:StudioPiPObservation];
        [_pip removeObserver:self forKeyPath:@"pictureInPictureSuspended" context:StudioPiPSuspensionObservation];
    }
    _pip.delegate = nil; [_pip stopPictureInPicture]; _pip.contentSource = nil;
    self.statusHandler = nil;
    [_renderHandler release]; _renderHandler = nil;
    [_activeHandler release]; _activeHandler = nil;
}
- (void)dealloc
{
    [self invalidate]; [_pip release]; [_pipView release]; [_pipContent release]; [_device release];
    [_exportPresenter release]; [_imageContext release]; [_statusHandler release]; [super dealloc];
}
@end
