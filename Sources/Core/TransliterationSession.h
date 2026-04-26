#ifndef BANSH_TRANSLITERATION_SESSION_H
#define BANSH_TRANSLITERATION_SESSION_H

#include <cstddef>
#include <cstdint>
#include <string>

namespace bansh::core {

using EngineString = std::u16string;

struct Snapshot {
    EngineString rawInput;
    EngineString markedText;
    EngineString committedText;
    std::size_t cursor = 0;
    bool isComposing = false;
    bool changed = false;
};

class TransliterationSession {
public:
    TransliterationSession();

    static bool isInputCharacter(char16_t scalar);

    Snapshot insert(char16_t scalar);
    Snapshot backspace();
    Snapshot deleteForward();
    Snapshot moveLeft();
    Snapshot moveRight();
    Snapshot moveHome();
    Snapshot moveEnd();
    Snapshot commit();
    Snapshot cancel();

    const Snapshot& snapshot() const;

private:
    void rebuildMarkedText();
    void copyMarkedTextToRawInput();
    Snapshot publish(bool changed, EngineString committedText = {});

    EngineString rawInput_;
    EngineString markedText_;
    std::size_t cursor_ = 0;
    Snapshot snapshot_;
};

} // namespace bansh::core

#endif // BANSH_TRANSLITERATION_SESSION_H
