// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
#include "SoundDecoder_Internal.h"
#include "config.h"
#include <assert.h>
#include <unistd.h>
int main(void)
{
    uint64_t frames;
    assert(SoundDecoder_MillisecondsToFrames(1,44100,INT64_MAX,&frames)&&frames==44);
    assert(SoundDecoder_MillisecondsToFrames(5000000000ULL,48000,INT64_MAX,&frames)&&frames==240000000000ULL);
    assert(!SoundDecoder_MillisecondsToFrames(SIZE_MAX,UINT32_MAX,INT64_MAX,&frames));
    assert(!SoundDecoder_MillisecondsToFrames(1,0,INT64_MAX,&frames));
    assert(SoundDecoder_DurationFrom100ns(INT64_MAX)==922337203685478LL);
    assert(SoundDecoder_DurationFrom100ns(4999)==0);
    assert(SoundDecoder_DurationFrom100ns(5000)==1);
    assert(SoundDecoder_DurationFrom100ns(-1)==-1);
    assert(SIZEOF_LONG==sizeof(long));assert(SIZEOF_OFF_T==sizeof(off_t));
    assert(SIZEOF_SIZE_T==sizeof(size_t));assert(SIZEOF_SSIZE_T==sizeof(ssize_t));
    ALmixer_RWops *rw=ALmixer_RWFromFile("/dev/null","wb");assert(rw);
    char b;assert(ALmixer_RWread(rw,&b,1,1)==ALMIXER_RWOPS_ERROR);
    assert(ALmixer_RWread(rw,&b,0,1)==0);rw->close(rw);
    rw=ALmixer_RWFromFile("/dev/null","rb");assert(rw);
    assert(rw->write(rw,&b,1,1)==ALMIXER_RWOPS_ERROR);rw->close(rw);
    return 0;
}
