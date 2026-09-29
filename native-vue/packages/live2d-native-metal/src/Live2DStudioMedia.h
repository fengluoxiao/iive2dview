#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <AVKit/AVKit.h>
#import <MetalKit/MetalKit.h>

@interface Live2DStudioMedia : NSObject <AVPictureInPictureControllerDelegate, MTKViewDelegate>
@property (nonatomic, copy) void (^statusHandler)(NSString* message);
- (void)configureSourceView:(UIView*)source device:(id<MTLDevice>)device
             renderHandler:(BOOL (^)(MTKView*))renderHandler
             activeHandler:(void (^)(BOOL))activeHandler;
- (void)requestExportFrom:(UIViewController*)presenter;
- (void)togglePictureInPicture;
- (NSDictionary*)pictureInPictureDiagnostics;
- (void)captureTexture:(id<MTLTexture>)texture commandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (void)invalidate;
@end
