/*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*/

#include <array>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "bzlib.h"

extern "C" void bz_internal_error(int ACode)
{
    std::fprintf(stderr, "bzip2 internal error: %d\n", ACode);
    std::exit(1);
}

int main()
{
    static_assert(sizeof(void *) == 8, "This fixture verifies the Win64 build.");
    std::array<char, 4096> lSource{};
    std::array<char, 5000> lCompressed{};
    std::array<char, 4096> lRestored{};
    for (std::size_t lIndex = 0; lIndex < lSource.size(); ++lIndex)
        lSource[lIndex] = static_cast<char>('A' + lIndex % 23);

    auto lCompressedSize = static_cast<unsigned int>(lCompressed.size());
    int lStatus = BZ2_bzBuffToBuffCompress(lCompressed.data(), &lCompressedSize,
        lSource.data(), static_cast<unsigned int>(lSource.size()), 9, 0, 30);
    if (lStatus != BZ_OK || lCompressedSize >= lSource.size()) {
        std::fprintf(stderr, "Compression failed: status=%d, bytes=%u\n",
            lStatus, lCompressedSize);
        return 1;
    }

    auto lRestoredSize = static_cast<unsigned int>(lRestored.size());
    lStatus = BZ2_bzBuffToBuffDecompress(lRestored.data(), &lRestoredSize,
        lCompressed.data(), lCompressedSize, 0, 0);
    if (lStatus != BZ_OK || lRestoredSize != lSource.size() ||
        std::memcmp(lSource.data(), lRestored.data(), lSource.size()) != 0) {
        std::fprintf(stderr, "Decompression failed: status=%d, bytes=%u\n",
            lStatus, lRestoredSize);
        return 1;
    }

    std::printf("PASS: Win64 Abbrevia bzip2; LLVM C objects + C++17 + LLD; "
        "%zu -> %u -> %u bytes, restored bytes identical; bzip2 %s\n",
        lSource.size(), lCompressedSize, lRestoredSize, BZ2_bzlibVersion());
    return 0;
}
