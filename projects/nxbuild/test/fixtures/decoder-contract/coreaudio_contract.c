// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Compiles the actual CoreAudio adapter against a deterministic platform API double.
 * This is not a native Apple ABI/runtime test. */
#include "SoundDecoder_Internal.h"
#include <AudioToolbox/AudioToolbox.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
extern const Sound_DecoderFunctions __Sound_DecoderFunctions_CoreAudio;
extern OSStatus CoreAudio_ReadCallback(void *,SInt64,UInt32,void *,UInt32 *);
static int fail_alloc,fail_api,files,wrappers,seek_failed,read_calls;
static AudioStreamBasicDescription output;
void *__real_malloc(size_t);
void *__wrap_malloc(size_t size) { return fail_alloc>0 && --fail_alloc==0?NULL:__real_malloc(size); }
void SoundDecoder_SetError(const char *s,...) {}
int SoundDecoder_strcasecmp(const char *a,const char *b) {return strcasecmp(a,b);}
ALenum alGetEnumValue(const ALchar *name) {return 0;}
OSStatus AudioFileOpenWithCallbacks(void *p,OSStatus(*r)(void *,SInt64,UInt32,void *,UInt32 *),void *w,SInt64(*s)(void *),void *z,AudioFileTypeID type,AudioFileID *f)
{if(fail_api==1)return -1;*f=(void *)1;++files;return 0;}
OSStatus AudioFileClose(AudioFileID f) {assert(f==(void*)1);--files;return 0;}
OSStatus AudioFileGetProperty(AudioFileID f,UInt32 key,UInt32 *size,void *p)
{
 if(fail_api==2)return -1;
 if(key==kAudioFilePropertyDataFormat) {AudioStreamBasicDescription *d=p;memset(d,0,sizeof(*d));d->mSampleRate=48000;d->mChannelsPerFrame=1;d->mBitsPerChannel=16;}
 else *(Float64*)p=5000000.;
 return 0;
}
OSStatus ExtAudioFileWrapAudioFileID(AudioFileID f,bool b,ExtAudioFileRef *ref) {if(fail_api==3)return -1;*ref=(void *)2;++wrappers;return 0;}
OSStatus ExtAudioFileDispose(ExtAudioFileRef ref) {assert(ref==(void*)2);--wrappers;return 0;}
OSStatus ExtAudioFileSetProperty(ExtAudioFileRef ref,UInt32 k,UInt32 size,const void *p) {output=*(const AudioStreamBasicDescription*)p;return fail_api==4?-1:0;}
OSStatus ExtAudioFileRead(ExtAudioFileRef ref,UInt32 *frames,AudioBufferList *buffers)
{++read_calls;assert(*frames>0);assert(buffers->mBuffers[0].mDataByteSize==*frames*output.mBytesPerFrame);*frames=0;return 0;}
OSStatus ExtAudioFileSeek(ExtAudioFileRef ref,SInt64 frame) {assert(frame>=0);return seek_failed?-1:0;}
static long seek_stream(ALmixer_RWops *s,long pos,int whence) {return seek_failed?-1:pos;}
static size_t read_stream(ALmixer_RWops *s,void *p,size_t size,size_t count) {return ALMIXER_RWOPS_ERROR;}
int main(void)
{
 const Sound_DecoderFunctions *d=&__Sound_DecoderFunctions_CoreAudio;
 ALmixer_RWops rw={0};rw.seek=seek_stream;rw.read=read_stream;
 Sound_SampleInternal internal={0};internal.rw=&rw;
 Sound_Sample sample={0};sample.opaque=&internal;sample.desired.format=AUDIO_U8;
 for(int n=1;n<=3;++n) {fail_alloc=n;assert(!d->open(&sample,"WAV"));fail_alloc=0;assert(files==0&&wrappers==0&&internal.decoder_private==NULL);}
 for(int n=1;n<=4;++n) {fail_api=n;assert(!d->open(&sample,"WAV"));assert(files==0&&wrappers==0&&internal.decoder_private==NULL);}fail_api=0;
 assert(d->init());assert(d->open(&sample,"WAV"));assert(output.mBitsPerChannel==8);assert(internal.total_time==5000000000LL);
 char buffer[8];internal.buffer=buffer;internal.buffer_size=(size_t)UINT32_MAX+16;
 assert(d->read(&sample)==0);assert(read_calls==1);assert(sample.flags&SOUND_SAMPLEFLAG_EOF);
 seek_failed=1;assert(!d->seek(&sample,1));assert(!d->rewind(&sample));
 UInt32 count=99;assert(CoreAudio_ReadCallback(&rw,0,8,buffer,&count)!=0&&count==0);
 seek_failed=0;assert(CoreAudio_ReadCallback(&rw,0,8,buffer,&count)!=0&&count==0);
 assert(!d->seek(&sample,SIZE_MAX));assert(d->seek(&sample,1000));assert(d->rewind(&sample));
 d->close(&sample);d->quit();assert(files==0&&wrappers==0);return 0;
}
