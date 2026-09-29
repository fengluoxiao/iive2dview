#import <Foundation/Foundation.h>

// Use path components: directory URLs, /private aliases, and Unicode names
// must not change the relative identifier or trim its first character.
FOUNDATION_EXPORT NSString* Live2DModelIdentifier(NSURL* root, NSURL* file);
FOUNDATION_EXPORT NSDictionary* Live2DReadModelConfiguration(NSURL* file, NSError** error);
