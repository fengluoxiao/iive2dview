#import "Live2DMetalHostView.h"
#import "ViewController.h"
#import "LAppLive2DManager.h"
#import "LAppModel.h"
#import "LAppAllocator.h"
#import "LAppDefine.h"
#import "LAppPal.h"
#import "LAppTextureManager.h"
#import "Live2DMetalContext.h"
#import <SSZipArchive/SSZipArchive.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CubismFramework.hpp>
#import <Id/CubismIdManager.hpp>

using namespace Csm;

namespace {
LAppAllocator* gCubismAllocator = nullptr;
CubismFramework::Option gCubismOption;
bool gCubismInitialized = false;

void InitializeCubismOnce()
{
    if (gCubismInitialized) {
        return;
    }

    gCubismAllocator = new LAppAllocator();
    gCubismOption.LogFunction = LAppPal::PrintMessageLn;
    gCubismOption.LoggingLevel = LAppDefine::CubismLoggingLevel;
    gCubismOption.LoadFileFunction = LAppPal::LoadFileAsBytes;
    gCubismOption.ReleaseBytesFunction = LAppPal::ReleaseBytes;
    CubismFramework::StartUp(gCubismAllocator, &gCubismOption);
    CubismFramework::Initialize();
    LAppPal::UpdateTime();
    gCubismInitialized = true;
}
}

@interface Live2DMetalHostView () <UIGestureRecognizerDelegate>
@end

@implementation Live2DMetalHostView
{
    ViewController* _renderer;
    UIView* _metalView;
    LAppTextureManager* _textureManager;
    NSURL* _importDirectory;
    NSMutableDictionary<NSString*, NSNumber*>* _parameterValues;
    UIPinchGestureRecognizer* _pinchGesture;
    UIPanGestureRecognizer* _panGesture;
    CGFloat _lastPinchScale;
    BOOL _rendererAttachedToHost;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (_rendererAttachedToHost || self.window == nil) {
        return;
    }

    // The sample renderer is a view controller.  Attaching it to the React
    // Native root controller gives UIKit a complete lifecycle on modern iOS
    // scene-based applications instead of leaving its view orphaned.
    UIViewController* hostController = self.window.rootViewController;
    if (hostController == nil) {
        return;
    }
    [hostController addChildViewController:_renderer];
    [_renderer didMoveToParentViewController:hostController];
    _rendererAttachedToHost = YES;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        InitializeCubismOnce();
        _renderer = [[ViewController alloc] init];
        _textureManager = [[LAppTextureManager alloc] init];
        _renderer.textureManager = _textureManager;
        Live2DMetalSetHost(_renderer, _textureManager);
        _metalView = _renderer.view;
        _metalView.frame = self.bounds;
        _metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        // NativeScript owns gestures in the surrounding view tree. The sample's
        // menu hit testing is intentionally disabled for this embedded renderer.
        _metalView.userInteractionEnabled = NO;
        [self addSubview:_metalView];
        _parameterValues = [[NSMutableDictionary alloc] init];
        _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        _pinchGesture.cancelsTouchesInView = YES;
        _pinchGesture.delegate = self;
        [self addGestureRecognizer:_pinchGesture];
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGesture.minimumNumberOfTouches = 1;
        _panGesture.maximumNumberOfTouches = 1;
        _panGesture.delegate = self;
        [self addGestureRecognizer:_panGesture];
        // The embedded app imports its own models and does not bundle the
        // Cubism demo's background/control PNGs. Avoid initializing those
        // optional demo sprites during startup.
    }
    return self;
}

- (void)setParameterValue:(float)value forId:(NSString*)parameterId
{
    if (parameterId == nil) {
        return;
    }
    [_parameterValues setObject:@(value) forKey:parameterId];
    LAppLive2DManager* manager = [LAppLive2DManager getInstance];
    LAppModel* model = [manager getModel:0];
    if (model == nil || model->GetModel() == NULL) {
        return;
    }
    CubismIdHandle parameter = CubismFramework::GetIdManager()->GetId(parameterId.UTF8String);
    model->SetExternalParameterValue(parameter, value);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gesture
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)other
{
    return (gesture == _panGesture && other == _pinchGesture)
        || (gesture == _pinchGesture && other == _panGesture);
}

- (void)handlePan:(UIPanGestureRecognizer*)gesture
{
    if ((gesture.state == UIGestureRecognizerStateBegan
         || gesture.state == UIGestureRecognizerStateChanged)
        && gesture.numberOfTouches == 1
        && _pinchGesture.state != UIGestureRecognizerStateBegan
        && _pinchGesture.state != UIGestureRecognizerStateChanged) {
        [_renderer translateViewBy:[gesture translationInView:_metalView]];
    }
    // Consume only the current movement, including during finger transitions.
    [gesture setTranslation:CGPointZero inView:_metalView];
}

- (void)handlePinch:(UIPinchGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _lastPinchScale = gesture.scale;
        return;
    }
    if (gesture.state != UIGestureRecognizerStateChanged || _lastPinchScale <= 0.0f) {
        return;
    }

    const CGFloat factor = gesture.scale / _lastPinchScale;
    [_renderer adjustViewScaleAtPoint:[gesture locationInView:_metalView] factor:factor];
    _lastPinchScale = gesture.scale;
}

- (void)resetFace
{
    [self setParameterValue:0.0f forId:@"ParamAngleX"];
    [self setParameterValue:1.0f forId:@"ParamEyeLOpen"];
    [self setParameterValue:1.0f forId:@"ParamEyeROpen"];
    [self setParameterValue:0.0f forId:@"ParamMouthOpenY"];
}

- (void)presentModelImporter
{
    UIViewController* presenter = [self activePresenter];
    if (presenter == nil) {
        return;
    }

    UIAlertController* sourcePicker = [UIAlertController
        alertControllerWithTitle:@"Import Live2D model"
        message:@"Choose a model folder or a ZIP archive."
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"Import folder"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action) {
        (void)action;
        [self presentFolderImporter];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"Import ZIP"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action) {
        (void)action;
        UTType* zipType = [UTType typeWithFilenameExtension:@"zip"];
        [self presentModelPickerForContentTypes:(zipType == nil ? @[] : @[zipType])];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];

    // An action sheet needs a source rectangle when this host is ever used on
    // an iPad. On iPhone it remains the normal bottom sheet.
    UIPopoverPresentationController* popover = sourcePicker.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self;
        popover.sourceRect = self.bounds;
    }
    [presenter presentViewController:sourcePicker animated:YES completion:nil];
}

- (UIViewController*)activePresenter
{
    UIViewController* presenter = self.window.rootViewController;
    while (presenter.presentedViewController != nil) {
        presenter = presenter.presentedViewController;
    }
    return presenter;
}

- (void)presentModelPickerForContentTypes:(NSArray<UTType*>*)contentTypes
{
    if (contentTypes.count == 0) {
        return;
    }

    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:contentTypes
        asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    UIViewController* presenter = [self activePresenter];
    if (presenter == nil) {
        [picker release];
        return;
    }
    [presenter presentViewController:picker animated:YES completion:nil];
    [picker release];
}

- (void)presentFolderImporter
{
    // Directories require open-in-place mode, not import/copy mode.
    // Copy the selected directory ourselves while holding security access.
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeFolder]
        asCopy:NO];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    UIViewController* presenter = [self activePresenter];
    if (presenter == nil) {
        [picker release];
        return;
    }
    [presenter presentViewController:picker animated:YES completion:nil];
    [picker release];
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    NSURL* selectedURL = urls.firstObject;
    if (selectedURL == nil) {
        return;
    }

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSURL* appSupport = [fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* modelsDirectory = [appSupport URLByAppendingPathComponent:@"Live2DModels" isDirectory:YES];
    [fileManager createDirectoryAtURL:modelsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL* destination = [modelsDirectory URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    [fileManager createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:nil];

    __block BOOL imported = NO;
    if ([selectedURL.pathExtension caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
        imported = [SSZipArchive unzipFileAtPath:selectedURL.path toDestination:destination.path];
    } else {
        BOOL accessing = [selectedURL startAccessingSecurityScopedResource];
        if (accessing) {
            NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            NSError* coordinationError = nil;
            @try {
                [coordinator coordinateReadingItemAtURL:selectedURL
                                               options:0
                                                 error:&coordinationError
                                            byAccessor:^(NSURL* readableURL) {
                    NSURL* importedDirectory = [destination URLByAppendingPathComponent:selectedURL.lastPathComponent isDirectory:YES];
                    imported = [fileManager copyItemAtURL:readableURL toURL:importedDirectory error:nil];
                }];
                if (coordinationError != nil) {
                    imported = NO;
                }
            } @finally {
                [coordinator release];
                [selectedURL stopAccessingSecurityScopedResource];
            }
        }
    }
    if (!imported) {
        [fileManager removeItemAtURL:destination error:nil];
        return;
    }

    NSURL* modelURL = [self firstModelURLInDirectory:destination];
    if (modelURL == nil) {
        [fileManager removeItemAtURL:destination error:nil];
        return;
    }
    [_importDirectory release];
    _importDirectory = [destination retain];
    NSString* directory = [modelURL.path.stringByDeletingLastPathComponent stringByAppendingString:@"/"];
    LAppLive2DManager* manager = [LAppLive2DManager getInstance];
    [manager loadModelAtDirectory:directory.UTF8String fileName:modelURL.lastPathComponent.UTF8String];
    // setParameterValue writes back to _parameterValues. Enumerate a snapshot
    // so restoring controls cannot mutate the collection being enumerated.
    NSDictionary<NSString*, NSNumber*>* savedParameters = [_parameterValues copy];
    for (NSString* parameterId in savedParameters) {
        [self setParameterValue:[[savedParameters objectForKey:parameterId] floatValue] forId:parameterId];
    }
    [savedParameters release];
}

- (NSURL*)firstModelURLInDirectory:(NSURL*)directory
{
    NSDirectoryEnumerator<NSURL*>* files = [[NSFileManager defaultManager]
        enumeratorAtURL:directory
        includingPropertiesForKeys:nil
        options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:nil];
    for (NSURL* fileURL in files) {
        if ([fileURL.lastPathComponent.lowercaseString hasSuffix:@".model3.json"]) {
            return fileURL;
        }
    }
    return nil;
}

- (void)dealloc
{
    Live2DMetalClearHost(_renderer);
    if (_rendererAttachedToHost) {
        [_renderer willMoveToParentViewController:nil];
        [_renderer removeFromParentViewController];
    }
    [_metalView removeFromSuperview];
    [_pinchGesture release];
    [_panGesture release];
    [_parameterValues release];
    [_importDirectory release];
    [_textureManager release];
    [_renderer release];
    [super dealloc];
}

@end
