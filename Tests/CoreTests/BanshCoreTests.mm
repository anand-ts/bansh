#import <XCTest/XCTest.h>

#include <string_view>

#include "TransliterationSession.h"

using bansh::core::Snapshot;
using bansh::core::TransliterationSession;

namespace {

NSString* NSStringFromEngineString(std::u16string_view text)
{
    return [[NSString alloc] initWithCharacters:reinterpret_cast<const unichar*>(text.data())
                                         length:text.size()];
}

Snapshot typeAscii(TransliterationSession& session, std::string_view ascii)
{
    Snapshot snapshot = session.snapshot();
    for (char ch : ascii) {
        snapshot = session.insert(static_cast<char16_t>(ch));
    }
    return snapshot;
}

NSString* markedTextForAscii(std::string_view ascii)
{
    TransliterationSession session;
    return NSStringFromEngineString(typeAscii(session, ascii).markedText);
}

} // namespace

@interface BanshCoreTests : XCTestCase
@end

@implementation BanshCoreTests

- (void)testBasicWordComposition
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "nom");

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"ном");
    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.rawInput), @"nom");
    XCTAssertEqual(snapshot.cursor, static_cast<std::size_t>(3));
    XCTAssertTrue(snapshot.isComposing);

    const Snapshot committed = session.commit();
    XCTAssertEqualObjects(NSStringFromEngineString(committed.committedText), @"ном");
    XCTAssertEqualObjects(NSStringFromEngineString(committed.markedText), @"");
    XCTAssertEqualObjects(NSStringFromEngineString(committed.rawInput), @"");
    XCTAssertFalse(committed.isComposing);
}

- (void)testReadmeExample
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "id'ye");

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"идье");
}

- (void)testInputCharacterSet
{
    XCTAssertTrue(TransliterationSession::isInputCharacter(u'a'));
    XCTAssertTrue(TransliterationSession::isInputCharacter(u'Z'));
    XCTAssertTrue(TransliterationSession::isInputCharacter(u'\''));
    XCTAssertTrue(TransliterationSession::isInputCharacter(u'"'));
    XCTAssertFalse(TransliterationSession::isInputCharacter(u' '));
    XCTAssertFalse(TransliterationSession::isInputCharacter(u'\n'));
}

- (void)testLongestMatchRules
{
    XCTAssertEqualObjects(markedTextForAscii("ch"), @"ч");
    XCTAssertEqualObjects(markedTextForAscii("sxc"), @"щ");
    XCTAssertEqualObjects(markedTextForAscii("iii"), @"ы");
}

- (void)testFemaleWordRule
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "eo");

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"эө");
}

- (void)testVowelHarmonyAndForcedVowels
{
    XCTAssertEqualObjects(markedTextForAscii("ao"), @"ао");
    XCTAssertEqualObjects(markedTextForAscii("eo"), @"эө");
    XCTAssertEqualObjects(markedTextForAscii("o\""), @"о");
    XCTAssertEqualObjects(markedTextForAscii("o'"), @"ө");
}

- (void)testMixedCaseInput
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "Nom");

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"Ном");
}

- (void)testDeleteAfterCursorMove
{
    TransliterationSession session;
    typeAscii(session, "nom");
    session.moveLeft();
    const Snapshot snapshot = session.deleteForward();

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"но");
    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.rawInput), @"но");
    XCTAssertEqual(snapshot.cursor, static_cast<std::size_t>(2));
}

- (void)testInsertAfterCursorMoveKeepsCompositionEditable
{
    TransliterationSession session;
    typeAscii(session, "az");
    session.moveLeft();
    const Snapshot snapshot = session.insert(u'u');

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"ауз");
    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.rawInput), @"аuз");
    XCTAssertEqual(snapshot.cursor, static_cast<std::size_t>(2));
}

- (void)testDoubleApostrophe
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "''");

    XCTAssertEqualObjects(NSStringFromEngineString(snapshot.markedText), @"Ь");
}

@end
