#import <UIKit/UIKit.h>

// Owns the complete UIKit presentation session, independent of the RN tree.
@interface Live2DFolderPicker : UIViewController <UIDocumentPickerDelegate>
@property (nonatomic, assign) id<UIDocumentPickerDelegate> resultDelegate;
- (BOOL)openFromWindow:(UIWindow*)window;
- (void)invalidate;
@end
