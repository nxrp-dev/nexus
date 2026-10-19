// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Actual mixer/dispatcher, deterministic short-read decoder and OpenAL null driver. */
#include "ALmixer.h"
#include "SoundDecoder_Internal.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
static int reads,closes;
static int init(void){return 1;}
static void quit(void){}
static int open_sample(Sound_Sample *s,const char *ext){s->actual.format=AUDIO_S16SYS;s->actual.channels=1;s->actual.rate=8000;s->flags=SOUND_SAMPLEFLAG_CANSEEK;return 1;}
static void close_sample(Sound_Sample *s){}
static size_t read_sample(Sound_Sample *s){size_t n=reads++?2:6;memset(s->buffer,0,n);s->flags|=reads==1?SOUND_SAMPLEFLAG_EAGAIN:SOUND_SAMPLEFLAG_EOF;return n;}
static int rewind_sample(Sound_Sample *s){reads=0;return 1;}
static int seek_sample(Sound_Sample *s,size_t ms){return 1;}
static const char *extensions[]={"contract",NULL};
const Sound_DecoderFunctions __Sound_DecoderFunctions_WAV={{extensions,"test","Nexus",""},init,quit,open_sample,close_sample,read_sample,rewind_sample,seek_sample};
static long seek_stream(ALmixer_RWops *s,long pos,int whence){return pos;}
static int close_stream(ALmixer_RWops *s){++closes;free(s);return 0;}
int main(void)
{
 assert(ALmixer_Init(8000,1,0));
 ALmixer_RWops *rw=calloc(1,sizeof(*rw));assert(rw);rw->seek=seek_stream;rw->close=close_stream;
 ALmixer_Data *data=ALmixer_LoadSample_RW(rw,"contract",8,AL_FALSE,2,1,1,0);
 if(!data){fprintf(stderr,"mixer load: %s\n",ALmixer_GetError());return 1;}
 /* A short first read is not permission to discard it and treat the tail as the entire sound. */
 assert(!ALmixer_IsPredecoded(data));
 ALmixer_FreeData(data);ALmixer_Quit();assert(closes==1);return 0;
}
