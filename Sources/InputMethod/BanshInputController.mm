#import "BanshInputController.h"
#import "BanshMappingCatalog.h"
#import "BanshUpdateChecker.h"

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#include "../Core/TransliterationSession.h"

using bansh::core::Snapshot;
using bansh::core::TransliterationSession;

namespace {

NSString* NSStringFromEngineString(std::u16string_view text)
{
    return [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar*>(text.data())
                                         length:text.size()];
}

NSAttributedString* NSAttributedStringFromEngineString(std::u16string_view text)
{
    return [[NSAttributedString alloc] initWithString:NSStringFromEngineString(text)];
}

NSUInteger disallowedModifierFlags()
{
    return NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption;
}

NSUInteger deviceIndependentModifierFlags(NSUInteger flags)
{
    return flags & NSEventModifierFlagDeviceIndependentFlagsMask;
}

BOOL isControlSlashShortcut(NSString* string, NSInteger keyCode, NSUInteger flags)
{
    NSUInteger modifiers = deviceIndependentModifierFlags(flags);
    const BOOL isControlSlashCharacter =
        [string isEqualToString:[NSString stringWithFormat:@"%C", static_cast<unichar>(0x1F)]];
    const BOOL isSlashInput = [string isEqualToString:@"/"] || keyCode == kVK_ANSI_Slash;

    return isControlSlashCharacter ||
        (isSlashInput &&
        (modifiers & NSEventModifierFlagControl) != 0 &&
        (modifiers & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagShift)) == 0);
}

} // namespace

@interface BanshInputController () {
    TransliterationSession session_;
    NSPanel* cheatSheetPanel_;
}

- (void)applySnapshot:(const Snapshot&)snapshot client:(id<IMKTextInput, NSObject>)client;
- (BOOL)commitCompositionAndInsertText:(NSString*)text client:(id<IMKTextInput, NSObject>)client;
- (NSRange)committedTextReplacementRangeForClient:(id<IMKTextInput, NSObject>)client;
- (void)clearMarkedTextForClient:(id<IMKTextInput, NSObject>)client;
- (NSPanel*)createCheatSheetPanel;
- (NSTextField*)cheatSheetLabel:(NSString*)text font:(NSFont*)font color:(NSColor*)color;
- (NSView*)cheatSheetMappingGridWithItems:(NSArray<BanshMappingItem*>*)items;
- (NSView*)cheatSheetSection:(BanshMappingSection*)mappingSection;
- (void)hideCheatSheetPanel;
- (NSRect)preferredCheatSheetFrameForClient:(id<IMKTextInput, NSObject>)client panelSize:(NSSize)panelSize;
- (NSScreen*)screenForRect:(NSRect)rect fallback:(NSScreen*)fallback;
- (void)toggleCheatSheetPanelForClient:(id<IMKTextInput, NSObject>)client;
- (void)updateCompositionForClient:(id<IMKTextInput, NSObject>)client snapshot:(const Snapshot&)snapshot;

@end

@implementation BanshInputController

- (BOOL)inputText:(NSString*)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender
{
    id<IMKTextInput, NSObject> client = sender;
    const Snapshot& current = session_.snapshot();

    if (isControlSlashShortcut(string, keyCode, flags)) {
        [self toggleCheatSheetPanelForClient:client];
        return YES;
    }

    if ((flags & disallowedModifierFlags()) != 0) {
        return NO;
    }

    if (string.length == 1) {
        const char16_t scalar = static_cast<char16_t>([string characterAtIndex:0]);

        if (TransliterationSession::isInputCharacter(scalar)) {
            Snapshot snapshot = session_.insert(scalar);
            if (!snapshot.changed && snapshot.isComposing) {
                [self commitComposition:client];
                snapshot = session_.insert(scalar);
            }
            [self applySnapshot:snapshot client:client];
            return snapshot.changed ? YES : NO;
        }

        if (scalar == u' ') {
            return [self commitCompositionAndInsertText:string client:client];
        }
    }

    if (current.isComposing) {
        [self commitComposition:client];
    }

    return NO;
}

- (BOOL)inputText:(NSString*)string client:(id)sender
{
    return [self inputText:string key:0 modifiers:0 client:sender];
}

- (BOOL)didCommandBySelector:(SEL)selector client:(id)sender
{
    id<IMKTextInput, NSObject> client = sender;
    const Snapshot& current = session_.snapshot();

    if (selector == @selector(cancelOperation:) && cheatSheetPanel_ != nil && [cheatSheetPanel_ isVisible]) {
        [self hideCheatSheetPanel];
        return YES;
    }

    if (!current.isComposing) {
        return NO;
    }

    if (selector == @selector(deleteBackward:)) {
        const Snapshot snapshot = session_.backspace();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(deleteForward:)) {
        const Snapshot snapshot = session_.deleteForward();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(moveLeft:)) {
        const Snapshot snapshot = session_.moveLeft();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(moveRight:)) {
        const Snapshot snapshot = session_.moveRight();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(moveToBeginningOfLine:) || selector == @selector(moveToBeginningOfParagraph:)) {
        const Snapshot snapshot = session_.moveHome();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(moveToEndOfLine:) || selector == @selector(moveToEndOfParagraph:)) {
        const Snapshot snapshot = session_.moveEnd();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(cancelOperation:)) {
        const Snapshot snapshot = session_.cancel();
        [self applySnapshot:snapshot client:client];
        return snapshot.changed ? YES : NO;
    }

    if (selector == @selector(insertNewline:) ||
        selector == @selector(insertLineBreak:) ||
        selector == @selector(insertParagraphSeparator:)) {
        return [self commitCompositionAndInsertText:@"\n" client:client];
    }

    if (selector == @selector(insertTab:)) {
        [self commitComposition:client];
        return NO;
    }

    if (selector == @selector(insertBacktab:)) {
        [self commitComposition:client];
        return NO;
    }

    return NO;
}

- (id)composedString:(id)sender
{
    return NSStringFromEngineString(session_.snapshot().markedText);
}

- (NSAttributedString*)originalString:(id)sender
{
    return NSAttributedStringFromEngineString(session_.snapshot().rawInput);
}

- (NSRange)selectionRange
{
    const std::size_t cursor = session_.snapshot().cursor;
    return NSMakeRange(cursor, 0);
}

- (NSUInteger)recognizedEvents:(id)sender
{
    return NSEventMaskKeyDown;
}

- (void)activateServer:(id)sender
{
    [[BanshUpdateChecker sharedChecker] checkForUpdatesIfNeeded];
}

- (void)deactivateServer:(id)sender
{
    [self hideCheatSheetPanel];

    if (session_.snapshot().isComposing) {
        [self commitComposition:sender];
    }
}

- (void)commitComposition:(id)sender
{
    id<IMKTextInput, NSObject> client = sender ?: [self client];
    if (client == nil) {
        return;
    }

    if (!session_.snapshot().isComposing) {
        return;
    }

    const Snapshot snapshot = session_.commit();
    [self applySnapshot:snapshot client:client];
}

- (BOOL)commitCompositionAndInsertText:(NSString*)text client:(id<IMKTextInput, NSObject>)client
{
    client = client ?: [self client];
    if (client == nil) {
        return NO;
    }

    if (!session_.snapshot().isComposing) {
        return NO;
    }

    [self commitComposition:client];
    [client insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    return YES;
}

- (void)inputControllerWillClose
{
    [self hideCheatSheetPanel];

    id<IMKTextInput, NSObject> client = [self client];
    if (client != nil && session_.snapshot().isComposing) {
        [self commitComposition:client];
    }
}

- (NSArray*)candidates:(id)sender
{
    return @[];
}

- (NSTextField*)cheatSheetLabel:(NSString*)text font:(NSFont*)font color:(NSColor*)color
{
    NSTextField* label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (NSView*)cheatSheetMappingGridWithItems:(NSArray<BanshMappingItem*>*)items
{
    NSGridView* grid = [[NSGridView alloc] initWithFrame:NSZeroRect];
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    grid.rowSpacing = 7.0;
    grid.columnSpacing = 10.0;
    grid.xPlacement = NSGridCellPlacementLeading;
    grid.yPlacement = NSGridCellPlacementCenter;

    NSFont* mappingFont = [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightMedium];
    NSColor* mappingColor = [NSColor labelColor];

    constexpr NSUInteger kColumnCount = 3;
    for (NSUInteger rowIndex = 0; rowIndex < items.count; rowIndex += kColumnCount) {
        NSMutableArray<NSView*>* cells = [NSMutableArray array];
        for (NSUInteger columnIndex = 0; columnIndex < kColumnCount; ++columnIndex) {
            const NSUInteger itemIndex = rowIndex + columnIndex;
            NSView* cell = nil;
            if (itemIndex < items.count) {
                NSString* mapping = BanshMappingLabel(items[itemIndex]);
                NSTextField* label = [self cheatSheetLabel:mapping font:mappingFont color:mappingColor];
                label.toolTip = mapping;
                cell = label;
            } else {
                cell = [NSView new];
            }
            [cell.widthAnchor constraintEqualToConstant:156.0].active = YES;
            [cells addObject:cell];
        }
        [grid addRowWithViews:cells];
    }

    return grid;
}

- (NSView*)cheatSheetSection:(BanshMappingSection*)mappingSection
{
    NSStackView* section = [[NSStackView alloc] initWithFrame:NSZeroRect];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.spacing = 5.0;

    NSTextField* titleLabel = [self cheatSheetLabel:mappingSection.title
                                              font:[NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold]
                                             color:[NSColor secondaryLabelColor]];
    [section addArrangedSubview:titleLabel];
    [section addArrangedSubview:[self cheatSheetMappingGridWithItems:mappingSection.items]];
    return section;
}

- (NSPanel*)createCheatSheetPanel
{
    const NSRect contentRect = NSMakeRect(0, 0, 560, 500);
    NSPanel* panel = [[NSPanel alloc] initWithContentRect:contentRect
                                                styleMask:NSWindowStyleMaskTitled |
                                                    NSWindowStyleMaskClosable |
                                                    NSWindowStyleMaskUtilityWindow |
                                                    NSWindowStyleMaskNonactivatingPanel
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    panel.title = @"Bansh Mappings";
    panel.level = NSFloatingWindowLevel;
    panel.opaque = NO;
    panel.backgroundColor = [NSColor clearColor];
    panel.hasShadow = YES;
    panel.hidesOnDeactivate = NO;
    panel.becomesKeyOnlyIfNeeded = YES;
    panel.movableByWindowBackground = YES;
    panel.releasedWhenClosed = NO;
    panel.restorable = NO;
    panel.excludedFromWindowsMenu = YES;
    panel.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
    panel.collectionBehavior = NSWindowCollectionBehaviorTransient |
        NSWindowCollectionBehaviorMoveToActiveSpace |
        NSWindowCollectionBehaviorFullScreenAuxiliary;
    [[panel standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
    [[panel standardWindowButton:NSWindowZoomButton] setHidden:YES];

    NSVisualEffectView* background = [[NSVisualEffectView alloc] initWithFrame:contentRect];
    background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    background.material = NSVisualEffectMaterialContentBackground;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;

    NSUInteger mappingCount = 0;
    for (BanshMappingSection* section in BanshMappingCatalog()) {
        mappingCount += section.items.count;
    }

    NSString* summary = [NSString stringWithFormat:
        @"%lu input forms. Letters are case-aware; O and U follow vowel harmony. "
         "Press Control+/ again or Esc to close.",
        static_cast<unsigned long>(mappingCount)];
    NSTextField* summaryLabel = [NSTextField wrappingLabelWithString:summary];
    summaryLabel.frame = NSMakeRect(14.0, 450.0, 532.0, 38.0);
    summaryLabel.font = [NSFont systemFontOfSize:12.0];
    summaryLabel.textColor = [NSColor secondaryLabelColor];
    [background addSubview:summaryLabel];

    NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(14.0, 14.0, 532.0, 426.0)];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    scrollView.borderType = NSNoBorder;
    scrollView.verticalLineScroll = 24.0;

    NSStackView* mappingContent = [[NSStackView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 510.0, 1.0)];
    mappingContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    mappingContent.alignment = NSLayoutAttributeLeading;
    mappingContent.spacing = 14.0;
    mappingContent.edgeInsets = NSEdgeInsetsMake(8.0, 4.0, 12.0, 4.0);

    for (BanshMappingSection* section in BanshMappingCatalog()) {
        [mappingContent addArrangedSubview:[self cheatSheetSection:section]];
    }

    NSSize fittingSize = mappingContent.fittingSize;
    mappingContent.frame = NSMakeRect(0.0, 0.0, 510.0, fittingSize.height);
    scrollView.documentView = mappingContent;
    [background addSubview:scrollView];

    panel.contentView = background;
    return panel;
}

- (NSScreen*)screenForRect:(NSRect)rect fallback:(NSScreen*)fallback
{
    NSPoint midpoint = NSMakePoint(NSMidX(rect), NSMidY(rect));
    for (NSScreen* candidate in [NSScreen screens]) {
        if (NSPointInRect(midpoint, candidate.visibleFrame)) {
            return candidate;
        }
    }

    for (NSScreen* candidate in [NSScreen screens]) {
        if (NSIntersectsRect(rect, candidate.visibleFrame)) {
            return candidate;
        }
    }

    return fallback ?: [NSScreen mainScreen];
}

- (NSRect)preferredCheatSheetFrameForClient:(id<IMKTextInput, NSObject>)client panelSize:(NSSize)panelSize
{
    NSScreen* screen = [NSScreen mainScreen] ?: [NSScreen screens].firstObject;
    NSRect caretRect = NSZeroRect;

    if (client != nil) {
        NSRange selectedRange = [client selectedRange];
        if (selectedRange.location != NSNotFound) {
            NSRange actualRange = NSMakeRange(NSNotFound, 0);
            caretRect = [client firstRectForCharacterRange:selectedRange actualRange:&actualRange];
        }
    }

    if (!NSEqualRects(caretRect, NSZeroRect)) {
        NSPoint caretPoint = NSMakePoint(NSMidX(caretRect), NSMinY(caretRect));
        screen = [self screenForRect:caretRect fallback:screen];
        NSRect visibleFrame = screen.visibleFrame;
        CGFloat x = caretPoint.x + 12.0;
        CGFloat y = caretPoint.y - panelSize.height - 8.0;

        if (y < NSMinY(visibleFrame)) {
            y = NSMaxY(caretRect) + 8.0;
        }

        x = MIN(MAX(x, NSMinX(visibleFrame) + 12.0), NSMaxX(visibleFrame) - panelSize.width - 12.0);
        y = MIN(MAX(y, NSMinY(visibleFrame) + 12.0), NSMaxY(visibleFrame) - panelSize.height - 12.0);
        return NSMakeRect(x, y, panelSize.width, panelSize.height);
    }

    if (screen == nil) {
        return NSMakeRect(100.0, 100.0, panelSize.width, panelSize.height);
    }

    NSRect visibleFrame = screen.visibleFrame;
    return NSMakeRect(NSMaxX(visibleFrame) - panelSize.width - 18.0,
                      NSMaxY(visibleFrame) - panelSize.height - 18.0,
                      panelSize.width,
                      panelSize.height);
}

- (void)toggleCheatSheetPanelForClient:(id<IMKTextInput, NSObject>)client
{
    if (cheatSheetPanel_ != nil && [cheatSheetPanel_ isVisible]) {
        [self hideCheatSheetPanel];
        return;
    }

    if (cheatSheetPanel_ == nil) {
        cheatSheetPanel_ = [self createCheatSheetPanel];
    }

    NSSize panelSize = cheatSheetPanel_.frame.size;
    [cheatSheetPanel_ setFrame:[self preferredCheatSheetFrameForClient:client panelSize:panelSize] display:NO];
    [cheatSheetPanel_ orderFrontRegardless];
}

- (void)hideCheatSheetPanel
{
    [cheatSheetPanel_ orderOut:nil];
}

- (void)clearMarkedTextForClient:(id<IMKTextInput, NSObject>)client
{
    const NSRange markedRange = [client markedRange];
    if (markedRange.location != NSNotFound) {
        [client insertText:@"" replacementRange:markedRange];
    }
}

- (NSRange)committedTextReplacementRangeForClient:(id<IMKTextInput, NSObject>)client
{
    const NSRange markedRange = [client markedRange];
    return markedRange.location != NSNotFound ? markedRange : NSMakeRange(NSNotFound, NSNotFound);
}

- (void)updateCompositionForClient:(id<IMKTextInput, NSObject>)client snapshot:(const Snapshot&)snapshot
{
    const NSRange markedRange = [client markedRange];
    NSRange replacementRange = markedRange.location != NSNotFound ? markedRange : NSMakeRange(NSNotFound, NSNotFound);

    if (replacementRange.location == NSNotFound) {
        const NSRange selectedRange = [client selectedRange];
        if (selectedRange.location != NSNotFound) {
            replacementRange = selectedRange;
        }
    }

    const NSUInteger cursor = std::min<std::size_t>(snapshot.cursor, snapshot.markedText.size());
    [client setMarkedText:NSAttributedStringFromEngineString(snapshot.markedText)
            selectionRange:NSMakeRange(cursor, 0)
          replacementRange:replacementRange];
}

- (void)applySnapshot:(const Snapshot&)snapshot client:(id<IMKTextInput, NSObject>)client
{
    const BOOL insertedCommittedText = !snapshot.committedText.empty();
    if (insertedCommittedText) {
        [client insertText:NSStringFromEngineString(snapshot.committedText)
           replacementRange:[self committedTextReplacementRangeForClient:client]];
    }

    if (snapshot.isComposing) {
        [self updateCompositionForClient:client snapshot:snapshot];
    } else if (!insertedCommittedText) {
        [self clearMarkedTextForClient:client];
    }
}

@end
