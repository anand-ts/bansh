#include <cstdlib>
#include <iostream>
#include <string_view>

#include "TransliterationSession.h"

using bansh::core::Snapshot;
using bansh::core::TransliterationSession;

namespace {

std::string toUtf8(std::u16string_view text)
{
    std::string utf8;

    for (char16_t scalar : text) {
        const std::uint32_t codePoint = scalar;

        if (codePoint <= 0x7Fu) {
            utf8.push_back(static_cast<char>(codePoint));
        } else if (codePoint <= 0x7FFu) {
            utf8.push_back(static_cast<char>(0xC0u | (codePoint >> 6)));
            utf8.push_back(static_cast<char>(0x80u | (codePoint & 0x3Fu)));
        } else {
            utf8.push_back(static_cast<char>(0xE0u | (codePoint >> 12)));
            utf8.push_back(static_cast<char>(0x80u | ((codePoint >> 6) & 0x3Fu)));
            utf8.push_back(static_cast<char>(0x80u | (codePoint & 0x3Fu)));
        }
    }

    return utf8;
}

void expectEqual(const char* label, std::u16string_view actual, std::u16string_view expected, int& failures)
{
    if (actual == expected) {
        return;
    }

    std::cerr << "FAIL " << label << "\n";
    std::cerr << "  expected: " << toUtf8(expected) << "\n";
    std::cerr << "  actual:   " << toUtf8(actual) << "\n";
    ++failures;
}

void expectEqual(const char* label, std::size_t actual, std::size_t expected, int& failures)
{
    if (actual == expected) {
        return;
    }

    std::cerr << "FAIL " << label << "\n";
    std::cerr << "  expected: " << expected << "\n";
    std::cerr << "  actual:   " << actual << "\n";
    ++failures;
}

void expectEqual(const char* label, bool actual, bool expected, int& failures)
{
    if (actual == expected) {
        return;
    }

    std::cerr << "FAIL " << label << "\n";
    std::cerr << "  expected: " << (expected ? "true" : "false") << "\n";
    std::cerr << "  actual:   " << (actual ? "true" : "false") << "\n";
    ++failures;
}

Snapshot typeAscii(TransliterationSession& session, std::string_view ascii)
{
    Snapshot snapshot = session.snapshot();
    for (char ch : ascii) {
        snapshot = session.insert(static_cast<char16_t>(ch));
    }
    return snapshot;
}

void testBasicWord(int& failures)
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "buuz");

    expectEqual("basic word marked text", snapshot.markedText, u"\u0431\u0443\u0443\u0437", failures);
    expectEqual("basic word raw input", snapshot.rawInput, u"buuz", failures);
    expectEqual("basic word cursor", snapshot.cursor, 4, failures);
    expectEqual("basic word composing", snapshot.isComposing, true, failures);

    const Snapshot committed = session.commit();
    expectEqual("commit text", committed.committedText, u"\u0431\u0443\u0443\u0437", failures);
    expectEqual("commit clears marked text", committed.markedText, u"", failures);
    expectEqual("commit clears raw input", committed.rawInput, u"", failures);
    expectEqual("commit clears composing flag", committed.isComposing, false, failures);
}

void testReadmeExample(int& failures)
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "id'ye");

    expectEqual("readme example", snapshot.markedText, u"\u0438\u0434\u044C\u0435", failures);
}

void testFemaleWordRule(int& failures)
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "eo");

    expectEqual("female word rule", snapshot.markedText, u"\u044D\u04E9", failures);
}

void testMixedCase(int& failures)
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "Buuz");

    expectEqual("mixed case", snapshot.markedText, u"\u0411\u0443\u0443\u0437", failures);
}

void testDeleteAfterCursorMove(int& failures)
{
    TransliterationSession session;
    typeAscii(session, "buuz");
    session.moveLeft();
    const Snapshot snapshot = session.deleteForward();

    expectEqual("delete after move marked text", snapshot.markedText, u"\u0431\u0443\u0443", failures);
    expectEqual("delete after move raw input", snapshot.rawInput, u"\u0431\u0443\u0443", failures);
    expectEqual("delete after move cursor", snapshot.cursor, 3, failures);
}

void testDoubleApostrophe(int& failures)
{
    TransliterationSession session;
    const Snapshot snapshot = typeAscii(session, "''");

    expectEqual("double apostrophe", snapshot.markedText, u"\u042C", failures);
}

} // namespace

int main()
{
    int failures = 0;

    testBasicWord(failures);
    testReadmeExample(failures);
    testFemaleWordRule(failures);
    testMixedCase(failures);
    testDeleteAfterCursorMove(failures);
    testDoubleApostrophe(failures);

    if (failures != 0) {
        std::cerr << failures << " test(s) failed\n";
        return EXIT_FAILURE;
    }

    std::cout << "All core transliteration tests passed\n";
    return EXIT_SUCCESS;
}
