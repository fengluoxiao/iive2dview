#import "Live2DMetalContext.h"

static ViewController* gViewController = nil;
static LAppTextureManager* gTextureManager = nil;

void Live2DMetalSetHost(ViewController* viewController, LAppTextureManager* textureManager)
{
    gViewController = viewController;
    gTextureManager = textureManager;
}

void Live2DMetalClearHost(ViewController* viewController)
{
    if (gViewController == viewController) {
        gViewController = nil;
        gTextureManager = nil;
    }
}

ViewController* Live2DMetalHostViewController(void)
{
    return gViewController;
}

LAppTextureManager* Live2DMetalHostTextureManager(void)
{
    return gTextureManager;
}
