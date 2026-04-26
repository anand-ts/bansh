#import <Cocoa/Cocoa.h>

#import "BanshAppDelegate.h"

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        NSApplication* application = [NSApplication sharedApplication];
        BanshAppDelegate* delegate = [[BanshAppDelegate alloc] init];
        [application setDelegate:delegate];
        return NSApplicationMain(argc, argv);
    }
}
