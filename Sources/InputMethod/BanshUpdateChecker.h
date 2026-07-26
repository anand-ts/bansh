#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT BOOL BanshVersionIsNewer(NSString* candidateVersion, NSString* currentVersion);
FOUNDATION_EXPORT BOOL BanshShouldCheckForUpdates(
    NSDate* now,
    NSDate* _Nullable lastCheckDate,
    NSDate* _Nullable snoozeUntilDate);

@interface BanshUpdateChecker : NSObject

+ (instancetype)sharedChecker;
- (void)checkForUpdatesIfNeeded;

@end

NS_ASSUME_NONNULL_END
