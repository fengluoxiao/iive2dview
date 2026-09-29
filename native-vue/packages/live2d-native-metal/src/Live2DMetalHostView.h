#import <UIKit/UIKit.h>

@interface Live2DMetalHostView : UIView <UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@property (nonatomic, copy) void (^studioEvent)(NSDictionary* state);
- (void)performStudioCommand:(NSDictionary*)command;
- (void)setParameterValue:(float)value forId:(NSString*)parameterId;
- (void)resetFace;
- (void)presentModelImporter;
@end
