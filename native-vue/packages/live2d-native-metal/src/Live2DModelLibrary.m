#import "Live2DModelLibrary.h"

NSArray<NSDictionary*>* Live2DScanModels(NSURL* root, NSString* prefix, BOOL legacy, NSError** error)
{
    NSMutableArray* result = [NSMutableArray array];
    NSFileManager* fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:root.path]) return result;
    NSMutableArray* failures = [NSMutableArray array];
    NSDirectoryEnumerator* files = [fm enumeratorAtURL:root
        includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:^BOOL(NSURL* url, NSError* failure) {
            if (!failures.count) [failures addObject:failure];
            return YES;
        }];
    for (NSURL* url in files) {
        NSNumber* link = nil; [url getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:nil];
        // NSDirectoryEnumerator does not descend into symbolic links. Calling
        // skipDescendants on a non-directory can skip unrelated pending entries.
        if (link.boolValue) continue;
        if (![url.lastPathComponent.lowercaseString hasSuffix:@".model3.json"]) continue;
        NSNumber* regular = nil; [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        NSString* relative = Live2DModelIdentifier(root, url);
        if (!regular.boolValue || !relative) continue;
        NSArray* parts = relative.pathComponents;
        NSString* outfit = [url.lastPathComponent substringToIndex:url.lastPathComponent.length - 12];
        // Imported archives have a UUID wrapper; manually placed folders do not.
        BOOL wrapped = legacy || (parts.count > 1 && [parts[0] rangeOfString:@"^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"
            options:NSRegularExpressionSearch].location != NSNotFound);
        NSUInteger index = wrapped ? 1 : 0;
        NSString* character = parts.count > index + 1 ? parts[index] : outfit;
        [result addObject:@{@"id": [prefix stringByAppendingString:relative], @"character": character,
                            @"outfit": outfit, @"url": url}];
    }
    if (error && failures.count) *error = failures.firstObject;
    return result;
}

NSString* Live2DModelIdentifier(NSURL* root, NSURL* file)
{
    NSArray* base = root.URLByResolvingSymlinksInPath.URLByStandardizingPath.pathComponents;
    NSArray* parts = file.URLByResolvingSymlinksInPath.URLByStandardizingPath.pathComponents;
    if (parts.count <= base.count) return nil;
    for (NSUInteger i = 0; i < base.count; ++i)
        if (![base[i] isEqual:parts[i]]) return nil;
    return [NSString pathWithComponents:[parts subarrayWithRange:NSMakeRange(base.count, parts.count - base.count)]];
}

NSDictionary* Live2DReadModelConfiguration(NSURL* file, NSError** error)
{
    NSData* data = [NSData dataWithContentsOfURL:file options:0 error:error];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!json) return nil;
    if (![json isKindOfClass:NSDictionary.class] || ![json[@"FileReferences"] isKindOfClass:NSDictionary.class]) {
        if (error) *error = [NSError errorWithDomain:@"Live2DModelLibrary" code:1 userInfo:
            @{NSLocalizedDescriptionKey: @"配置缺少 FileReferences，需使用 Cubism model3.json"}];
        return nil;
    }
    return json;
}
