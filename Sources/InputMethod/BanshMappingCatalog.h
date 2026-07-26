#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BanshMappingExample : NSObject

@property(nonatomic, copy, readonly) NSString* input;
@property(nonatomic, copy, readonly) NSString* output;

- (instancetype)initWithInput:(NSString*)input output:(NSString*)output;

@end

@interface BanshMappingItem : NSObject

@property(nonatomic, copy, readonly) NSString* input;
@property(nonatomic, copy, readonly) NSString* displayOutput;
@property(nonatomic, copy, readonly) NSArray<BanshMappingExample*>* validationExamples;

- (instancetype)initWithInput:(NSString*)input
                displayOutput:(NSString*)displayOutput
           validationExamples:(NSArray<BanshMappingExample*>*)validationExamples;

@end


@interface BanshMappingSection : NSObject

@property(nonatomic, copy, readonly) NSString* title;
@property(nonatomic, copy, readonly) NSArray<BanshMappingItem*>* items;

- (instancetype)initWithTitle:(NSString*)title items:(NSArray<BanshMappingItem*>*)items;

@end


FOUNDATION_EXPORT NSArray<BanshMappingSection*>* BanshMappingCatalog(void);
FOUNDATION_EXPORT NSString* BanshMappingLabel(BanshMappingItem* item);

NS_ASSUME_NONNULL_END
