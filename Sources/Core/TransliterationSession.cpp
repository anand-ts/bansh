#include "TransliterationSession.h"

#include <algorithm>
#include <cstdint>
#include <set>
#include <unordered_map>
#include <utility>
#include <vector>

namespace bansh::core {

namespace {

constexpr std::size_t kMaxCompositionLength = 50;

constexpr std::uint32_t kAllowCaseConversion = 0x0001u;
constexpr std::uint32_t kMale = 0x0002u;
constexpr std::uint32_t kFemale = 0x0004u;
constexpr std::uint32_t kMakeMale = 0x0008u;
constexpr std::uint32_t kMakeFemale = 0x0010u;

constexpr std::uint8_t kCyrToUpper[] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    0x50, 0x01, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F,
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F,
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAE,
    0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF,
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF,
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE8, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
};

constexpr std::uint8_t kCyrToLower[] = {
    0x00, 0x51, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
    0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
    0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
    0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
    0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F,
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F,
    0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAF, 0xAF,
    0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF,
    0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF,
    0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE9, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
    0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
};

char16_t toUpper(char16_t scalar)
{
    if (scalar >= u'a' && scalar <= u'z') {
        return static_cast<char16_t>(scalar - (u'a' - u'A'));
    }

    const unsigned value = static_cast<unsigned>(scalar);
    if ((value >> 8) == 4) {
        return static_cast<char16_t>(0x0400u + kCyrToUpper[value & 0xFFu]);
    }

    return scalar;
}

char16_t toLower(char16_t scalar)
{
    if (scalar >= u'A' && scalar <= u'Z') {
        return static_cast<char16_t>(scalar + (u'a' - u'A'));
    }

    const unsigned value = static_cast<unsigned>(scalar);
    if ((value >> 8) == 4) {
        return static_cast<char16_t>(0x0400u + kCyrToLower[value & 0xFFu]);
    }

    return scalar;
}

bool isUpper(char16_t scalar)
{
    if (scalar >= u'A' && scalar <= u'Z') {
        return true;
    }

    const unsigned value = static_cast<unsigned>(scalar);
    return (value >> 8) == 4 && kCyrToLower[value & 0xFFu] != (value & 0xFFu);
}

bool isLower(char16_t scalar)
{
    if (scalar >= u'a' && scalar <= u'z') {
        return true;
    }

    const unsigned value = static_cast<unsigned>(scalar);
    return (value >> 8) == 4 && kCyrToUpper[value & 0xFFu] != (value & 0xFFu);
}

bool isAlpha(char16_t scalar)
{
    return isUpper(scalar) || isLower(scalar);
}

struct Rule {
    EngineString from;
    EngineString to;
    std::uint32_t flags;
};

struct RuleKeyHash {
    std::size_t operator()(const EngineString& text) const
    {
        std::size_t hash = 0;
        for (char16_t scalar : text) {
            hash = (hash << 4) + scalar;
            const std::size_t overflow = hash & 0xF0000000u;
            if (overflow != 0) {
                hash ^= overflow >> 24;
                hash ^= overflow;
            }
        }
        return hash;
    }
};

class RuleBook {
public:
    RuleBook();

    EngineString transliterate(const EngineString& rawInput) const;

private:
    void addRule(const char16_t* from, const char16_t* to, std::uint32_t flags);
    void insertRule(const EngineString& from, const EngineString& to, std::uint32_t flags);
    void computeRuleLengths();

    std::unordered_map<EngineString, std::vector<Rule>, RuleKeyHash> rulesByFrom_;
    std::vector<std::size_t> ruleLengths_;
    std::size_t maxRuleLength_ = 0;
};

RuleBook::RuleBook()
{
    const auto add = [this](const char16_t* from, const char16_t* to, std::uint32_t flags) {
        addRule(from, to, flags);
    };

    add(u"\u0410", u"\u0410", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u0410I", u"\u0410\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u041E", u"\u041E", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u041EI", u"\u041E\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u0423", u"\u0423", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u0423I", u"\u0423\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\u042D", u"\u042D", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"\u042DI", u"\u042D\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"\u04E8", u"\u04E8", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"\u04E8I", u"\u04E8\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"\u04AE", u"\u04AE", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"\u04AEI", u"\u04AE\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);

    add(u"\u0418I", u"\u0418\u0419", kMale | kFemale | kAllowCaseConversion);

    add(u"A", u"\u0410", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"AI", u"\u0410\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"B", u"\u0411", kMale | kFemale | kAllowCaseConversion);
    add(u"C", u"\u0426", kMale | kFemale | kAllowCaseConversion);
    add(u"CH", u"\u0427", kMale | kFemale | kAllowCaseConversion);
    add(u"D", u"\u0414", kMale | kFemale | kAllowCaseConversion);
    add(u"E", u"\u042D", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"EI", u"\u042D\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"F", u"\u0424", kMale | kFemale | kAllowCaseConversion);
    add(u"G", u"\u0413", kMale | kFemale | kAllowCaseConversion);
    add(u"H", u"\u0425", kMale | kFemale | kAllowCaseConversion);
    add(u"I", u"\u0418", kMale | kFemale | kAllowCaseConversion);
    add(u"II", u"\u0418\u0419", kMale | kFemale | kAllowCaseConversion);
    add(u"III", u"\u042B", kMale | kFemale | kAllowCaseConversion);
    add(u"J", u"\u0416", kMale | kFemale | kAllowCaseConversion);
    add(u"K", u"\u041A", kMale | kFemale | kAllowCaseConversion);
    add(u"KH", u"\u0425", kMale | kFemale | kAllowCaseConversion);
    add(u"L", u"\u041B", kMale | kFemale | kAllowCaseConversion);
    add(u"M", u"\u041C", kMale | kFemale | kAllowCaseConversion);
    add(u"N", u"\u041D", kMale | kFemale | kAllowCaseConversion);

    add(u"O", u"\u041E", kMale | kAllowCaseConversion);
    add(u"OI", u"\u041E\u0419", kMale | kAllowCaseConversion);
    add(u"O\"", u"\u041E", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"O\"I", u"\u041E\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\"O", u"\u041E", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\"OI", u"\u041E\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);

    add(u"O", u"\u04E8", kFemale | kAllowCaseConversion);
    add(u"OI", u"\u04E8\u0419", kFemale | kAllowCaseConversion);
    add(u"Q", u"\u04E8", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"QI", u"\u04E8\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"O'", u"\u04E8", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"O'I", u"\u04E8\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"'O", u"\u04E8", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"'OI", u"\u04E8\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);

    add(u"P", u"\u041F", kMale | kFemale | kAllowCaseConversion);
    add(u"R", u"\u0420", kMale | kFemale | kAllowCaseConversion);
    add(u"S", u"\u0421", kMale | kFemale | kAllowCaseConversion);
    add(u"SH", u"\u0428", kMale | kFemale | kAllowCaseConversion);
    add(u"SXC", u"\u0429", kMale | kFemale | kAllowCaseConversion);
    add(u"T", u"\u0422", kMale | kFemale | kAllowCaseConversion);

    add(u"U", u"\u0423", kMale | kAllowCaseConversion);
    add(u"UI", u"\u0423\u0419", kMale | kAllowCaseConversion);
    add(u"U\"", u"\u0423", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"U\"I", u"\u0423\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\"U", u"\u0423", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"\"UI", u"\u0423\u0419", kMale | kFemale | kMakeMale | kAllowCaseConversion);

    add(u"U", u"\u04AE", kFemale | kAllowCaseConversion);
    add(u"UI", u"\u04AE\u0419", kFemale | kAllowCaseConversion);
    add(u"W", u"\u04AE", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"WI", u"\u04AE\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"U'", u"\u04AE", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"U'I", u"\u04AE\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"'U", u"\u04AE", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"'UI", u"\u04AE\u0419", kMale | kFemale | kMakeFemale | kAllowCaseConversion);

    add(u"V", u"\u0412", kMale | kFemale | kAllowCaseConversion);
    add(u"X", u"\u0425", kMale | kFemale | kAllowCaseConversion);
    add(u"Y", u"\u042B", kMale | kFemale | kAllowCaseConversion);
    add(u"YA", u"\u042F", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"YE", u"\u0415", kMale | kFemale | kMakeFemale | kAllowCaseConversion);
    add(u"YO", u"\u0401", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"YU", u"\u042E", kMale | kFemale | kMakeMale | kAllowCaseConversion);
    add(u"Z", u"\u0417", kMale | kFemale | kAllowCaseConversion);

    add(u"\"", u"\u044A", kMale | kFemale);
    add(u"\"\"", u"\u042A", kMale | kFemale);
    add(u"'", u"\u044C", kMale | kFemale);
    add(u"''", u"\u042C", kMale | kFemale);

    computeRuleLengths();
}

void RuleBook::addRule(const char16_t* from, const char16_t* to, std::uint32_t flags)
{
    EngineString baseFrom(from);
    EngineString baseTo(to);

    if ((flags & kAllowCaseConversion) == 0) {
        insertRule(baseFrom, baseTo, flags);
        return;
    }

    std::vector<int> targetPositions(baseFrom.size(), -1);
    for (std::size_t i = 0, targetIndex = 0; i < baseFrom.size(); ++i) {
        if (isAlpha(baseFrom[i]) && targetIndex < baseTo.size()) {
            targetPositions[i] = static_cast<int>(targetIndex++);
        }
    }

    EngineString variantFrom = baseFrom;
    EngineString variantTo = baseTo;

    const auto walk = [&](const auto& self, std::size_t position) -> void {
        if (position >= variantFrom.size()) {
            insertRule(variantFrom, variantTo, flags);
            return;
        }

        if (!isAlpha(baseFrom[position])) {
            self(self, position + 1);
            return;
        }

        const int targetPosition = targetPositions[position];
        const char16_t originalFrom = baseFrom[position];
        const char16_t originalTo = targetPosition >= 0 ? baseTo[static_cast<std::size_t>(targetPosition)] : 0;

        variantFrom[position] = toUpper(originalFrom);
        if (targetPosition >= 0) {
            variantTo[static_cast<std::size_t>(targetPosition)] = toUpper(originalTo);
        }
        self(self, position + 1);

        variantFrom[position] = toLower(originalFrom);
        if (targetPosition >= 0) {
            variantTo[static_cast<std::size_t>(targetPosition)] = toLower(originalTo);
        }
        self(self, position + 1);

        variantFrom[position] = originalFrom;
        if (targetPosition >= 0) {
            variantTo[static_cast<std::size_t>(targetPosition)] = originalTo;
        }
    };

    walk(walk, 0);
}

void RuleBook::insertRule(const EngineString& from, const EngineString& to, std::uint32_t flags)
{
    rulesByFrom_[from].push_back(Rule{from, to, flags});
    maxRuleLength_ = std::max(maxRuleLength_, from.size());
}

void RuleBook::computeRuleLengths()
{
    std::set<std::size_t> uniqueLengths;
    for (const auto& [from, rules] : rulesByFrom_) {
        (void)rules;
        uniqueLengths.insert(from.size());
    }

    for (auto iter = uniqueLengths.rbegin(); iter != uniqueLengths.rend(); ++iter) {
        ruleLengths_.push_back(*iter);
    }
}

EngineString RuleBook::transliterate(const EngineString& rawInput) const
{
    EngineString markedText;
    markedText.reserve(rawInput.size());

    std::uint32_t wordFlags = kMale;
    std::size_t position = 0;

    while (position < rawInput.size()) {
        const std::size_t maxLookahead = std::min(maxRuleLength_, rawInput.size() - position);
        bool matched = false;

        for (std::size_t fromLength : ruleLengths_) {
            if (fromLength > maxLookahead) {
                continue;
            }

            const EngineString candidate(rawInput.data() + position, fromLength);
            const auto found = rulesByFrom_.find(candidate);
            if (found == rulesByFrom_.end()) {
                continue;
            }

            for (const Rule& rule : found->second) {
                if ((wordFlags & rule.flags) != wordFlags) {
                    continue;
                }

                if ((rule.flags & kMakeFemale) != 0) {
                    wordFlags = kFemale;
                } else if ((rule.flags & kMakeMale) != 0) {
                    wordFlags = kMale;
                }

                markedText += rule.to;
                position += rule.from.size();
                matched = true;
                break;
            }

            if (matched) {
                break;
            }
        }

        if (!matched) {
            markedText.push_back(rawInput[position]);
            ++position;
        }
    }

    return markedText;
}

const RuleBook& ruleBook()
{
    static const RuleBook instance;
    return instance;
}

} // namespace

TransliterationSession::TransliterationSession()
{
    snapshot_ = publish(false);
}

bool TransliterationSession::isInputCharacter(char16_t scalar)
{
    return scalar == u'\'' || scalar == u'"' ||
           (scalar >= u'a' && scalar <= u'z') ||
           (scalar >= u'A' && scalar <= u'Z');
}

Snapshot TransliterationSession::insert(char16_t scalar)
{
    if (rawInput_.size() >= kMaxCompositionLength) {
        return publish(false);
    }

    cursor_ = std::min(cursor_, markedText_.size());
    const std::size_t backCursorPos = markedText_.size() - cursor_;
    const std::size_t rawCursorPos = rawInput_.size() >= backCursorPos ? rawInput_.size() - backCursorPos : 0;

    rawInput_.insert(rawInput_.begin() + static_cast<std::ptrdiff_t>(rawCursorPos), scalar);
    rebuildMarkedText();
    cursor_ = markedText_.size() >= backCursorPos ? markedText_.size() - backCursorPos : 0;

    return publish(true);
}

Snapshot TransliterationSession::backspace()
{
    if (rawInput_.empty()) {
        return publish(false);
    }

    cursor_ = std::min(cursor_, markedText_.size());
    const std::size_t backCursorPos = markedText_.size() - cursor_;
    const std::size_t rawCursorPos = rawInput_.size() >= backCursorPos ? rawInput_.size() - backCursorPos : 0;

    if (rawCursorPos == 0) {
        return publish(false);
    }

    rawInput_.erase(rawInput_.begin() + static_cast<std::ptrdiff_t>(rawCursorPos - 1));
    rebuildMarkedText();
    cursor_ = markedText_.size() >= backCursorPos ? markedText_.size() - backCursorPos : 0;

    return publish(true);
}

Snapshot TransliterationSession::deleteForward()
{
    if (rawInput_.empty()) {
        return publish(false);
    }

    cursor_ = std::min(cursor_, markedText_.size());
    const std::size_t backCursorPos = markedText_.size() - cursor_;
    const std::size_t rawCursorPos = rawInput_.size() >= backCursorPos ? rawInput_.size() - backCursorPos : 0;

    if (rawCursorPos >= rawInput_.size()) {
        return publish(false);
    }

    rawInput_.erase(rawInput_.begin() + static_cast<std::ptrdiff_t>(rawCursorPos));
    rebuildMarkedText();
    cursor_ = std::min(cursor_, markedText_.size());

    return publish(true);
}

Snapshot TransliterationSession::moveLeft()
{
    if (markedText_.empty() || cursor_ == 0) {
        return publish(false);
    }

    copyMarkedTextToRawInput();
    --cursor_;
    return publish(true);
}

Snapshot TransliterationSession::moveRight()
{
    if (markedText_.empty() || cursor_ >= markedText_.size()) {
        return publish(false);
    }

    copyMarkedTextToRawInput();
    ++cursor_;
    return publish(true);
}

Snapshot TransliterationSession::moveHome()
{
    if (markedText_.empty() || cursor_ == 0) {
        return publish(false);
    }

    copyMarkedTextToRawInput();
    cursor_ = 0;
    return publish(true);
}

Snapshot TransliterationSession::moveEnd()
{
    if (markedText_.empty() || cursor_ >= markedText_.size()) {
        return publish(false);
    }

    copyMarkedTextToRawInput();
    cursor_ = markedText_.size();
    return publish(true);
}

Snapshot TransliterationSession::commit()
{
    if (markedText_.empty()) {
        return publish(false);
    }

    EngineString committedText = markedText_;
    rawInput_.clear();
    markedText_.clear();
    cursor_ = 0;

    return publish(true, std::move(committedText));
}

Snapshot TransliterationSession::cancel()
{
    if (rawInput_.empty() && markedText_.empty()) {
        return publish(false);
    }

    rawInput_.clear();
    markedText_.clear();
    cursor_ = 0;

    return publish(true);
}

const Snapshot& TransliterationSession::snapshot() const
{
    return snapshot_;
}

void TransliterationSession::rebuildMarkedText()
{
    markedText_ = ruleBook().transliterate(rawInput_);
}

void TransliterationSession::copyMarkedTextToRawInput()
{
    rawInput_ = markedText_;
}

Snapshot TransliterationSession::publish(bool changed, EngineString committedText)
{
    snapshot_.rawInput = rawInput_;
    snapshot_.markedText = markedText_;
    snapshot_.committedText = std::move(committedText);
    snapshot_.cursor = std::min(cursor_, markedText_.size());
    snapshot_.isComposing = !markedText_.empty();
    snapshot_.changed = changed;
    return snapshot_;
}

} // namespace bansh::core
