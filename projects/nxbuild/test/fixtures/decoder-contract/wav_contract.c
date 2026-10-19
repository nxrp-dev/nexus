// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Runs the actual WAV decoder and dispatcher against small, explicit RIFF data. */
#include "SoundDecoder_Internal.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>
static void word(FILE *f, unsigned value) { fputc(value, f); fputc(value >> 8, f); }
static void dword(FILE *f, uint32_t value) { word(f,value); word(f,value >> 16); }
static SoundDecoder_Sample *make_wave(int adpcm, size_t buffer, int bad_rate, int odd_chunk)
{
    FILE *f=tmpfile(); assert(f);
    fwrite("RIFF",1,4,f); dword(f,100); fwrite("WAVE",1,4,f);
    if(odd_chunk) { fwrite("JUNK",1,4,f); dword(f,1); word(f,42); }
    fwrite("fmt ",1,4,f); dword(f,adpcm?26:16);
    word(f,adpcm?2:1); word(f,1); dword(f,1000); dword(f,bad_rate?0:(adpcm?2000:1000));
    word(f,adpcm?8:1); word(f,adpcm?4:8);
    if(adpcm) { word(f,8); word(f,4); word(f,1); word(f,256); word(f,0); }
    fwrite("data",1,4,f); dword(f,adpcm?16:8);
    if(adpcm) { for(int i=0;i<2;++i) { fputc(0,f); word(f,16); word(f,20+i); word(f,10+i); fputc(0,f); } }
    else { for(int i=0;i<8;++i)fputc(40+i,f); }
    rewind(f);
    return SoundDecoder_NewSample(ALmixer_RWFromFP(f,1),"WAV",NULL,buffer);
}
static size_t io_error(ALmixer_RWops *rw,void *p,size_t size,size_t n) { return ALMIXER_RWOPS_ERROR; }
int main(int argc,char **argv)
{
    assert(argc==2); assert(SoundDecoder_Init());
    if(!strcmp(argv[1],"wav-pcm")) {
        SoundDecoder_Sample *s=make_wave(0,3,0,1); assert(s);
        assert(SoundDecoder_DecodeAll(s)==8); assert(!memcmp(s->buffer,"()*+,-./",8));
        assert(SoundDecoder_Seek(s,3)); assert(SoundDecoder_Decode(s)==5);
        assert(((unsigned char *)s->buffer)[0]==43);
        assert(!SoundDecoder_Seek(s,SIZE_MAX));
        assert(SoundDecoder_Rewind(s)); assert(SoundDecoder_Decode(s)==8);
        assert(SoundDecoder_Seek(s,8)); assert(SoundDecoder_Decode(s)==0);
        assert(s->flags&SOUND_SAMPLEFLAG_EOF); SoundDecoder_FreeSample(s);
    } else if(!strcmp(argv[1],"wav-errors")) {
        assert(make_wave(0,8,1,0)==NULL);
        SoundDecoder_Sample *s=make_wave(0,8,0,0); assert(s);
        ((Sound_SampleInternal*)s->opaque)->rw->read=io_error;
        assert(SoundDecoder_Decode(s)==0); assert(s->flags&SOUND_SAMPLEFLAG_ERROR);
        SoundDecoder_FreeSample(s);
    } else if(!strcmp(argv[1],"wav-adpcm")) {
        SoundDecoder_Sample *s=make_wave(1,16,0,0); assert(s);
        assert(SoundDecoder_DecodeAll(s)==16);
        unsigned char expected[16]; memcpy(expected,s->buffer,16);
        for(size_t frame=0;frame<=8;++frame) {
            assert(SoundDecoder_Seek(s,frame));
            assert(SoundDecoder_DecodeAll(s)==16-frame*2);
            if(frame<8) assert(!memcmp(s->buffer,expected+frame*2,16-frame*2));
        }
        SoundDecoder_FreeSample(s);
        s=make_wave(1,1,0,0); assert(s);
        assert(SoundDecoder_Decode(s)==0); assert(s->flags&SOUND_SAMPLEFLAG_ERROR);
        SoundDecoder_FreeSample(s);
        s=make_wave(1,3,0,0); assert(s); assert(SoundDecoder_DecodeAll(s)==16);
        assert(!memcmp(s->buffer,expected,16)); SoundDecoder_FreeSample(s);
    } else return 2;
    SoundDecoder_Quit(); return 0;
}
