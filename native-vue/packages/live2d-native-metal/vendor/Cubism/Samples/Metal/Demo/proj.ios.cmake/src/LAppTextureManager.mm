/**
 * Copyright(c) Live2D Inc. All rights reserved.
 *
 * Use of this source code is governed by the Live2D Open Software license
 * that can be found at https://www.live2d.com/eula/live2d-open-software-license-agreement_en.html.
 */

#import "LAppTextureManager.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <iostream>
#define STBI_NO_STDIO
#define STBI_ONLY_PNG
#define STB_IMAGE_IMPLEMENTATION
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcomma"
#pragma clang diagnostic ignored "-Wunused-function"
#import "stb_image.h"
#pragma clang diagnostic pop
#import "LAppPal.h"
#import "ViewController.h"
#import "MetalUIView.h"
#import "Live2DMetalContext.h"

@interface LAppTextureManager()

@property (nonatomic) Csm::csmVector<TextureInfo*> textures;

@end

@implementation LAppTextureManager

- (id)init
{
    self = [super init];
    return self;
}

- (void)dealloc
{
    [self releaseTextures];
    [super dealloc];
}

- (TextureInfo*) createTextureFromPngFile:(std::string)fileName
{
    ViewController* viewController = Live2DMetalHostViewController();
    if (viewController == nil)
    {
        return NULL;
    }

    //search loaded texture already.
    for (Csm::csmUint32 i = 0; i < _textures.GetSize(); i++)
    {
        if (_textures[i]->fileName == fileName)
        {
            return _textures[i];
        }
    }

    Csm::csmInt32 textureId;
    int width = 0, height = 0, channels = 0;
    unsigned int size;
    unsigned char* png;
    unsigned char* address;

    address = LAppPal::LoadFileAsBytes(fileName, &size);
    if (address == NULL || size == 0) return NULL;

    // png情報を取得する
    png = stbi_load_from_memory(
                                address,
                                static_cast<int>(size),
                                &width,
                                &height,
                                &channels,
                                STBI_rgb_alpha);
    if (png == NULL || width <= 0 || height <= 0) {
        stbi_image_free(png);
        LAppPal::ReleaseBytes(address);
        return NULL;
    }

    {
#ifdef PREMULTIPLIED_ALPHA_ENABLE
        unsigned int* fourBytes = reinterpret_cast<unsigned int*>(png);
        for (int i = 0; i < width * height; i++)
        {
            unsigned char* p = png + i * 4;
            int tes = [self premultiply:p[0] Green:p[1] Blue:p[2] Alpha:p[3]];
            fourBytes[i] = tes;
        }
#endif
    }

    MTLTextureDescriptor *textureDescriptor = [[[MTLTextureDescriptor alloc] init] autorelease];

    // Indicate that each pixel has a blue, green, red, and alpha channel, where each channel is
    // an 8-bit unsigned normalized value (i.e. 0 maps to 0.0 and 255 maps to 1.0)
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;

    // Set the pixel dimensions of the texture
    textureDescriptor.width = width;
    textureDescriptor.height = height;
    textureDescriptor.storageMode = MTLStorageModeShared;

    int widthLevels = ceil(log2(width));
    int heightLevels = ceil(log2(height));
    int mipCount = (heightLevels > widthLevels) ? heightLevels : widthLevels;
    textureDescriptor.mipmapLevelCount = mipCount;

    id <MTLDevice> device = [viewController getDevice];

    // Create the texture from the device by using the descriptor
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    if (texture == nil) {
        stbi_image_free(png);
        LAppPal::ReleaseBytes(address);
        return NULL;
    }

    // Calculate the number of bytes per row in the image.
    NSUInteger bytesPerRow = 4 * width;

    MTLRegion region = {
        { 0, 0, 0 },                   // MTLOrigin
        {(NSUInteger)width, (NSUInteger)height, 1} // MTLSize
    };

    // Copy the bytes from the data object into the texture
    [texture replaceRegion:region
                mipmapLevel:0
                  withBytes:png
                bytesPerRow:bytesPerRow];

    id<MTLCommandBuffer> commandBuffer = [viewController.commandQueue commandBuffer];
    if (commandBuffer == nil)
    {
        stbi_image_free(png);
        LAppPal::ReleaseBytes(address);
        return nil;
    }
    id<MTLBlitCommandEncoder> blitCommandEncoder = [commandBuffer blitCommandEncoder];
    [blitCommandEncoder generateMipmapsForTexture:texture];
    [blitCommandEncoder endEncoding];
    [commandBuffer commit];

    // 解放処理
    stbi_image_free(png);
    LAppPal::ReleaseBytes(address);

    TextureInfo* textureInfo = new TextureInfo;
    textureInfo->fileName = fileName;
    textureInfo->width = width;
    textureInfo->height = height;
    textureInfo->id = texture;
    _textures.PushBack(textureInfo);

    return textureInfo;
}

- (id<MTLTexture>)loadTextureUsingMetalKit: (NSURL *) url device: (id<MTLDevice>) device {
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice: device];

    NSError *error;
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url options:nil error:&error];
    [loader release];

    if (!texture)
    {
        NSLog(@"Failed to create the texture from %@", url.absoluteString);
        return nil;
    }
    return texture;
}

- (unsigned int)premultiply:(unsigned char)red Green:(unsigned char)green Blue:(unsigned char)blue Alpha:(unsigned char) alpha
{
    return static_cast<unsigned>(\
                                 (red * (alpha + 1) >> 8) | \
                                 ((green * (alpha + 1) >> 8) << 8) | \
                                 ((blue * (alpha + 1) >> 8) << 16) | \
                                 (((alpha)) << 24)   \
                                 );
}
- (void)releaseTextures
{
    for (Csm::csmUint32 i = 0; i < _textures.GetSize(); i++)
    {
        [ _textures[i]->id release];
        delete _textures[i];
        _textures.Remove(i);
    }

    _textures.Clear();
}

- (void)releaseTextureWithId:(id <MTLTexture>) textureId
{
    for (Csm::csmUint32 i = 0; i < _textures.GetSize(); i++)
    {
        if (_textures[i]->id != textureId)
        {
            continue;
        }
        [ _textures[i]->id release];
        delete _textures[i];
        _textures.Remove(i);
        break;
    }
}

- (void)releaseTextureByName:(std::string)fileName;
{
    for (Csm::csmUint32 i = 0; i < _textures.GetSize(); i++)
    {
        if (_textures[i]->fileName == fileName)
        {
            [ _textures[i]->id release];
            delete _textures[i];
            _textures.Remove(i);
            break;
        }
    }
}

@end
