// Wake Music Apple compatibility adapter. Uses only public CoreFoundation APIs.
#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <string_view>

namespace mega {
inline int appleNaturalCompare(std::string_view lhs, std::string_view rhs)
{
    const auto makeString = [](std::string_view value) {
        return CFStringCreateWithBytes(kCFAllocatorDefault,
                                       reinterpret_cast<const UInt8*>(value.data()),
                                       static_cast<CFIndex>(value.size()),
                                       kCFStringEncodingUTF8, false);
    };
    CFStringRef left = makeString(lhs);
    CFStringRef right = makeString(rhs);
    int result = 0;
    if (left && right)
    {
        CFLocaleRef locale = CFLocaleCreate(kCFAllocatorDefault, CFSTR("en_US"));
        result = static_cast<int>(CFStringCompareWithOptionsAndLocale(
            left, right, CFRangeMake(0, CFStringGetLength(left)),
            kCFCompareNumerically | kCFCompareNonliteral, locale));
        if (locale) CFRelease(locale);
    }
    if (left) CFRelease(left);
    if (right) CFRelease(right);
    // Stable byte ordering for equivalent spellings / numeric padding, or invalid UTF-8.
    return result == 0 ? lhs.compare(rhs) : result;
}
}
