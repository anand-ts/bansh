#import "BanshUpdateChecker.h"

#import <Cocoa/Cocoa.h>

namespace {

constexpr NSTimeInterval kCheckInterval = 24.0 * 60.0 * 60.0;
constexpr NSTimeInterval kRemindLaterInterval = 7.0 * 24.0 * 60.0 * 60.0;
constexpr NSTimeInterval kDownloadReminderInterval = 24.0 * 60.0 * 60.0;

NSString* const kLatestReleaseAPIURL = @"https://api.github.com/repos/anand-ts/bansh/releases/latest";
NSString* const kFallbackDownloadURL =
    @"https://github.com/anand-ts/bansh/releases/latest/download/Bansh-direct-download.zip";
NSString* const kLastCheckDefaultsKey = @"BanshUpdateLastCheckDate";
NSString* const kSnoozeUntilDefaultsKey = @"BanshUpdateSnoozeUntilDate";
NSString* const kReleaseAssetName = @"Bansh-direct-download.zip";

NSArray<NSNumber*>* _Nullable BanshVersionComponents(NSString* version)
{
    NSString* normalized = [version stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([normalized hasPrefix:@"v"] || [normalized hasPrefix:@"V"]) {
        normalized = [normalized substringFromIndex:1];
    }

    normalized = [normalized componentsSeparatedByString:@"-"][0];
    if (normalized.length == 0) {
        return nil;
    }

    NSMutableArray<NSNumber*>* components = [NSMutableArray array];
    for (NSString* component in [normalized componentsSeparatedByString:@"."]) {
        if (component.length == 0) {
            return nil;
        }

        NSScanner* scanner = [NSScanner scannerWithString:component];
        NSInteger value = 0;
        if (![scanner scanInteger:&value] || !scanner.isAtEnd || value < 0) {
            return nil;
        }
        [components addObject:@(value)];
    }
    return components;
}

NSString* BanshDisplayVersion(NSString* version)
{
    NSString* normalized = [version stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([normalized hasPrefix:@"v"] || [normalized hasPrefix:@"V"]) {
        normalized = [normalized substringFromIndex:1];
    }
    return normalized;
}

NSURL* _Nullable BanshHTTPSURL(NSString* value)
{
    if (![value isKindOfClass:NSString.class]) {
        return nil;
    }

    NSURL* url = [NSURL URLWithString:value];
    return [url.scheme.lowercaseString isEqualToString:@"https"] ? url : nil;
}

NSDate* _Nullable BanshDefaultsDate(NSUserDefaults* defaults, NSString* key)
{
    id value = [defaults objectForKey:key];
    return [value isKindOfClass:NSDate.class] ? value : nil;
}

} // namespace

BOOL BanshVersionIsNewer(NSString* candidateVersion, NSString* currentVersion)
{
    NSArray<NSNumber*>* candidate = BanshVersionComponents(candidateVersion);
    NSArray<NSNumber*>* current = BanshVersionComponents(currentVersion);
    if (candidate == nil || current == nil) {
        return NO;
    }

    const NSUInteger componentCount = MAX(candidate.count, current.count);
    for (NSUInteger index = 0; index < componentCount; ++index) {
        const NSInteger candidateValue = index < candidate.count ? candidate[index].integerValue : 0;
        const NSInteger currentValue = index < current.count ? current[index].integerValue : 0;
        if (candidateValue != currentValue) {
            return candidateValue > currentValue;
        }
    }
    return NO;
}

BOOL BanshShouldCheckForUpdates(NSDate* now, NSDate* lastCheckDate, NSDate* snoozeUntilDate)
{
    if (snoozeUntilDate != nil && [now compare:snoozeUntilDate] == NSOrderedAscending) {
        return NO;
    }
    if (lastCheckDate != nil && [lastCheckDate compare:now] != NSOrderedDescending) {
        if ([now timeIntervalSinceDate:lastCheckDate] < kCheckInterval) {
            return NO;
        }
    }
    return YES;
}

@interface BanshUpdateChecker () <NSWindowDelegate>

@property(nonatomic) BOOL requestInFlight;
@property(nonatomic, strong, nullable) NSPanel* updatePanel;
@property(nonatomic, strong, nullable) NSURL* downloadURL;

- (void)beginCheckIfNeeded;
- (void)downloadUpdate:(id)sender;
- (void)finishCheckWithRelease:(NSDictionary*)release currentVersion:(NSString*)currentVersion;
- (void)presentUpdateForVersion:(NSString*)version downloadURL:(NSURL*)downloadURL;
- (void)remindLater:(id)sender;
- (void)snoozeForInterval:(NSTimeInterval)interval;

@end

@implementation BanshUpdateChecker

+ (instancetype)sharedChecker
{
    static BanshUpdateChecker* checker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checker = [BanshUpdateChecker new];
    });
    return checker;
}

- (void)checkForUpdatesIfNeeded
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self beginCheckIfNeeded];
    });
}

- (void)beginCheckIfNeeded
{
    if (self.requestInFlight || self.updatePanel != nil) {
        return;
    }

    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    NSDate* now = [NSDate date];
    if (!BanshShouldCheckForUpdates(
            now,
            BanshDefaultsDate(defaults, kLastCheckDefaultsKey),
            BanshDefaultsDate(defaults, kSnoozeUntilDefaultsKey))) {
        return;
    }

    id currentVersionValue = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString* currentVersion = [currentVersionValue isKindOfClass:NSString.class] ? currentVersionValue : nil;
    if (BanshVersionComponents(currentVersion).count == 0) {
        return;
    }

    NSURL* endpoint = [NSURL URLWithString:kLatestReleaseAPIURL];
    if (endpoint == nil) {
        return;
    }

    self.requestInFlight = YES;
    [defaults setObject:now forKey:kLastCheckDefaultsKey];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:endpoint];
    request.timeoutInterval = 15.0;
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"2022-11-28" forHTTPHeaderField:@"X-GitHub-Api-Version"];
    [request setValue:[NSString stringWithFormat:@"BanshInputMethod/%@", currentVersion]
        forHTTPHeaderField:@"User-Agent"];

    NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
    NSURLSessionDataTask* task = [session dataTaskWithRequest:request
                                           completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        NSDictionary* release = nil;
        if (error == nil &&
            [response isKindOfClass:NSHTTPURLResponse.class] &&
            [(NSHTTPURLResponse*)response statusCode] == 200 &&
            data.length > 0) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:NSDictionary.class]) {
                release = json;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.requestInFlight = NO;
            if (release != nil) {
                [self finishCheckWithRelease:release currentVersion:currentVersion];
            }
        });
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

- (void)finishCheckWithRelease:(NSDictionary*)release currentVersion:(NSString*)currentVersion
{
    NSString* tagName = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : nil;
    if (tagName == nil || !BanshVersionIsNewer(tagName, currentVersion)) {
        return;
    }

    NSURL* downloadURL = nil;
    NSArray* assets = [release[@"assets"] isKindOfClass:NSArray.class] ? release[@"assets"] : @[];
    for (id value in assets) {
        if (![value isKindOfClass:NSDictionary.class]) {
            continue;
        }
        NSDictionary* asset = value;
        if ([asset[@"name"] isEqual:kReleaseAssetName]) {
            downloadURL = BanshHTTPSURL(asset[@"browser_download_url"]);
            break;
        }
    }

    if (downloadURL == nil) {
        downloadURL = [NSURL URLWithString:kFallbackDownloadURL];
    }
    if (downloadURL != nil) {
        [self presentUpdateForVersion:BanshDisplayVersion(tagName) downloadURL:downloadURL];
    }
}

- (void)presentUpdateForVersion:(NSString*)version downloadURL:(NSURL*)downloadURL
{
    if (self.updatePanel != nil) {
        return;
    }

    self.downloadURL = downloadURL;

    const NSRect panelRect = NSMakeRect(0.0, 0.0, 480.0, 200.0);
    NSPanel* panel = [[NSPanel alloc]
        initWithContentRect:panelRect
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskNonactivatingPanel
                    backing:NSBackingStoreBuffered
                      defer:NO];
    panel.title = @"Bansh Update";
    panel.delegate = self;
    panel.floatingPanel = YES;
    panel.hidesOnDeactivate = NO;
    panel.becomesKeyOnlyIfNeeded = YES;
    panel.movableByWindowBackground = YES;
    panel.releasedWhenClosed = NO;
    panel.level = NSFloatingWindowLevel;
    panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary;

    NSView* contentView = panel.contentView;

    NSImageView* iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(24.0, 94.0, 72.0, 72.0)];
    iconView.image = NSApplication.sharedApplication.applicationIconImage;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [contentView addSubview:iconView];

    NSTextField* titleLabel = [NSTextField labelWithString:@"A new Bansh version is available"];
    titleLabel.frame = NSMakeRect(116.0, 139.0, 340.0, 26.0);
    titleLabel.font = [NSFont systemFontOfSize:17.0 weight:NSFontWeightSemibold];
    [contentView addSubview:titleLabel];

    NSString* message = [NSString stringWithFormat:
        @"Bansh %@ is ready. Download it now, then open Install Bansh.command to update.", version];
    NSTextField* messageLabel = [NSTextField wrappingLabelWithString:message];
    messageLabel.frame = NSMakeRect(116.0, 83.0, 340.0, 50.0);
    messageLabel.font = [NSFont systemFontOfSize:13.0];
    [contentView addSubview:messageLabel];

    NSButton* downloadButton = [NSButton buttonWithTitle:@"Download Update"
                                                  target:self
                                                  action:@selector(downloadUpdate:)];
    downloadButton.frame = NSMakeRect(312.0, 24.0, 144.0, 32.0);
    downloadButton.bezelStyle = NSBezelStyleRounded;
    downloadButton.keyEquivalent = @"\r";
    [contentView addSubview:downloadButton];

    NSButton* remindButton = [NSButton buttonWithTitle:@"Remind Me Later"
                                                target:self
                                                action:@selector(remindLater:)];
    remindButton.frame = NSMakeRect(166.0, 24.0, 138.0, 32.0);
    remindButton.bezelStyle = NSBezelStyleRounded;
    [contentView addSubview:remindButton];

    NSScreen* screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (screen != nil) {
        NSRect visibleFrame = screen.visibleFrame;
        NSPoint origin = NSMakePoint(
            NSMaxX(visibleFrame) - NSWidth(panelRect) - 24.0,
            NSMaxY(visibleFrame) - NSHeight(panelRect) - 24.0);
        [panel setFrameOrigin:origin];
    } else {
        [panel center];
    }

    self.updatePanel = panel;
    [panel orderFrontRegardless];
}

- (void)downloadUpdate:(id)sender
{
    NSURL* downloadURL = self.downloadURL;
    [self snoozeForInterval:kDownloadReminderInterval];
    [self.updatePanel orderOut:nil];
    self.updatePanel = nil;
    self.downloadURL = nil;

    if (downloadURL != nil) {
        [NSWorkspace.sharedWorkspace openURL:downloadURL];
    }
}

- (void)remindLater:(id)sender
{
    [self snoozeForInterval:kRemindLaterInterval];
    [self.updatePanel orderOut:nil];
    self.updatePanel = nil;
    self.downloadURL = nil;
}

- (void)snoozeForInterval:(NSTimeInterval)interval
{
    NSDate* snoozeUntil = [NSDate dateWithTimeIntervalSinceNow:interval];
    [NSUserDefaults.standardUserDefaults setObject:snoozeUntil forKey:kSnoozeUntilDefaultsKey];
}

- (BOOL)windowShouldClose:(NSWindow*)sender
{
    if (sender == self.updatePanel) {
        [self snoozeForInterval:kRemindLaterInterval];
        self.updatePanel = nil;
        self.downloadURL = nil;
    }
    return YES;
}

@end
