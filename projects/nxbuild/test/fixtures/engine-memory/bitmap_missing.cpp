// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
// Call the real bitmap loader with a missing file; UBSan diagnoses falling
// through its non-void function instead of returning a null image.
#include "Core/Rtt_Types.h"
#include "Rtt_BitmapUtils.h"
#include <cstdlib>

int main(int argc, char** argv)
{
    if (argc != 2) return 2;
    int width = 0;
    int height = 0;
    Rtt::PlatformBitmap::Format format{};
    auto* pixels = bitmapUtil::loadBMP(argv[1], width, height, format);
    if (pixels)
    {
        std::free(pixels);
        return 1;
    }
    return 0;
}
