#import <React/RCTViewManager.h>
#import <React/RCTConvert.h>
#import <React/RCTUIManager.h>
#import <Live2DNativeMetal/Live2DMetalHostView.h>

@interface ExpoLive2DHostView : Live2DMetalHostView
@property (nonatomic, strong) NSNumber* angleX;
@property (nonatomic, strong) NSNumber* eyeOpen;
@property (nonatomic, strong) NSNumber* mouthOpen;
@property (nonatomic, strong) NSNumber* importRequest;
@property (nonatomic, strong) NSNumber* resetRequest;
@property (nonatomic, copy) RCTDirectEventBlock onStudioEvent;
@property (nonatomic, copy) NSDictionary* studioCommand;
@end

@implementation ExpoLive2DHostView

- (void)setOnStudioEvent:(RCTDirectEventBlock)event
{
    _onStudioEvent = [event copy];
    __weak ExpoLive2DHostView* weakSelf = self;
    self.studioEvent = ^(NSDictionary* state) {
        ExpoLive2DHostView* host = weakSelf;
        if (host.onStudioEvent) host.onStudioEvent(state);
    };
}

- (void)setStudioCommand:(NSDictionary*)command
{
    _studioCommand = [command copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performStudioCommand:command];
    });
}

- (void)setAngleX:(NSNumber*)value
{
    _angleX = value;
    [self setParameterValue:value.floatValue forId:@"ParamAngleX"];
}

- (void)setEyeOpen:(NSNumber*)value
{
    _eyeOpen = value;
    [self setParameterValue:value.floatValue forId:@"ParamEyeLOpen"];
    [self setParameterValue:value.floatValue forId:@"ParamEyeROpen"];
}

- (void)setMouthOpen:(NSNumber*)value
{
    _mouthOpen = value;
    [self setParameterValue:value.floatValue forId:@"ParamMouthOpenY"];
}

- (void)setImportRequest:(NSNumber*)value
{
    if (value.integerValue == _importRequest.integerValue) {
        return;
    }
    _importRequest = value;
    if (value.integerValue > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.window != nil) {
                [self presentModelImporter];
            }
        });
    }
}

- (void)setResetRequest:(NSNumber*)value
{
    if (value.integerValue == _resetRequest.integerValue) {
        return;
    }
    _resetRequest = value;
    if (value.integerValue > 0) {
        [self resetFace];
    }
}

@end

@interface ExpoLive2DHostViewManager : RCTViewManager
@end

@implementation ExpoLive2DHostViewManager

RCT_EXPORT_MODULE(ExpoLive2DHost)

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (UIView*)view
{
    return [[ExpoLive2DHostView alloc] initWithFrame:CGRectZero];
}

RCT_EXPORT_VIEW_PROPERTY(angleX, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(eyeOpen, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(mouthOpen, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(importRequest, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(resetRequest, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(studioCommand, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(onStudioEvent, RCTDirectEventBlock)

@end
