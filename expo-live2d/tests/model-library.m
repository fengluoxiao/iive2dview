#import <Foundation/Foundation.h>
#import "Live2DModelLibrary.h"

static void require(BOOL condition, NSString* message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

int main(void) {
    @autoreleasepool {
        NSFileManager* fm = NSFileManager.defaultManager;
        NSURL* temporary = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        NSURL* root = [temporary URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        NSString* identifier = @"A123/祥子 夏服/角色 #1.model3.json";
        NSURL* file = [root URLByAppendingPathComponent:identifier];
        NSError* error = nil;
        require([fm createDirectoryAtURL:file.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:&error], error.description);
        NSDictionary* fixture = @{@"Version": @3, @"FileReferences": @{@"Moc": @"角色.moc3", @"Textures": @[@"texture.png"]}};
        [[NSJSONSerialization dataWithJSONObject:fixture options:0 error:nil] writeToURL:file atomically:YES];
        for (NSURL* base in @[root, [NSURL fileURLWithPath:[root.path stringByAppendingString:@"/"] isDirectory:YES]]) {
            NSString* actual = Live2DModelIdentifier(base, file);
            require([actual isEqual:identifier], [NSString stringWithFormat:@"Identifier truncated: %@", actual]);
            require([Live2DReadModelConfiguration([base URLByAppendingPathComponent:actual], &error) isEqual:fixture], @"Round-trip model read");
        }
        NSURL* alias = [temporary URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
        require([fm createSymbolicLinkAtURL:alias withDestinationURL:root error:&error], error.description);
        require([Live2DModelIdentifier(alias, file) isEqual:identifier], @"Symlink root alias");
        require(Live2DModelIdentifier(root, temporary) == nil, @"Reject files outside library");
        NSURL* missing = [root URLByAppendingPathComponent:@"missing.model3.json"];
        error = nil;
        require(Live2DReadModelConfiguration(missing, &error) == nil && error != nil, @"Missing file reports filesystem error");
        [@"{broken" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
        error = nil;
        require(Live2DReadModelConfiguration(file, &error) == nil && error != nil, @"Invalid JSON reports parsing error");
        [@"{}" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
        error = nil;
        require(Live2DReadModelConfiguration(file, &error) == nil && [error.domain isEqual:@"Live2DModelLibrary"], @"Missing schema reports configuration error");
        error = nil;
        NSArray* direct = Live2DScanModels(root, @"models/", NO, &error);
        require(direct.count == 1 && error == nil, @"Recursive models scan");
        require([direct[0][@"id"] isEqual:[@"models/" stringByAppendingString:identifier]], @"Stable document namespace");
        require([direct[0][@"character"] isEqual:@"A123"], @"Manual folder name is character");
        NSArray* old = Live2DScanModels(root, @"", YES, &error);
        require([old[0][@"id"] isEqual:identifier] && [old[0][@"character"] isEqual:@"祥子 夏服"], @"Legacy IDs and grouping preserved");
        NSURL* outside = [root URLByAppendingPathComponent:@"outside"];
        require([fm createSymbolicLinkAtURL:outside withDestinationURL:temporary error:&error], @"Create external link");
        NSArray* withLink = Live2DScanModels(root, @"models/", NO, &error);
        require(withLink.count == 1, [NSString stringWithFormat:@"Do not traverse external symlinks: %@", [withLink valueForKey:@"id"]]);
        NSURL* wrapper = [root URLByAppendingPathComponent:@"12345678-1234-1234-1234-123456789abc/sakiko/casual/test.MODEL3.JSON"];
        [fm createDirectoryAtURL:wrapper.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [@"{}" writeToURL:wrapper atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSArray* imported = Live2DScanModels(root, @"models/", NO, &error);
        require(imported.count == 2, @"Case insensitive model extension");
        for (NSDictionary* item in imported) if ([item[@"outfit"] isEqual:@"test"])
            require([item[@"character"] isEqual:@"sakiko"], @"Hide import UUID in character label");
        [fm removeItemAtURL:file error:nil];
        require(Live2DScanModels(root, @"models/", NO, &error).count == 1, @"Refresh reflects removal");
        [fm removeItemAtURL:alias error:nil];
        [fm removeItemAtURL:root error:nil];
        NSLog(@"PASS: model library path round-trip, Unicode, aliases, and error diagnostics");
    }
    return 0;
}
