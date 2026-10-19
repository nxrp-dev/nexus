// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Real Ogg adapter; deterministic Vorbis API double tests its callback contract. */
#include "SoundDecoder_Internal.h"
#ifdef TEST_VORBIS
#include <vorbis/vorbisfile.h>
#else
#include <ivorbisfile.h>
#endif
#include <assert.h>
#include <stdlib.h>
#include <string.h>
extern const Sound_DecoderFunctions __Sound_DecoderFunctions_OGG;
static ov_callbacks callbacks;
static void *source;
static int mode,calls,clears;
static long position;
static vorbis_info info;
static long seek_stream(ALmixer_RWops *s,long offset,int whence) { position=(whence==SEEK_CUR)?position+offset:offset; return position; }
static size_t read_stream(ALmixer_RWops *s,void *p,size_t size,size_t n) { return ALMIXER_RWOPS_ERROR; }
void SoundDecoder_SetError(const char *s,...) {}
#ifdef TEST_VORBIS
int ov_open_callbacks(void *data,OggVorbis_File *file,const char *initial,long ibytes,ov_callbacks cb)
#else
int ov_open_callbacks(void *data,OggVorbis_File *file,char *initial,long ibytes,ov_callbacks cb)
#endif
{ callbacks=cb; source=data; info.channels=1; info.rate=1000; return 0; }
vorbis_info *ov_info(OggVorbis_File *f,int link) {return &info;}
long ov_seekable(OggVorbis_File *f) {return 1;}
int ov_clear(OggVorbis_File *f) { ++clears; return callbacks.close_func(source); }
int ov_raw_seek(OggVorbis_File *f,ogg_int64_t pos) {return callbacks.seek_func(source,pos,SEEK_SET);}
#ifdef TEST_VORBIS
double ov_time_total(OggVorbis_File *f,int link) { return 5000000.; }
int ov_time_seek(OggVorbis_File *f,double time) { return 0; }
long ov_read(OggVorbis_File *f,char *p,int length,int big,int word,int sign,int *bitstream)
#else
ogg_int64_t ov_time_total(OggVorbis_File *f,int link) { return 5000000000LL; }
int ov_time_seek(OggVorbis_File *f,ogg_int64_t time) { assert(time>=0); return 0; }
long ov_read(OggVorbis_File *f,void *p,int length,int *bitstream)
#endif
{
    assert(length>0); ++calls;
    if(mode==0)return -3;
    if(mode==1) {if(calls==1) {memset(p,7,2);return 2;}return -3;}
    if(mode==2) {callbacks.read_func(p,1,length,source);return 0;}
    if(calls>1)return 0;
    memset(p,7,2);return 2;
}
int main(void)
{
    const Sound_DecoderFunctions *d=&__Sound_DecoderFunctions_OGG;
    unsigned char buffer[8];
    ALmixer_RWops rw={0}; rw.seek=seek_stream;rw.read=read_stream;
    Sound_SampleInternal internal={0};internal.rw=&rw;internal.buffer=buffer;internal.buffer_size=8;
    Sound_Sample sample={0}; sample.opaque=&internal;
    assert(d->init()); assert(d->open(&sample,"OGG"));
    assert(internal.total_time==5000000000LL);
    assert(callbacks.seek_func(source,123,SEEK_SET)==0); assert(position==123);
    assert(callbacks.tell_func(source)==123);
    for(mode=0;mode<4;++mode) {
        calls=0;sample.flags=0;
        size_t count=d->read(&sample);
        assert(count==(mode==1||mode==3?2:0));
        if(mode<3) {assert(sample.flags&SOUND_SAMPLEFLAG_ERROR);assert(!(sample.flags&SOUND_SAMPLEFLAG_EOF));}
        else assert(sample.flags&SOUND_SAMPLEFLAG_EOF);
    }
    internal.buffer_size=1;sample.flags=0;
    assert(d->read(&sample)==0); assert(sample.flags&SOUND_SAMPLEFLAG_ERROR);
    assert(d->rewind(&sample));
#ifndef TEST_VORBIS
    assert(!d->seek(&sample,SIZE_MAX));
#endif
    d->close(&sample);d->quit();assert(clears==1);return 0;
}
