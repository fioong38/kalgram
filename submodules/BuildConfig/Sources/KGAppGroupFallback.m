#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// kalgram: sideload support.
//
// A sideloaded build is re-signed (ESign etc) with a certificate whose
// provisioning profile has no app group for our bundle id, so
// -containerURLForSecurityApplicationGroupIdentifier: returns nil and the app
// stops at launch ("Error 2" on a window that is not visible yet: a black
// screen). When the system has no container, hand out a directory inside the
// process's own Library instead. The main app keeps all of its data there;
// extensions get their own (empty) directory and find no accounts, which is
// what they would see without a container anyway.

static IMP kgOriginalContainerURL = NULL;

static NSURL *kgContainerURL(id self, SEL _cmd, NSString *groupIdentifier) {
    NSURL *url = ((NSURL *(*)(id, SEL, NSString *))kgOriginalContainerURL)(self, _cmd, groupIdentifier);
    if (url != nil || groupIdentifier.length == 0) {
        return url;
    }
    NSURL *library = [[(NSFileManager *)self URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] firstObject];
    if (library == nil) {
        return nil;
    }
    NSURL *fallback = [[library URLByAppendingPathComponent:@"KalgramAppGroup" isDirectory:true] URLByAppendingPathComponent:groupIdentifier isDirectory:true];
    [(NSFileManager *)self createDirectoryAtURL:fallback withIntermediateDirectories:true attributes:nil error:nil];
    return fallback;
}

@interface KGAppGroupFallback : NSObject
@end

@implementation KGAppGroupFallback

+ (void)load {
    Method method = class_getInstanceMethod([NSFileManager class], @selector(containerURLForSecurityApplicationGroupIdentifier:));
    if (method != NULL) {
        kgOriginalContainerURL = method_setImplementation(method, (IMP)kgContainerURL);
    }
}

@end
