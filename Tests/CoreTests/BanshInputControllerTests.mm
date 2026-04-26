#import <XCTest/XCTest.h>

#import "BanshInputController.h"

@interface BanshFakeTextClient : NSObject <IMKTextInput>
@property(nonatomic, strong) NSMutableString* text;
@property(nonatomic) NSRange selectedRangeValue;
@property(nonatomic) NSRange markedRangeValue;
@end

@implementation BanshFakeTextClient

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _text = [NSMutableString string];
        _selectedRangeValue = NSMakeRange(0, 0);
        _markedRangeValue = NSMakeRange(NSNotFound, NSNotFound);
    }
    return self;
}

static NSString* BanshPlainString(id string)
{
    if ([string isKindOfClass:[NSAttributedString class]]) {
        return [(NSAttributedString*)string string];
    }
    return string ?: @"";
}

- (NSRange)clampedRange:(NSRange)range
{
    if (range.location == NSNotFound) {
        return _selectedRangeValue.location == NSNotFound ? NSMakeRange(_text.length, 0) : _selectedRangeValue;
    }

    const NSUInteger location = MIN(range.location, _text.length);
    const NSUInteger length = MIN(range.length, _text.length - location);
    return NSMakeRange(location, length);
}

- (BOOL)hasMarkedText
{
    return _markedRangeValue.location != NSNotFound;
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange
{
    NSString* plainText = BanshPlainString(string);
    NSRange targetRange = NSMakeRange(NSNotFound, NSNotFound);
    BOOL shouldClearMarkedRange = NO;

    if (replacementRange.location != NSNotFound) {
        targetRange = [self clampedRange:replacementRange];
        shouldClearMarkedRange = [self hasMarkedText];
    } else if ([self hasMarkedText] && _markedRangeValue.length > 0) {
        targetRange = [self clampedRange:_markedRangeValue];
        shouldClearMarkedRange = YES;
    } else {
        targetRange = [self clampedRange:_selectedRangeValue];
    }

    [_text replaceCharactersInRange:targetRange withString:plainText];
    _selectedRangeValue = NSMakeRange(targetRange.location + plainText.length, 0);

    if (shouldClearMarkedRange) {
        _markedRangeValue = NSMakeRange(NSNotFound, NSNotFound);
    }
}

- (void)setMarkedText:(id)string selectionRange:(NSRange)selectionRange replacementRange:(NSRange)replacementRange
{
    NSString* plainText = BanshPlainString(string);
    const NSRange targetRange = [self clampedRange:replacementRange];

    [_text replaceCharactersInRange:targetRange withString:plainText];
    _markedRangeValue = NSMakeRange(targetRange.location, plainText.length);
    _selectedRangeValue = NSMakeRange(targetRange.location + selectionRange.location, selectionRange.length);
}

- (NSRange)selectedRange
{
    return _selectedRangeValue;
}

- (NSRange)markedRange
{
    return _markedRangeValue;
}

- (NSAttributedString*)attributedSubstringFromRange:(NSRange)range
{
    return [[NSAttributedString alloc] initWithString:[_text substringWithRange:[self clampedRange:range]]];
}

- (NSInteger)length
{
    return static_cast<NSInteger>(_text.length);
}

- (NSInteger)characterIndexForPoint:(NSPoint)point
                           tracking:(IMKLocationToOffsetMappingMode)mappingMode
                      inMarkedRange:(BOOL*)inMarkedRange
{
    if (inMarkedRange != nullptr) {
        *inMarkedRange = NO;
    }
    return NSNotFound;
}

- (NSDictionary*)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRect*)lineRect
{
    if (lineRect != nullptr) {
        *lineRect = NSZeroRect;
    }
    return @{};
}

- (NSArray*)validAttributesForMarkedText
{
    return @[];
}

- (void)overrideKeyboardWithKeyboardNamed:(NSString*)keyboardUniqueName
{
}

- (void)selectInputMode:(NSString*)modeIdentifier
{
}

- (BOOL)supportsUnicode
{
    return YES;
}

- (NSString*)bundleIdentifier
{
    return @"com.bansh.tests.fake-client";
}

- (CGWindowLevel)windowLevel
{
    return kCGNormalWindowLevel;
}

- (BOOL)supportsProperty:(TSMDocumentPropertyTag)property
{
    return YES;
}

- (NSString*)uniqueClientIdentifierString
{
    return @"bansh-fake-client";
}

- (NSString*)stringFromRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    NSRange clampedRange = [self clampedRange:range];
    if (actualRange != nullptr) {
        *actualRange = clampedRange;
    }
    return [_text substringWithRange:clampedRange];
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange
{
    if (actualRange != nullptr) {
        *actualRange = [self clampedRange:range];
    }
    return NSZeroRect;
}

@end

@interface BanshInputControllerTests : XCTestCase
@end

@implementation BanshInputControllerTests

- (void)typeASCII:(NSString*)text controller:(BanshInputController*)controller client:(BanshFakeTextClient*)client
{
    for (NSUInteger i = 0; i < text.length; ++i) {
        NSString* character = [text substringWithRange:NSMakeRange(i, 1)];
        XCTAssertTrue([controller inputText:character key:0 modifiers:0 client:client],
                      @"Expected Bansh to handle %@", character);
    }
}

- (void)testPunctuationCommitDoesNotLeaveEmptyMarkedRange
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];

    [self typeASCII:@"sain" controller:controller client:client];
    XCTAssertNotEqual([client markedRange].location, NSNotFound);

    const BOOL handled = [controller inputText:@"?" key:0 modifiers:0 client:client];

    XCTAssertFalse(handled);
    XCTAssertEqualObjects(client.text, @"сайн");
    XCTAssertEqual([client selectedRange].location, client.text.length);
    XCTAssertEqual([client markedRange].location, NSNotFound);
}

- (void)testNewCompositionAfterPunctuationAndBlankLinesStartsAtCurrentCursor
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];

    [self typeASCII:@"sain" controller:controller client:client];

    if (![controller inputText:@"?" key:0 modifiers:0 client:client]) {
        [client insertText:@"?" replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    [client insertText:@"\n" replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [client insertText:@"\n" replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self typeASCII:@"bansh" controller:controller client:client];
    XCTAssertTrue([controller inputText:@" " key:0 modifiers:0 client:client]);
    [self typeASCII:@"id'ye" controller:controller client:client];

    XCTAssertEqualObjects(client.text, @"сайн?\n\nбанш идье");
    XCTAssertEqual([client markedRange].location, [@"сайн?\n\nбанш " length]);
}

@end
