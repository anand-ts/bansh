#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

static NSString* StringProperty(TISInputSourceRef source, CFStringRef key)
{
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    if (value == NULL) {
        return @"";
    }

    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        return (__bridge NSString*)value;
    }

    return [(__bridge id)value description];
}

static BOOL BoolProperty(TISInputSourceRef source, CFStringRef key)
{
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    return value != NULL &&
           CFGetTypeID(value) == CFBooleanGetTypeID() &&
           CFBooleanGetValue((CFBooleanRef)value);
}

static NSArray* SourceListMatching(CFStringRef key, NSString* value)
{
    NSDictionary* filter = @{(__bridge NSString*)key : value};
    return CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true));
}

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        if (argc < 5) {
            fprintf(stderr, "usage: register-input-source <app-path> <bundle-id> <source-id> <mode-id>\n");
            return 2;
        }

        NSString* path = [NSString stringWithUTF8String:argv[1]];
        NSString* bundleID = [NSString stringWithUTF8String:argv[2]];
        NSString* sourceID = [NSString stringWithUTF8String:argv[3]];
        NSString* modeID = [NSString stringWithUTF8String:argv[4]];
        NSURL* url = [NSURL fileURLWithPath:path];
        OSStatus status = TISRegisterInputSource((__bridge CFURLRef)url);
        if (status != noErr) {
            fprintf(stderr, "TISRegisterInputSource failed with status %d.\n", (int)status);
            return 1;
        }

        NSMutableOrderedSet* matches = [NSMutableOrderedSet orderedSet];
        for (id source in SourceListMatching(kTISPropertyBundleID, bundleID)) {
            [matches addObject:source];
        }
        for (id source in SourceListMatching(kTISPropertyInputSourceID, sourceID)) {
            [matches addObject:source];
        }
        if (modeID.length > 0) {
            for (id source in SourceListMatching(kTISPropertyInputSourceID, modeID)) {
                [matches addObject:source];
            }
        }

        if (matches.count == 0) {
            fprintf(stderr, "Registered the bundle, but no installed input sources matched %s, %s, or %s.\n",
                    bundleID.UTF8String,
                    sourceID.UTF8String,
                    modeID.UTF8String);
            return 1;
        }

        BOOL enabledAny = NO;
        for (id object in matches) {
            TISInputSourceRef source = (__bridge TISInputSourceRef)object;
            NSString* currentSourceID = StringProperty(source, kTISPropertyInputSourceID);
            BOOL enableCapable = BoolProperty(source, kTISPropertyInputSourceIsEnableCapable);
            BOOL enabled = BoolProperty(source, kTISPropertyInputSourceIsEnabled);

            printf("Discovered input source: %s\n", currentSourceID.UTF8String);

            if (enabled) {
                enabledAny = YES;
                continue;
            }

            if (enableCapable && !enabled) {
                OSStatus enableStatus = TISEnableInputSource(source);
                printf("Enable status for %s: %d\n", currentSourceID.UTF8String, (int)enableStatus);
                if (enableStatus == noErr) {
                    enabledAny = YES;
                } else {
                    fprintf(stderr, "Failed to enable input source %s with status %d.\n",
                            currentSourceID.UTF8String,
                            (int)enableStatus);
                }
            } else {
                fprintf(stderr, "Input source %s is not enable-capable and is not enabled.\n",
                        currentSourceID.UTF8String);
            }
        }

        if (!enabledAny) {
            fprintf(stderr, "Bansh was registered, but no matching input source is enabled.\n");
            return 1;
        }

        return 0;
    }
}
