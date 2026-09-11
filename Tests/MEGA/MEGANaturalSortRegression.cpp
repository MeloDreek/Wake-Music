#include "../../LocalSDK/MEGASDK/src/apple_natural_sort.h"
#include <cassert>
#include <iostream>

int main()
{
    using mega::appleNaturalCompare;
    assert(appleNaturalCompare("track2", "track12") < 0);
    assert(appleNaturalCompare("track12", "track2") > 0);
    assert(appleNaturalCompare("音乐2", "音乐12") < 0);
    assert(appleNaturalCompare("0", "00") < 0);
    assert(appleNaturalCompare("same", "same") == 0);
    assert(appleNaturalCompare("", "") == 0);
    assert(appleNaturalCompare("", "a") < 0);
    assert(appleNaturalCompare("é", "e\xCC\x81") != 0);
    assert(appleNaturalCompare("a\xFF", "a\xFE") > 0);
    std::cout << "MEGA Apple natural-sort checks passed: 9\n";
}
