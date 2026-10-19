// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Uses the actual engine's compiled Tremor/mpg123 implementations and existing
 * nexus-lab audio assets. No codec API doubles are linked in this test. */
#include "SoundDecoder_Internal.h"
#include <assert.h>
#include <string.h>
#include <stdlib.h>
int main(int argc,char **argv)
{
 assert(argc==4);assert(SoundDecoder_Init());
 for(int i=1;i<argc;++i) {
    Sound_Sample *s=SoundDecoder_NewSampleFromFile(argv[i],NULL,4096);
    if(!s){fprintf(stderr,"open %s: %s\n",argv[i],SoundDecoder_GetError());return 1;}
    size_t count=SoundDecoder_Decode(s);assert(count>0&&count<=4096);assert(!(s->flags&SOUND_SAMPLEFLAG_ERROR));
    unsigned char expected[4096];memcpy(expected,s->buffer,count);
    assert(SoundDecoder_GetDuration(s)>0);
    assert(SoundDecoder_Rewind(s));assert(SoundDecoder_Decode(s)==count);assert(!memcmp(s->buffer,expected,count));
    assert(SoundDecoder_Seek(s,0));assert(SoundDecoder_Decode(s)==count);assert(!memcmp(s->buffer,expected,count));
    if(i==2) {assert(SoundDecoder_Rewind(s));assert(SoundDecoder_DecodeAll(s)>0);assert(s->flags&SOUND_SAMPLEFLAG_EOF);assert(!(s->flags&SOUND_SAMPLEFLAG_ERROR));}
    fprintf(stderr,"decoded/replayed/seeking: %s; format %u, channels %u, rate %u\n",argv[i],s->actual.format,s->actual.channels,s->actual.rate);
    SoundDecoder_FreeSample(s);
 }
 SoundDecoder_Quit();return 0;
}
