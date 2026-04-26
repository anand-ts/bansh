#import "BanshAppDelegate.h"

#import <InputMethodKit/InputMethodKit.h>

namespace {

NSString* plistString(NSString* key)
{
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

} // namespace

@interface BanshAppDelegate ()

@property(nonatomic, strong) IMKServer* server;

@end

@implementation BanshAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
    NSString* connectionName = plistString(@"InputMethodConnectionName");
    NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];

    NSCAssert(connectionName.length > 0, @"Missing InputMethodConnectionName in Info.plist");
    NSCAssert(bundleIdentifier.length > 0, @"Missing CFBundleIdentifier in Info.plist");

    self.server = [[IMKServer alloc] initWithName:connectionName bundleIdentifier:bundleIdentifier];
    NSCAssert(self.server != nil, @"Failed to create IMKServer");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return NO;
}

@end
