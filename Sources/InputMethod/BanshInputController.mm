#import "BanshInputController.h"

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

} // namespace

@interface BanshInputController () {
    TransliterationSession session_;
}

- (void)applySnapshot:(const Snapshot&)snapshot client:(id<IMKTextInput, NSObject>)client;
- (BOOL)commitCompositionAndInsertText:(NSString*)text client:(id<IMKTextInput, NSObject>)client;
- (NSRange)committedTextReplacementRangeForClient:(id<IMKTextInput, NSObject>)client;
- (void)clearMarkedTextForClient:(id<IMKTextInput, NSObject>)client;
- (void)updateCompositionForClient:(id<IMKTextInput, NSObject>)client snapshot:(const Snapshot&)snapshot;

@end

@implementation BanshInputController

- (BOOL)inputText:(NSString*)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender
{
    id<IMKTextInput, NSObject> client = sender;
    const Snapshot& current = session_.snapshot();

    if ((flags & disallowedModifierFlags()) != 0) {
        return NO;
    }

    if (string.length == 1) {
        const char16_t scalar = static_cast<char16_t>([string characterAtIndex:0]);

        if (TransliterationSession::isInputCharacter(scalar)) {
            const Snapshot snapshot = session_.insert(scalar);
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

- (BOOL)didCommandBySelector:(SEL)selector client:(id)sender
{
    id<IMKTextInput, NSObject> client = sender;
    const Snapshot& current = session_.snapshot();

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
}

- (void)deactivateServer:(id)sender
{
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
    id<IMKTextInput, NSObject> client = [self client];
    if (client != nil && session_.snapshot().isComposing) {
        [self commitComposition:client];
    }
}

- (NSArray*)candidates:(id)sender
{
    return @[];
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
