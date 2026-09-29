#import "Live2DFolderPicker.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation Live2DFolderPicker {
    UIViewController* _presenter;
    UIDocumentPickerViewController* _picker;
    BOOL _finished;
}

- (BOOL)openFromWindow:(UIWindow*)window
{
    if (_picker || !window.windowScene ||
        window.windowScene.activationState != UISceneActivationStateForegroundActive) return NO;
    UIViewController* presenter = window.rootViewController;
    while (presenter.presentedViewController && !presenter.presentedViewController.isBeingDismissed)
        presenter = presenter.presentedViewController;
    if (!presenter.view.window || presenter.isBeingDismissed) return NO;
    _presenter = [presenter retain];
    _picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    _picker.delegate = self;
    _picker.allowsMultipleSelection = NO;
    _picker.modalPresentationStyle = UIModalPresentationOverFullScreen;
    // Keep the live application underneath while Files prepares its remote UI.
    // An extra opaque window caused a black screen before Files appeared.
    [_presenter presentViewController:_picker animated:YES completion:nil];
    return YES;
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
        if (self->_presenter.presentedViewController == self->_picker)
            [self->_presenter dismissViewControllerAnimated:YES completion:^{ [self invalidate]; }];
        else [self invalidate];
    });
}

- (void)invalidate
{
    _finished = YES;
    self.resultDelegate = nil;
    _picker.delegate = nil;
    [_presenter release]; _presenter = nil;
    [_picker release]; _picker = nil;
}

- (void)dealloc
{
    [self invalidate];
    [super dealloc];
}
@end
