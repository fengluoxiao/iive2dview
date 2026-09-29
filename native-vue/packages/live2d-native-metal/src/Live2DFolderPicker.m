#import "Live2DFolderPicker.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation Live2DFolderPicker {
    UIWindow* _pickerWindow;
    UIWindow* _previousWindow;
    UIDocumentPickerViewController* _picker;
    BOOL _presented;
    BOOL _finished;
}

- (BOOL)openFromWindow:(UIWindow*)window
{
    if (_pickerWindow || !window.windowScene ||
        window.windowScene.activationState != UISceneActivationStateForegroundActive) return NO;
    _previousWindow = [window retain];
    _picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    _picker.delegate = self;
    _picker.allowsMultipleSelection = NO;
    _picker.modalPresentationStyle = UIModalPresentationOverFullScreen;
    _pickerWindow = [[UIWindow alloc] initWithWindowScene:window.windowScene];
    _pickerWindow.frame = window.bounds;
    _pickerWindow.windowLevel = window.windowLevel + 1;
    _pickerWindow.rootViewController = self;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [_pickerWindow makeKeyAndVisible];
    return YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_presented || _finished || !_picker) return;
    _presented = YES;
    // Present only once this plain UIKit controller has joined its scene.
    [self presentViewController:_picker animated:YES completion:^{
        NSLog(@"Live2D folder picker: isolated UIKit presentation ready");
    }];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    if (_finished) return;
    _finished = YES;
    NSLog(@"Live2D folder picker: received %lu URL(s)", (unsigned long)urls.count);
    // Acquire security scope in the importer synchronously, before dismissal.
    [self.resultDelegate documentPicker:controller didPickDocumentsAtURLs:urls];
    [self close];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentAtURL:(NSURL*)url
{
    [self documentPicker:controller didPickDocumentsAtURLs:url ? @[url] : @[]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    if (_finished) return;
    _finished = YES;
    [self.resultDelegate documentPickerWasCancelled:controller];
    [self close];
}

- (void)close
{
    // Never destroy a provider's presentation hierarchy inside its delegate call.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:^{ [self invalidate]; }];
    });
}

- (void)invalidate
{
    _finished = YES;
    self.resultDelegate = nil;
    _picker.delegate = nil;
    BOOL restoreKey = _pickerWindow.isKeyWindow;
    _pickerWindow.hidden = YES;
    _pickerWindow.rootViewController = nil;
    if (restoreKey && !_previousWindow.hidden) [_previousWindow makeKeyWindow];
    [_pickerWindow release]; _pickerWindow = nil;
    [_previousWindow release]; _previousWindow = nil;
    [_picker release]; _picker = nil;
}

- (void)dealloc
{
    [self invalidate];
    [super dealloc];
}
@end
