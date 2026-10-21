#import <XCTest/XCTest.h>

#import <Carbon/Carbon.h>

#import "BanshInputController.h"
#import "BanshMappingCatalog.h"
#import "BanshUpdateChecker.h"

@interface BanshNativeTextView : NSTextView
- (void)setMarkedText:(id)string selectionRange:(NSRange)selectionRange replacementRange:(NSRange)replacementRange;
@end

@implementation BanshNativeTextView

- (void)setMarkedText:(id)string selectionRange:(NSRange)selectionRange replacementRange:(NSRange)replacementRange
{
    [super setMarkedText:string selectedRange:selectionRange replacementRange:replacementRange];
}

@end

@interface BanshFakeTextClient : NSObject <IMKTextInput>
@property(nonatomic, strong) NSMutableString* text;
@property(nonatomic) NSRange selectedRangeValue;
@property(nonatomic) NSRange markedRangeValue;
@property(nonatomic) NSRect characterRectValue;
@end

@implementation BanshFakeTextClient

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _text = [NSMutableString string];
        _selectedRangeValue = NSMakeRange(0, 0);
        _markedRangeValue = NSMakeRange(NSNotFound, NSNotFound);
        _characterRectValue = NSZeroRect;
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

static NSArray<NSString*>* BanshTextValuesInView(NSView* view)
{
    NSMutableArray<NSString*>* values = [NSMutableArray array];
    if ([view isKindOfClass:[NSTextField class]]) {
        [values addObject:[(NSTextField*)view stringValue]];
    }
    for (NSView* subview in view.subviews) {
        [values addObjectsFromArray:BanshTextValuesInView(subview)];
    }
    return values;
}

static NSScrollView* BanshFirstScrollViewInView(NSView* view)
{
    if ([view isKindOfClass:[NSScrollView class]]) {
        return (NSScrollView*)view;
    }
    for (NSView* subview in view.subviews) {
        NSScrollView* scrollView = BanshFirstScrollViewInView(subview);
        if (scrollView != nil) {
            return scrollView;
        }
    }
    return nil;
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
    return _characterRectValue;
}

@end

@interface BanshInputControllerTests : XCTestCase
@end

@interface BanshUpdateChecker (BanshTests)
- (void)finishCheckWithRelease:(NSDictionary*)release currentVersion:(NSString*)currentVersion;
- (void)remindLater:(id)sender;
@end

@interface BanshInputController (BanshTests)
- (NSRect)preferredCheatSheetFrameForClient:(id<IMKTextInput, NSObject>)client panelSize:(NSSize)panelSize;
@end

@implementation BanshInputControllerTests

- (void)testUpdateVersionComparison
{
    XCTAssertTrue(BanshVersionIsNewer(@"v0.1.3", @"0.1.2"));
    XCTAssertTrue(BanshVersionIsNewer(@"0.2.0", @"0.1.99"));
    XCTAssertTrue(BanshVersionIsNewer(@"1.0.10", @"1.0.9"));
    XCTAssertFalse(BanshVersionIsNewer(@"0.1.3", @"0.1.3"));
    XCTAssertFalse(BanshVersionIsNewer(@"0.1.2", @"0.1.3"));
    XCTAssertFalse(BanshVersionIsNewer(@"not-a-version", @"0.1.3"));
}

- (void)testUpdateCheckScheduleHonorsDailyLimitAndReminder
{
    NSDate* now = [NSDate dateWithTimeIntervalSinceReferenceDate:1'000'000.0];
    NSDate* twentyThreeHoursAgo = [now dateByAddingTimeInterval:-(23.0 * 60.0 * 60.0)];
    NSDate* twentyFiveHoursAgo = [now dateByAddingTimeInterval:-(25.0 * 60.0 * 60.0)];
    NSDate* futureReminder = [now dateByAddingTimeInterval:60.0];
    NSDate* expiredReminder = [now dateByAddingTimeInterval:-60.0];
    NSDate* futureLastCheck = [now dateByAddingTimeInterval:60.0];

    XCTAssertFalse(BanshShouldCheckForUpdates(now, twentyThreeHoursAgo, nil));
    XCTAssertTrue(BanshShouldCheckForUpdates(now, twentyFiveHoursAgo, nil));
    XCTAssertFalse(BanshShouldCheckForUpdates(now, twentyFiveHoursAgo, futureReminder));
    XCTAssertTrue(BanshShouldCheckForUpdates(now, twentyFiveHoursAgo, expiredReminder));
    XCTAssertTrue(BanshShouldCheckForUpdates(now, futureLastCheck, nil));
}

- (void)testUpdateReleaseCreatesANonactivatingPrompt
{
    BanshUpdateChecker* checker = [BanshUpdateChecker new];
    NSDictionary* release = @{
        @"tag_name" : @"v0.1.4",
        @"assets" : @[
            @{
                @"name" : @"Bansh-direct-download.zip",
                @"browser_download_url" : @"https://github.com/anand-ts/bansh/releases/download/v0.1.4/Bansh-direct-download.zip",
            },
        ],
    };

    [checker finishCheckWithRelease:release currentVersion:@"0.1.3"];

    NSPanel* panel = [checker valueForKey:@"updatePanel"];
    XCTAssertNotNil(panel);
    XCTAssertNotEqual(panel.styleMask & NSWindowStyleMaskNonactivatingPanel, 0U);

    NSMutableSet<NSString*>* buttonTitles = [NSMutableSet set];
    for (NSView* subview in panel.contentView.subviews) {
        if ([subview isKindOfClass:NSButton.class]) {
            [buttonTitles addObject:[(NSButton*)subview title]];
        }
    }
    XCTAssertTrue([buttonTitles containsObject:@"Download Update"]);
    XCTAssertTrue([buttonTitles containsObject:@"Remind Me Later"]);

    [checker remindLater:nil];
    XCTAssertNil([checker valueForKey:@"updatePanel"]);
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"BanshUpdateSnoozeUntilDate"];
}

- (void)typeASCII:(NSString*)text controller:(BanshInputController*)controller client:(BanshFakeTextClient*)client
{
    for (NSUInteger i = 0; i < text.length; ++i) {
        NSString* character = [text substringWithRange:NSMakeRange(i, 1)];
        XCTAssertTrue([controller inputText:character key:0 modifiers:0 client:client],
                      @"Expected Bansh to handle %@", character);
    }
}

- (void)testClientCaretChangesAreRespectedDuringComposition
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    [client insertText:@"prefix " replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self typeASCII:@"bansh" controller:controller client:client];

    client.selectedRangeValue = NSMakeRange(8, 0);
    [self typeASCII:@"z" controller:controller client:client];

    XCTAssertEqualObjects(client.text, @"prefix бзанш");
    XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(9, 0)));

    client.selectedRangeValue = NSMakeRange(10, 0);
    XCTAssertTrue([controller didCommandBySelector:@selector(deleteBackward:) client:client]);
    XCTAssertEqualObjects(client.text, @"prefix бзнш");
    XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(9, 0)));
}

- (void)testTypingAndDeletionReplaceTheClientSelection
{
    for (NSString* action in @[@"type", @"backspace", @"delete"]) {
        BanshInputController* controller = [BanshInputController new];
        BanshFakeTextClient* client = [BanshFakeTextClient new];
        [self typeASCII:@"bansh" controller:controller client:client];
        client.selectedRangeValue = NSMakeRange(1, 2);

        if ([action isEqualToString:@"type"]) {
            [self typeASCII:@"sh" controller:controller client:client];
            XCTAssertEqualObjects(client.text, @"бшш");
            XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(2, 0)));
        } else {
            SEL selector = [action isEqualToString:@"backspace"] ? @selector(deleteBackward:) : @selector(deleteForward:);
            XCTAssertTrue([controller didCommandBySelector:selector client:client]);
            XCTAssertEqualObjects(client.text, @"бш");
            XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(1, 0)));
        }
    }
}

- (void)testSeparatorsAreInsertedAtTheCompositionCaret
{
    for (NSString* separator in @[@" ", @".", @"\n"]) {
        BanshInputController* controller = [BanshInputController new];
        BanshFakeTextClient* client = [BanshFakeTextClient new];
        [self typeASCII:@"nom" controller:controller client:client];
        XCTAssertTrue([controller didCommandBySelector:@selector(moveLeft:) client:client]);

        BOOL handled = [separator isEqualToString:@"\n"]
            ? [controller didCommandBySelector:@selector(insertNewline:) client:client]
            : [controller inputText:separator key:0 modifiers:0 client:client];
        if (!handled) {
            [client insertText:separator replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        }

        XCTAssertEqualObjects(client.text, ([NSString stringWithFormat:@"но%@м", separator]));
        XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(3, 0)));
        XCTAssertEqual(client.markedRange.location, NSNotFound);

        [self typeASCII:@"z" controller:controller client:client];
        XCTAssertEqualObjects(client.text, ([NSString stringWithFormat:@"но%@зм", separator]));
    }
}

- (void)testSeparatorsReplaceTheSelectedCompositionText
{
    for (NSString* separator in @[@" ", @".", @"\n"]) {
        BanshInputController* controller = [BanshInputController new];
        BanshFakeTextClient* client = [BanshFakeTextClient new];
        [self typeASCII:@"nom" controller:controller client:client];
        client.selectedRangeValue = NSMakeRange(1, 1);

        BOOL handled = [separator isEqualToString:@"\n"]
            ? [controller didCommandBySelector:@selector(insertNewline:) client:client]
            : [controller inputText:separator key:0 modifiers:0 client:client];
        if (!handled) {
            [client insertText:separator replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        }

        XCTAssertEqualObjects(client.text, ([NSString stringWithFormat:@"н%@м", separator]));
        XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(2, 0)));
        XCTAssertEqual(client.markedRange.location, NSNotFound);
    }
}

- (void)testNativeTextViewPreservesCaretAcrossCommit
{
    BanshInputController* controller = [BanshInputController new];
    BanshNativeTextView* client = [[BanshNativeTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
    for (NSString* character in @[@"n", @"o", @"m"]) {
        XCTAssertTrue([controller inputText:character key:0 modifiers:0 client:client]);
    }
    [client setSelectedRange:NSMakeRange(2, 0)];

    [controller commitComposition:client];
    XCTAssertEqualObjects(client.string, @"ном");
    XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(2, 0)));
    XCTAssertFalse(client.hasMarkedText);
    [client insertText:@" " replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    XCTAssertEqualObjects(client.string, @"но м");
    XCTAssertTrue([controller inputText:@"z" key:0 modifiers:0 client:client]);
    XCTAssertEqualObjects(client.string, @"но зм");
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

- (void)testControlSlashShortcutAcceptsControlCharacterVariant
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    NSString* controlSlash = [NSString stringWithFormat:@"%C", static_cast<unichar>(0x1F)];

    const BOOL handled = [controller inputText:controlSlash
                                          key:kVK_ANSI_Slash
                                    modifiers:NSEventModifierFlagControl
                                       client:client];

    XCTAssertTrue(handled);
    XCTAssertEqualObjects(client.text, @"");
}

- (void)testLiteralControlSlashOpensAndTogglesTheNativePanel
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];

    XCTAssertTrue([controller inputText:@"/"
                                    key:kVK_ANSI_Slash
                              modifiers:NSEventModifierFlagControl
                                 client:client]);

    NSPanel* panel = [controller valueForKey:@"cheatSheetPanel_"];
    XCTAssertNotNil(panel);
    XCTAssertTrue(panel.visible);
    XCTAssertEqualObjects(panel.title, @"Bansh Mappings");
    XCTAssertNotEqual(panel.styleMask & NSWindowStyleMaskTitled, 0U);
    XCTAssertNotEqual(panel.styleMask & NSWindowStyleMaskClosable, 0U);
    XCTAssertNotEqual(panel.styleMask & NSWindowStyleMaskUtilityWindow, 0U);
    XCTAssertNotEqual(panel.styleMask & NSWindowStyleMaskNonactivatingPanel, 0U);
    XCTAssertFalse(panel.hidesOnDeactivate);
    XCTAssertNotEqual(panel.collectionBehavior & NSWindowCollectionBehaviorFullScreenAuxiliary, 0U);
    XCTAssertNotNil([panel standardWindowButton:NSWindowCloseButton]);

    NSScrollView* scrollView = BanshFirstScrollViewInView(panel.contentView);
    XCTAssertNotNil(scrollView);
    XCTAssertTrue(scrollView.hasVerticalScroller);
    XCTAssertGreaterThan(NSHeight(scrollView.documentView.frame), NSHeight(scrollView.contentView.bounds));
    NSStackView* mappingContent = (NSStackView*)scrollView.documentView;
    NSStackView* firstSection = (NSStackView*)mappingContent.arrangedSubviews.firstObject;
    NSView* firstTitle = firstSection.arrangedSubviews.firstObject;
    NSRect titleRect = [firstTitle convertRect:firstTitle.bounds toView:mappingContent];
    XCTAssertTrue(NSContainsRect(scrollView.documentVisibleRect, titleRect), @"The first mapping section should be visible on opening.");

    [panel performClose:nil];
    XCTAssertFalse(panel.visible);

    XCTAssertTrue([controller inputText:@"/"
                                    key:kVK_ANSI_Slash
                              modifiers:NSEventModifierFlagControl
                                 client:client]);
    XCTAssertTrue(panel.visible);

    XCTAssertTrue([controller inputText:@"/"
                                    key:kVK_ANSI_Slash
                              modifiers:NSEventModifierFlagControl
                                 client:client]);
    XCTAssertFalse(panel.visible);
}

- (void)testControlSlashRejectsAdditionalModifiers
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];

    const BOOL handled = [controller inputText:@"/"
                                          key:kVK_ANSI_Slash
                                    modifiers:NSEventModifierFlagControl | NSEventModifierFlagShift
                                       client:client];

    XCTAssertFalse(handled);
    XCTAssertNil([controller valueForKey:@"cheatSheetPanel_"]);
}

- (void)testControlSlashShortcutAcceptsKeybindingInputPath
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    NSString* controlSlash = [NSString stringWithFormat:@"%C", static_cast<unichar>(0x1F)];

    const BOOL handled = [controller inputText:controlSlash client:client];

    XCTAssertTrue(handled);
    XCTAssertEqualObjects(client.text, @"");
}

- (void)testEscapeAndDeactivationDismissThePanel
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    NSString* controlSlash = [NSString stringWithFormat:@"%C", static_cast<unichar>(0x1F)];

    XCTAssertTrue([controller inputText:controlSlash client:client]);
    NSPanel* panel = [controller valueForKey:@"cheatSheetPanel_"];
    XCTAssertTrue(panel.visible);
    XCTAssertTrue([controller didCommandBySelector:@selector(cancelOperation:) client:client]);
    XCTAssertFalse(panel.visible);

    XCTAssertTrue([controller inputText:controlSlash client:client]);
    XCTAssertTrue(panel.visible);
    [controller deactivateServer:client];
    XCTAssertFalse(panel.visible);
}

- (void)testCheatSheetPositionStaysInsideTheVisibleScreen
{
    NSScreen* screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (screen == nil) {
        return;
    }

    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    NSRect visibleFrame = screen.visibleFrame;
    client.characterRectValue = NSMakeRect(NSMaxX(visibleFrame) - 1.0,
                                           NSMinY(visibleFrame) + 1.0,
                                           1.0,
                                           20.0);
    const NSSize panelSize = NSMakeSize(560.0, MIN(500.0, NSHeight(visibleFrame) - 24.0));

    NSRect frame = [controller preferredCheatSheetFrameForClient:client panelSize:panelSize];

    XCTAssertGreaterThanOrEqual(NSMinX(frame), NSMinX(visibleFrame) + 12.0);
    XCTAssertLessThanOrEqual(NSMaxX(frame), NSMaxX(visibleFrame) - 12.0);
    XCTAssertGreaterThanOrEqual(NSMinY(frame), NSMinY(visibleFrame) + 12.0);
    XCTAssertLessThanOrEqual(NSMaxY(frame), NSMaxY(visibleFrame) - 12.0);
}

- (void)testCheatSheetMappingsMatchTheEngine
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    NSString* controlSlash = [NSString stringWithFormat:@"%C", static_cast<unichar>(0x1F)];

    XCTAssertTrue([controller inputText:controlSlash client:client]);

    NSPanel* panel = [controller valueForKey:@"cheatSheetPanel_"];
    XCTAssertNotNil(panel);
    NSArray<NSString*>* labels = BanshTextValuesInView(panel.contentView);
    NSMutableSet<NSString*>* expectedLabels = [NSMutableSet set];
    NSUInteger mappingCount = 0;

    for (BanshMappingSection* section in BanshMappingCatalog()) {
        XCTAssertTrue([labels containsObject:section.title], @"Cheat sheet is missing section %@", section.title);
        for (BanshMappingItem* mapping in section.items) {
            ++mappingCount;
            NSString* label = BanshMappingLabel(mapping);
            [expectedLabels addObject:label];
            XCTAssertTrue([labels containsObject:label], @"Cheat sheet is missing %@", label);

            XCTAssertGreaterThan(mapping.validationExamples.count, 0U);
            for (BanshMappingExample* example in mapping.validationExamples) {
                BanshInputController* mappingController = [BanshInputController new];
                BanshFakeTextClient* mappingClient = [BanshFakeTextClient new];
                [self typeASCII:example.input controller:mappingController client:mappingClient];
                XCTAssertEqualObjects(mappingClient.text,
                                      example.output,
                                      @"Cheat sheet mapping %@ failed for input %@",
                                      label,
                                      example.input);
            }
        }
    }

    NSPredicate* mappingPredicate = [NSPredicate predicateWithBlock:^BOOL(NSString* value, NSDictionary* bindings) {
        return [value containsString:@"→"];
    }];
    NSArray<NSString*>* displayedMappings = [labels filteredArrayUsingPredicate:mappingPredicate];
    XCTAssertEqual(mappingCount, 62U);
    XCTAssertEqual(expectedLabels.count, mappingCount);
    XCTAssertEqual(displayedMappings.count, mappingCount);
    XCTAssertTrue([labels containsObject:@"62 input forms. Letters are case-aware; O and U follow vowel harmony. Press Control+/ again or Esc to close."]);
    [panel orderOut:nil];
}

- (void)testCompositionLimitCommitsAndStartsANewComposition
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];

    for (NSUInteger index = 0; index < 50; ++index) {
        XCTAssertTrue([controller inputText:@"a" key:0 modifiers:0 client:client]);
    }

    XCTAssertTrue([controller inputText:@"z" key:0 modifiers:0 client:client]);

    NSString* committedPrefix = [@"" stringByPaddingToLength:50 withString:@"а" startingAtIndex:0];
    XCTAssertEqualObjects(client.text, [committedPrefix stringByAppendingString:@"з"]);
    XCTAssertTrue(NSEqualRanges([client markedRange], NSMakeRange(50, 1)));

    XCTAssertTrue([controller inputText:@" " key:0 modifiers:0 client:client]);
    XCTAssertEqualObjects(client.text, [committedPrefix stringByAppendingString:@"з "]);
    XCTAssertEqual([client markedRange].location, NSNotFound);
}

- (void)testCompositionLimitPreservesTheInsertionPoint
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    [self typeASCII:[@"" stringByPaddingToLength:50 withString:@"a" startingAtIndex:0]
        controller:controller client:client];
    client.selectedRangeValue = NSMakeRange(20, 0);

    [self typeASCII:@"z" controller:controller client:client];

    NSString* prefix = [@"" stringByPaddingToLength:20 withString:@"а" startingAtIndex:0];
    NSString* suffix = [@"" stringByPaddingToLength:30 withString:@"а" startingAtIndex:0];
    XCTAssertEqualObjects(client.text, ([NSString stringWithFormat:@"%@з%@", prefix, suffix]));
    XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(21, 0)));
    XCTAssertTrue(NSEqualRanges(client.markedRange, NSMakeRange(20, 1)));
}

- (void)testSelectionReplacementAtTheCompositionLimit
{
    BanshInputController* controller = [BanshInputController new];
    BanshFakeTextClient* client = [BanshFakeTextClient new];
    [self typeASCII:[@"" stringByPaddingToLength:50 withString:@"a" startingAtIndex:0]
        controller:controller client:client];
    client.selectedRangeValue = NSMakeRange(20, 2);

    [self typeASCII:@"z" controller:controller client:client];

    NSString* prefix = [@"" stringByPaddingToLength:20 withString:@"а" startingAtIndex:0];
    NSString* suffix = [@"" stringByPaddingToLength:28 withString:@"а" startingAtIndex:0];
    XCTAssertEqualObjects(client.text, ([NSString stringWithFormat:@"%@з%@", prefix, suffix]));
    XCTAssertTrue(NSEqualRanges(client.selectedRange, NSMakeRange(21, 0)));
    XCTAssertTrue(NSEqualRanges(client.markedRange, NSMakeRange(0, 49)));
}

@end
