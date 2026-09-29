#import "Live2DMetalHostView.h"
#import "ViewController.h"
#import "LAppLive2DManager.h"
#import "LAppModel.h"
#import "LAppAllocator.h"
#import "LAppDefine.h"
#import "LAppPal.h"
#import "LAppTextureManager.h"
#import "Live2DMetalContext.h"
#import "Live2DStudioMedia.h"
#import "Live2DModelLibrary.h"
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
    NSArray* _studioCatalog;
    NSDictionary* _studioModelURLs;
    NSDictionary* _studioMetadata;
    NSString* _studioModelId;
    NSString* _studioDirection;
    NSString* _studioStatus;
    BOOL _studioBlink;
    BOOL _studioInitialized;
    BOOL _studioImporting;
    NSString* _studioPendingModelId;
    NSInteger _studioExpressionIndex;
    Live2DStudioMedia* _studioMedia;
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
        _studioMedia = [[Live2DStudioMedia alloc] init];
        Live2DStudioMedia* media = _studioMedia;
        _renderer.studioFrameHandler = ^(id<MTLTexture> texture, id<MTLCommandBuffer> buffer) {
            [media captureTexture:texture commandBuffer:buffer];
        };
        __unsafe_unretained Live2DMetalHostView* host = self;
        [_studioMedia configureSourceView:_metalView device:[_renderer getDevice]
            renderHandler:^(CAMetalLayer* layer) { [host->_renderer renderStudioPipLayer:layer]; }
            activeHandler:^(BOOL active) { [host->_renderer setStudioPipActive:active]; }];
        _renderer.studioRenderErrorHandler = ^(NSString* message) { [host studioSetStatus:message]; [host studioEmitState]; };
        _studioMedia.statusHandler = ^(NSString* message) { [host studioSetStatus:message]; [host studioEmitState]; };
        _parameterValues = [[NSMutableDictionary alloc] init];
        _studioDirection = [@"C" copy];
        _studioStatus = [@"导入文件夹或 ZIP，开始预览" copy];
        _studioBlink = YES;
        _studioExpressionIndex = -1;
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

- (void)layoutSubviews
{
    [super layoutSubviews];
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
    [_parameterValues removeAllObjects];
    LAppModel* model = [[LAppLive2DManager getInstance] getModel:0];
    if (model) model->ClearExternalParameters();
}

- (NSURL*)studioLibraryURL
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject
            URLByAppendingPathComponent:@"Live2DModels" isDirectory:YES];
}

- (void)studioSetStatus:(NSString*)message
{
    [_studioStatus release];
    _studioStatus = [message copy];
}

- (void)studioScanLibrary
{
    NSURL* root = [self studioLibraryURL];
    NSMutableArray* catalog = [NSMutableArray array];
    NSMutableDictionary* modelURLs = [NSMutableDictionary dictionary];
    NSDirectoryEnumerator* files = [[NSFileManager defaultManager] enumeratorAtURL:root includingPropertiesForKeys:nil
        options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    for (NSURL* url in files) {
        if (![url.lastPathComponent.lowercaseString hasSuffix:@".model3.json"]) continue;
        NSString* relative = Live2DModelIdentifier(root, url);
        if (!relative) continue;
        NSNumber* regular = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (!regular.boolValue) continue;
        modelURLs[relative] = url;
        NSArray* parts = relative.pathComponents;
        NSString* outfit = [url.lastPathComponent substringToIndex:url.lastPathComponent.length - 12];
        // The first component is our import UUID, never expose it as a name.
        NSString* character = parts.count > 2 ? parts[1] : outfit;
        [catalog addObject:@{@"id": relative, @"character": character, @"outfit": outfit}];
    }
    [_studioCatalog release];
    [_studioModelURLs release];
    _studioModelURLs = [modelURLs copy];
    _studioCatalog = [[catalog sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* a, NSDictionary* b) {
        return [a[@"id"] localizedStandardCompare:b[@"id"]];
    }] copy];
}

- (void)studioConfigureIdle
{
    LAppModel* model = [[LAppLive2DManager getInstance] getModel:0];
    if (!model) return;
    NSDictionary* groups = _studioMetadata[@"motions"];
    NSString* idleGroup = nil;
    for (NSString* group in groups) {
        if ([group.lowercaseString isEqualToString:@"idle"]) { idleGroup = group; break; }
    }
    std::vector<int> matches, all;
    NSArray* entries = groups[idleGroup ?: @""];
    for (NSUInteger i = 0; i < entries.count; i++) {
        all.push_back((int)i);
        NSString* name = entries[i][@"Name"];
        if (!name) {
            name = [entries[i][@"File"] lastPathComponent];
            if ([name hasSuffix:@".motion3.json"]) name = [name substringToIndex:name.length - 13];
        }
        if ([name hasSuffix:[@"_" stringByAppendingString:_studioDirection]]) matches.push_back((int)i);
    }
    model->ConfigureIdle((idleGroup ?: @"").UTF8String, matches.empty() ? all : matches);
    model->SetBlinkEnabled(_studioBlink);
}

- (void)studioLoadModel:(NSString*)identifier
{
    NSDictionary* entry = nil;
    for (NSDictionary* item in _studioCatalog) {
        if ([item[@"id"] isEqual:identifier]) { entry = item; break; }
    }
    if (!entry) { [self studioSetStatus:@"找不到该模型，请重新导入"]; return; }
    NSURL* url = _studioModelURLs[identifier];
    NSError* readError = nil;
    NSDictionary* json = Live2DReadModelConfiguration(url, &readError);
    if (!json) {
        [self studioSetStatus:[NSString stringWithFormat:@"%@：%@", url.lastPathComponent ?: @"模型配置",
            readError.localizedDescription ?: @"无法读取文件"]]; return;
    }
    NSString* directory = [url.path.stringByDeletingLastPathComponent stringByAppendingString:@"/"];
    LAppLive2DManager* manager = [LAppLive2DManager getInstance];
    if (![manager loadModelAtDirectory:directory.UTF8String fileName:url.lastPathComponent.UTF8String]) {
        [_studioModelId release]; _studioModelId = nil;
        [_studioMetadata release]; _studioMetadata = nil;
        [self studioSetStatus:@"模型加载失败，请检查 moc3 和贴图文件"]; return;
    }
    [self resetFace];
    _studioExpressionIndex = -1;
    [_renderer resetStudioPosition];
    [_renderer setStudioScale:1];
    [_studioModelId release];
    _studioModelId = [identifier copy];
    [_studioMetadata release];
    NSDictionary* refs = json[@"FileReferences"];
    _studioMetadata = [@{@"motions": refs[@"Motions"] ?: @{}, @"expressions": refs[@"Expressions"] ?: @[],
                        @"drawables": @([manager getModel:0]->GetModel()->GetDrawableCount())} copy];
    [self studioConfigureIdle];
    [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:@"studioLastModel"];
    [self studioSetStatus:[NSString stringWithFormat:@"%@ 已就绪", entry[@"outfit"]]];
}

- (void)studioEmitState
{
    if (!self.studioEvent) return;
    self.studioEvent(@{@"models": _studioCatalog ?: @[], @"selectedModelId": _studioModelId ?: @"",
        @"metadata": _studioMetadata ?: @{}, @"view": [_renderer studioViewState],
        @"status": _studioStatus ?: @"", @"direction": _studioDirection, @"blink": @(_studioBlink),
        @"expressionIndex": @(_studioExpressionIndex)});
}

- (void)performStudioCommand:(NSDictionary*)command
{
    NSString* type = command[@"type"];
    LAppModel* model = [[LAppLive2DManager getInstance] getModel:0];
    if (!_studioInitialized && UIApplication.sharedApplication.applicationState == UIApplicationStateActive && self.window && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
        _studioInitialized = YES;
        [self studioScanLibrary];
        NSString* last = [[NSUserDefaults standardUserDefaults] stringForKey:@"studioLastModel"];
        BOOL found = NO;
        for (NSDictionary* item in _studioCatalog) if ([item[@"id"] isEqual:last]) found = YES;
        if (!_studioModelId && _studioCatalog.count) [self studioLoadModel:found ? last : _studioCatalog[0][@"id"]];
        model = [[LAppLive2DManager getInstance] getModel:0];
    }
    if (_studioPendingModelId && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        [self studioLoadModel:_studioPendingModelId];
        [_studioPendingModelId release]; _studioPendingModelId = nil;
        model = [[LAppLive2DManager getInstance] getModel:0];
    }
    if ([type isEqual:@"import"]) {
        [self presentModelImporter];
    } else if ([type isEqual:@"selectModel"]) {
        [self studioLoadModel:command[@"id"]];
    } else if ([type isEqual:@"parameter"]) {
        for (NSString* parameter in command[@"ids"]) [self setParameterValue:[command[@"value"] floatValue] forId:parameter];
    } else if ([type isEqual:@"resetFace"]) {
        [self resetFace];
    } else if ([type isEqual:@"direction"]) {
        [_studioDirection release];
        _studioDirection = [command[@"value"] copy];
        [self studioConfigureIdle];
        if (model) model->StopStudioMotion();
    } else if ([type isEqual:@"blink"]) {
        _studioBlink = [command[@"value"] boolValue];
        if (model) model->SetBlinkEnabled(_studioBlink);
    } else if ([type isEqual:@"motion"] && model) {
        NSString* group = command[@"group"];
        NSArray* entries = _studioMetadata[@"motions"][group];
        NSInteger index = [command[@"index"] integerValue];
        if (index >= 0 && index < (NSInteger)entries.count) model->StartMotion(group.UTF8String, (int)index, LAppDefine::PriorityForce);
    } else if ([type isEqual:@"expression"] && model) {
        NSInteger index = [command[@"index"] integerValue];
        NSArray* entries = _studioMetadata[@"expressions"];
        if (index < 0) { model->ClearStudioExpression(); _studioExpressionIndex = -1; }
        else if (index < (NSInteger)entries.count) { model->SetExpression([entries[index][@"Name"] UTF8String]); _studioExpressionIndex = index; }
    } else if ([type isEqual:@"scale"]) {
        [_renderer setStudioScale:[command[@"value"] doubleValue]];
    } else if ([type isEqual:@"mirror"]) {
        _renderer.studioMirrored = [command[@"value"] boolValue];
    } else if ([type isEqual:@"quality"]) {
        [_renderer setStudioQuality:command[@"value"]];
    } else if ([type isEqual:@"export"]) {
        [_studioMedia requestExportFrom:[self activePresenter]];
    } else if ([type isEqual:@"pip"]) {
        [_studioMedia togglePictureInPicture];
    } else if ([type isEqual:@"reset"]) {
        [self resetFace];
        [_renderer resetStudioPosition];
        if (model) {
            model->StopStudioMotion();
            NSArray* entries = _studioMetadata[@"expressions"];
            if (entries.count) {
                _studioExpressionIndex = arc4random_uniform((uint32_t)entries.count);
                model->SetExpression([entries[_studioExpressionIndex][@"Name"] UTF8String]);
            } else { model->ClearStudioExpression(); _studioExpressionIndex = -1; }
        }
    }
    [self studioEmitState];
}

- (void)presentModelImporter
{
    if (_studioImporting) {
        [self studioSetStatus:@"模型正在导入，请等待当前复制完成"]; [self studioEmitState]; return;
    }
    UIViewController* presenter = [self activePresenter];
    if (presenter == nil) {
        return;
    }

    UIAlertController* sourcePicker = [UIAlertController
        alertControllerWithTitle:@"导入 Live2D 模型"
        message:@"选择完整模型文件夹或 ZIP 压缩包"
        preferredStyle:UIAlertControllerStyleAlert];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"导入文件夹"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action) {
        (void)action;
        [presenter dismissViewControllerAnimated:YES completion:^{ [self presentFolderImporter]; }];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"导入 ZIP"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action) {
        (void)action;
        UTType* zipType = [UTType typeWithFilenameExtension:@"zip"];
        [presenter dismissViewControllerAnimated:YES completion:^{
            [self presentModelPickerForContentTypes:(zipType == nil ? @[] : @[zipType])];
        }];
    }]];
    [sourcePicker addAction:[UIAlertAction actionWithTitle:@"取消"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil]];

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
    if (!selectedURL || _studioImporting) return;
    _studioImporting = YES;
    [self studioSetStatus:@"正在导入：等待云盘下载并复制模型，请稍候…"];
    [self studioEmitState];

    // iCloud coordination can download an entire directory. Never block UIKit
    // while waiting for the file provider, and hold access until copying ends.
    BOOL accessing = [selectedURL startAccessingSecurityScopedResource];
    NSURL* library = [self studioLibraryURL];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSFileManager* fm = NSFileManager.defaultManager;
            NSURL* destination = [library URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
            NSError* setupError = nil;
            BOOL created = [fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:&setupError];
            __block BOOL imported = NO;
            __block NSError* copyError = nil;
            NSError* coordinationError = nil;
            NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            @try {
                if (created) {
                    [coordinator coordinateReadingItemAtURL:selectedURL options:0 error:&coordinationError byAccessor:^(NSURL* readableURL) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self studioSetStatus:@"正在复制并检查模型文件…"]; [self studioEmitState];
                        });
                        if ([selectedURL.pathExtension caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
                            // The copied ZIP from UIDocumentPicker may already
                            // be inside our sandbox and need no security scope.
                            imported = [SSZipArchive unzipFileAtPath:readableURL.path toDestination:destination.path];
                            if (!imported) copyError = [NSError errorWithDomain:@"Live2DImport" code:2
                                userInfo:@{NSLocalizedDescriptionKey: @"ZIP 解压失败，请确认文件已完整下载且未加密"}];
                        } else {
                            NSURL* target = [destination URLByAppendingPathComponent:selectedURL.lastPathComponent isDirectory:YES];
                            // A false startAccessing result is not by itself an
                            // I/O failure for URLs already accessible to the app.
                            imported = [fm copyItemAtURL:readableURL toURL:target error:&copyError];
                        }
                    }];
                }
            } @finally {
                [coordinator release];
                if (accessing) [selectedURL stopAccessingSecurityScopedResource];
            }
            NSError* error = setupError ?: coordinationError ?: copyError;
            NSURL* modelURL = imported && !error ? [self firstModelURLInDirectory:destination] : nil;
            NSString* failure = error.localizedDescription;
            if (!modelURL && !failure) failure = imported
                ? @"未找到 .model3.json，请选择包含模型配置、moc3 和贴图的文件夹"
                : @"文件提供方未允许读取，请先在“文件”中下载该文件夹后重试";
            if (!modelURL && created) [fm removeItemAtURL:destination error:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_studioImporting = NO;
                if (!modelURL) {
                    [self studioSetStatus:[NSString stringWithFormat:@"导入失败：%@", failure]];
                    [self studioEmitState]; return;
                }
                [self->_importDirectory release];
                self->_importDirectory = [destination retain];
                [self studioSetStatus:@"复制完成，正在加载模型…"]; [self studioEmitState];
                [self studioScanLibrary];
                NSString* identifier = Live2DModelIdentifier(library, modelURL);
                if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
                    [self studioLoadModel:identifier];
                } else {
                    [self->_studioPendingModelId release];
                    self->_studioPendingModelId = [identifier copy];
                    [self studioSetStatus:@"复制完成，返回应用后加载模型"];
                }
                [self studioEmitState];
            });
        }
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    [self studioSetStatus:@"已取消导入"]; [self studioEmitState];
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
    [_studioMedia invalidate];
    _renderer.studioFrameHandler = nil;
    _renderer.studioRenderErrorHandler = nil;
    [_studioMedia release];
    Live2DMetalClearHost(_renderer);
    if (_rendererAttachedToHost) {
        [_renderer willMoveToParentViewController:nil];
        [_renderer removeFromParentViewController];
    }
    [_metalView removeFromSuperview];
    [_pinchGesture release];
    [_panGesture release];
    [_parameterValues release];
    [_studioCatalog release];
    [_studioModelURLs release];
    [_studioPendingModelId release];
    [_studioMetadata release];
    [_studioModelId release];
    [_studioDirection release];
    [_studioStatus release];
    [_studioEvent release];
    [_importDirectory release];
    [_textureManager release];
    [_renderer release];
    [super dealloc];
}

@end
