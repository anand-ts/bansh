#import "BanshMappingCatalog.h"

@interface BanshMappingExample ()
@property(nonatomic, copy, readwrite) NSString* input;
@property(nonatomic, copy, readwrite) NSString* output;
@end

@implementation BanshMappingExample

- (instancetype)initWithInput:(NSString*)input output:(NSString*)output
{
    self = [super init];
    if (self != nil) {
        _input = [input copy];
        _output = [output copy];
    }
    return self;
}

@end


@interface BanshMappingItem ()
@property(nonatomic, copy, readwrite) NSString* input;
@property(nonatomic, copy, readwrite) NSString* displayOutput;
@property(nonatomic, copy, readwrite) NSArray<BanshMappingExample*>* validationExamples;
@end

@implementation BanshMappingItem

- (instancetype)initWithInput:(NSString*)input
                displayOutput:(NSString*)displayOutput
           validationExamples:(NSArray<BanshMappingExample*>*)validationExamples
{
    self = [super init];
    if (self != nil) {
        _input = [input copy];
        _displayOutput = [displayOutput copy];
        _validationExamples = [validationExamples copy];
    }
    return self;
}

@end


@interface BanshMappingSection ()
@property(nonatomic, copy, readwrite) NSString* title;
@property(nonatomic, copy, readwrite) NSArray<BanshMappingItem*>* items;
@end

@implementation BanshMappingSection

- (instancetype)initWithTitle:(NSString*)title items:(NSArray<BanshMappingItem*>*)items
{
    self = [super init];
    if (self != nil) {
        _title = [title copy];
        _items = [items copy];
    }
    return self;
}

@end


namespace {

BanshMappingExample* Example(NSString* input, NSString* output)
{
    return [[BanshMappingExample alloc] initWithInput:input output:output];
}

BanshMappingItem* Mapping(NSString* input, NSString* output)
{
    return [[BanshMappingItem alloc] initWithInput:input
                                     displayOutput:output
                                validationExamples:@[ Example(input, output) ]];
}

BanshMappingItem* ContextualMapping(
    NSString* input,
    NSString* displayOutput,
    NSArray<BanshMappingExample*>* examples)
{
    return [[BanshMappingItem alloc] initWithInput:input
                                     displayOutput:displayOutput
                                validationExamples:examples];
}

BanshMappingSection* Section(NSString* title, NSArray<BanshMappingItem*>* items)
{
    return [[BanshMappingSection alloc] initWithTitle:title items:items];
}

} // namespace

NSArray<BanshMappingSection*>* BanshMappingCatalog(void)
{
    static NSArray<BanshMappingSection*>* catalog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        catalog = @[
            Section(@"Letters and common sequences", @[
                Mapping(@"a", @"а"), Mapping(@"ai", @"ай"),
                Mapping(@"b", @"б"), Mapping(@"c", @"ц"), Mapping(@"ch", @"ч"),
                Mapping(@"d", @"д"), Mapping(@"e", @"э"), Mapping(@"ei", @"эй"),
                Mapping(@"f", @"ф"), Mapping(@"g", @"г"), Mapping(@"h", @"х"),
                Mapping(@"i", @"и"), Mapping(@"ii", @"ий"), Mapping(@"iii", @"ы"),
                Mapping(@"j", @"ж"), Mapping(@"k", @"к"), Mapping(@"kh", @"х"),
                Mapping(@"l", @"л"), Mapping(@"m", @"м"), Mapping(@"n", @"н"),
                Mapping(@"p", @"п"), Mapping(@"q", @"ө"), Mapping(@"qi", @"өй"),
                Mapping(@"r", @"р"), Mapping(@"s", @"с"), Mapping(@"sh", @"ш"),
                Mapping(@"sxc", @"щ"), Mapping(@"t", @"т"), Mapping(@"v", @"в"),
                Mapping(@"w", @"ү"), Mapping(@"wi", @"үй"), Mapping(@"x", @"х"),
                Mapping(@"y", @"ы"), Mapping(@"ya", @"я"), Mapping(@"ye", @"е"),
                Mapping(@"yo", @"ё"), Mapping(@"yu", @"ю"), Mapping(@"z", @"з"),
            ]),
            Section(@"Vowel harmony", @[
                ContextualMapping(@"o", @"о / ө", @[
                    Example(@"o", @"о"),
                    Example(@"eo", @"эө"),
                ]),
                ContextualMapping(@"oi", @"ой / өй", @[
                    Example(@"oi", @"ой"),
                    Example(@"eoi", @"эөй"),
                ]),
                ContextualMapping(@"u", @"у / ү", @[
                    Example(@"u", @"у"),
                    Example(@"eu", @"эү"),
                ]),
                ContextualMapping(@"ui", @"уй / үй", @[
                    Example(@"ui", @"уй"),
                    Example(@"eui", @"эүй"),
                ]),
            ]),
            Section(@"Forced vowels", @[
                Mapping(@"o\"", @"о"), Mapping(@"o\"i", @"ой"),
                Mapping(@"\"o", @"о"), Mapping(@"\"oi", @"ой"),
                Mapping(@"o'", @"ө"), Mapping(@"o'i", @"өй"),
                Mapping(@"'o", @"ө"), Mapping(@"'oi", @"өй"),
                Mapping(@"u\"", @"у"), Mapping(@"u\"i", @"уй"),
                Mapping(@"\"u", @"у"), Mapping(@"\"ui", @"уй"),
                Mapping(@"u'", @"ү"), Mapping(@"u'i", @"үй"),
                Mapping(@"'u", @"ү"), Mapping(@"'ui", @"үй"),
            ]),
            Section(@"Quotes and signs", @[
                Mapping(@"\"", @"ъ"), Mapping(@"\"\"", @"Ъ"),
                Mapping(@"'", @"ь"), Mapping(@"''", @"Ь"),
            ]),
        ];
    });
    return catalog;
}

NSString* BanshMappingLabel(BanshMappingItem* item)
{
    return [NSString stringWithFormat:@"%@  →  %@", item.input, item.displayOutput];
}
