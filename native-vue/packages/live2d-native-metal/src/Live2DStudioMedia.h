#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <AVKit/AVKit.h>

@interface Live2DStudioMedia : NSObject <AVPictureInPictureSampleBufferPlaybackDelegate, AVPictureInPictureControllerDelegate>
@property (nonatomic, copy) void (^statusHandler)(NSString* message);
@property (nonatomic, readonly) AVSampleBufferDisplayLayer* displayLayer;
- (void)requestExportFrom:(UIViewController*)presenter;
- (void)togglePictureInPicture;
- (void)captureTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)invalidate;
@end
