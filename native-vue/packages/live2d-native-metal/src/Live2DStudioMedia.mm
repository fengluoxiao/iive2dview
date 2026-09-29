#import "Live2DStudioMedia.h"
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

@implementation Live2DStudioMedia
{
    AVSampleBufferDisplayLayer* _displayLayer;
    AVPictureInPictureController* _pip;
    UIViewController* _exportPresenter;
    BOOL _exportRequested;
    BOOL _pipRequested;
    BOOL _capturePending;
    BOOL _invalidated;
    CFTimeInterval _lastCapture;
    CFTimeInterval _pipRequestTime;
    CIContext* _imageContext;
}
@synthesize displayLayer = _displayLayer;

- (instancetype)init
{
    if ((self = [super init])) {
        _displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        _imageContext = [[CIContext contextWithOptions:nil] retain];
    }
    return self;
}
- (void)requestExportFrom:(UIViewController*)presenter
{
    if (!presenter) return;
    [_exportPresenter release]; _exportPresenter = [presenter retain];
    _exportRequested = YES;
}
- (void)togglePictureInPicture
{
    if (_pip.pictureInPictureActive || _pipRequested) {
        _pipRequested = NO; [_pip stopPictureInPicture]; return;
    }
    if (![AVPictureInPictureController isPictureInPictureSupported]) {
        if (self.statusHandler) self.statusHandler(@"当前设备不支持画中画"); return;
    }
    NSError* error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    if (!error) [session setActive:YES error:&error];
    if (error) { if (self.statusHandler) self.statusHandler(error.localizedDescription); return; }
    if (!_pip) {
        AVPictureInPictureControllerContentSource* source = [[AVPictureInPictureControllerContentSource alloc]
            initWithSampleBufferDisplayLayer:_displayLayer playbackDelegate:self];
        _pip = [[AVPictureInPictureController alloc] initWithContentSource:source];
        [source release]; _pip.delegate = self;
        _pip.requiresLinearPlayback = YES;
    }
    _pipRequested = YES; _pipRequestTime = CACurrentMediaTime();
    if (self.statusHandler) self.statusHandler(@"正在准备画中画");
}
- (void)captureTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    if (_invalidated || _capturePending || (!_exportRequested && !_pipRequested && !_pip.pictureInPictureActive)) return;
    CFTimeInterval now = CACurrentMediaTime();
    if (!_exportRequested && now - _lastCapture < 1.0 / 30) return;
    _lastCapture = now;
    const NSUInteger width = texture.width, height = texture.height;
    const NSUInteger rowBytes = (width * 4 + 255) & ~255;
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
            if (self->_invalidated || completed.status == MTLCommandBufferStatusError) return;
            CVPixelBufferRef pixelBuffer = NULL;
            NSDictionary* attributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey: @{}};
            if (CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                   (CFDictionaryRef)attributes, &pixelBuffer) != kCVReturnSuccess) return;
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            uint8_t* target = (uint8_t*)CVPixelBufferGetBaseAddress(pixelBuffer);
            size_t targetStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
            for (NSUInteger y = 0; y < height; y++) memcpy(target + y * targetStride, (uint8_t*)pixels.contents + y * rowBytes, width * 4);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            [self consumePixelBuffer:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
    }];
    [pixels release];
}
- (void)consumePixelBuffer:(CVPixelBufferRef)buffer
{
    if (_exportRequested) {
        _exportRequested = NO;
        CIImage* image = [CIImage imageWithCVPixelBuffer:buffer];
        CGImageRef cgImage = [_imageContext createCGImage:image fromRect:image.extent];
        if (cgImage) {
            NSData* png = UIImagePNGRepresentation([UIImage imageWithCGImage:cgImage]);
            CGImageRelease(cgImage);
            NSURL* file = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:
                [NSString stringWithFormat:@"Live2D-%@.png", NSUUID.UUID.UUIDString]]];
            if ([png writeToURL:file atomically:YES]) {
                UIActivityViewController* share = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
                share.popoverPresentationController.sourceView = _exportPresenter.view;
                share.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(_exportPresenter.view.bounds), CGRectGetMidY(_exportPresenter.view.bounds), 1, 1);
                [_exportPresenter presentViewController:share animated:YES completion:nil]; [share release];
                if (self.statusHandler) self.statusHandler(@"PNG 已生成，可保存到文件或分享");
            } else if (self.statusHandler) self.statusHandler(@"PNG 写入失败");
        }
        [_exportPresenter release]; _exportPresenter = nil;
    }
    if (_pipRequested || _pip.pictureInPictureActive) {
        if (_displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) [_displayLayer flush];
        CMVideoFormatDescriptionRef format = NULL; CMSampleBufferRef sample = NULL;
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, buffer, &format);
        CMSampleTimingInfo timing = {CMTimeMake(1, 30), CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000000), kCMTimeInvalid};
        if (format) CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, buffer, format, &timing, &sample);
        if (sample) {
            CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sample, YES);
            CFDictionarySetValue((CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0), kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
            if (_displayLayer.readyForMoreMediaData) [_displayLayer enqueueSampleBuffer:sample];
            CFRelease(sample);
        }
        if (format) CFRelease(format);
        if (_pipRequested && _pip.pictureInPicturePossible) { _pipRequested = NO; [_pip startPictureInPicture]; }
        else if (_pipRequested && CACurrentMediaTime() - _pipRequestTime > 8) {
            _pipRequested = NO; if (self.statusHandler) self.statusHandler(@"系统尚未允许画中画，请保持应用前台再试");
        }
    }
}
- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController*)controller
{ if (self.statusHandler) self.statusHandler(@"画中画已开启"); }
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController*)controller
{ [_displayLayer flushAndRemoveImage]; if (self.statusHandler) self.statusHandler(@"画中画已关闭"); }
- (void)pictureInPictureController:(AVPictureInPictureController*)controller failedToStartPictureInPictureWithError:(NSError*)error
{ _pipRequested = NO; if (self.statusHandler) self.statusHandler(error.localizedDescription); }
- (void)pictureInPictureController:(AVPictureInPictureController*)controller restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{ completionHandler(YES); }
- (void)pictureInPictureController:(AVPictureInPictureController*)controller setPlaying:(BOOL)playing {}
- (CMTimeRange)pictureInPictureControllerTimeRangeForPlayback:(AVPictureInPictureController*)controller
{ return CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity); }
- (BOOL)pictureInPictureControllerIsPlaybackPaused:(AVPictureInPictureController*)controller { return NO; }
- (void)pictureInPictureController:(AVPictureInPictureController*)controller didTransitionToRenderSize:(CMVideoDimensions)size {}
- (void)pictureInPictureController:(AVPictureInPictureController*)controller skipByInterval:(CMTime)interval completionHandler:(void (^)(void))completionHandler
{ completionHandler(); }
- (void)invalidate
{
    _invalidated = YES; _pipRequested = NO; [_pip stopPictureInPicture]; _pip.delegate = nil;
    [_displayLayer removeFromSuperlayer]; self.statusHandler = nil;
}
- (void)dealloc
{
    [self invalidate]; [_pip release]; [_displayLayer release]; [_exportPresenter release]; [_imageContext release]; [_statusHandler release]; [super dealloc];
}
@end
