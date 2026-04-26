#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

namespace {

IMKServer* server = nil;

NSString* plistString(NSString* key)
{
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

} // namespace

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        NSString* connectionName = plistString(@"InputMethodConnectionName");
        NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

        NSCAssert(connectionName.length > 0, @"Missing InputMethodConnectionName in Info.plist");
        NSCAssert(bundleIdentifier.length > 0, @"Missing CFBundleIdentifier in Info.plist");

        server = [[IMKServer alloc] initWithName:connectionName bundleIdentifier:bundleIdentifier];
        NSCAssert(server != nil, @"Failed to create IMKServer");

        return NSApplicationMain(argc, argv);
    }
}
