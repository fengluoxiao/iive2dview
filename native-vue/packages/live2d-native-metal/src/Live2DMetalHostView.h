#import <UIKit/UIKit.h>

@interface Live2DMetalHostView : UIView <UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
- (void)setParameterValue:(float)value forId:(NSString*)parameterId;
- (void)resetFace;
- (void)presentModelImporter;
@end
