#import "Live2DModelLibrary.h"

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
