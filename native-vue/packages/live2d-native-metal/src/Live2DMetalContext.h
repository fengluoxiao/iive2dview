#import <Foundation/Foundation.h>

@class ViewController;
@class LAppTextureManager;

// The Cubism Metal sample expects to find these through its own AppDelegate.
// The embedded NativeScript view owns them instead.
FOUNDATION_EXPORT void Live2DMetalSetHost(ViewController* viewController, LAppTextureManager* textureManager);
FOUNDATION_EXPORT void Live2DMetalClearHost(ViewController* viewController);
FOUNDATION_EXPORT ViewController* Live2DMetalHostViewController(void);
FOUNDATION_EXPORT LAppTextureManager* Live2DMetalHostTextureManager(void);
