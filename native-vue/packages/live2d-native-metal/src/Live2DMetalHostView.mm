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

@implementation Live2DMetalHostView
{
    ViewController* _renderer;
    UIView* _metalView;
    LAppTextureManager* _textureManager;
    NSURL* _importDirectory;
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
        // The embedded app imports its own models and does not bundle the
        // Cubism demo's background/control PNGs. Avoid initializing those
        // optional demo sprites during startup.
    }
    return self;
}

- (void)setParameterValue:(float)value forId:(NSString*)parameterId
{
    LAppLive2DManager* manager = [LAppLive2DManager getInstance];
    LAppModel* model = [manager getModel:0];
    if (model == nil) {
        return;
    }
    CubismIdHandle parameter = CubismFramework::GetIdManager()->GetId(parameterId.UTF8String);
    model->GetModel()->SetParameterValue(parameter, value);
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
    __weak typeof(self) weakSelf = self;
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"Import folder"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction* action) {
        [weakSelf presentModelPickerForContentTypes:@[UTType.folder]];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"Import ZIP"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(__unused UIAlertAction* action) {
        UTType* zipType = [UTType typeWithFilenameExtension:@"zip"];
        [weakSelf presentModelPickerForContentTypes:(zipType == nil ? @[] : @[zipType])];
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

    BOOL imported = NO;
    if ([selectedURL.pathExtension caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
        imported = [SSZipArchive unzipFileAtPath:selectedURL.path toDestination:destination.path];
    } else {
        NSURL* importedDirectory = [destination URLByAppendingPathComponent:selectedURL.lastPathComponent isDirectory:YES];
        imported = [fileManager copyItemAtURL:selectedURL toURL:importedDirectory error:nil];
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
    _importDirectory = [destination retain];
    NSString* directory = [modelURL.path.stringByDeletingLastPathComponent stringByAppendingString:@"/"];
    LAppLive2DManager* manager = [LAppLive2DManager getInstance];
    [manager loadModelAtDirectory:directory.UTF8String fileName:modelURL.lastPathComponent.UTF8String];
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
    [_importDirectory release];
    [_textureManager release];
    [_renderer release];
    [super dealloc];
}

@end
