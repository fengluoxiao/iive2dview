#import <UIKit/UIKit.h>

// Retains the delegate for the complete system picker session.
@interface Live2DFolderPicker : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, assign) id<UIDocumentPickerDelegate> resultDelegate;
- (BOOL)openFromWindow:(UIWindow*)window;
- (void)invalidate;
@end
