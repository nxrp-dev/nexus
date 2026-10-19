// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Exercises the actual SoundDecoder dispatcher using a deterministic test
 * decoder. No production decoder implementation is copied or modified. */
#include "SoundDecoder_Internal.h"
#include <stdlib.h>
#include <string.h>

static unsigned int decoder_closes;
static unsigned int stream_closes;
static int oversize_error;
static int no_progress;
static int fail_allocation;
void *__real_malloc(size_t);void *__real_calloc(size_t,size_t);void *__real_realloc(void*,size_t);
static int fail_now(void) { return fail_allocation>0 && --fail_allocation==0; }
void *__wrap_malloc(size_t n) {return fail_now()?NULL:__real_malloc(n);}
void *__wrap_calloc(size_t n,size_t z) {return fail_now()?NULL:__real_calloc(n,z);}
void *__wrap_realloc(void *p,size_t n) {return fail_now()?NULL:__real_realloc(p,n);}

static int test_init(void) { return 1; }
static void test_quit(void) {}
static int test_open(SoundDecoder_Sample *sample, const char *extension)
{
    (void)extension;
    sample->actual.format = AUDIO_U8;
    sample->actual.channels = 1;
    sample->actual.rate = 8000;
    sample->flags = SOUND_SAMPLEFLAG_CANSEEK;
    return 1;
}
static void test_close(SoundDecoder_Sample *sample)
{
    (void)sample;
    ++decoder_closes;
}
static size_t test_read(SoundDecoder_Sample *sample)
{
    if (no_progress) return 0;
    if (oversize_error) {
        sample->flags |= SOUND_SAMPLEFLAG_ERROR;
        /* Models the invalid unsigned error count emitted by the Ogg adapters,
         * using nine bytes instead of gigabytes to make the probe small. */
        return sample->buffer_size + 1;
    }
    memset(sample->buffer, 42, sample->buffer_size);
    sample->flags |= SOUND_SAMPLEFLAG_EOF;
    return sample->buffer_size;
}
static int test_rewind(SoundDecoder_Sample *sample)
{
    (void)sample;
    return 1;
}
static int test_seek(SoundDecoder_Sample *sample, size_t milliseconds)
{
    (void)sample; (void)milliseconds;
    return 1;
}
static const char *extensions[] = { "contract", NULL };
const SoundDecoder_DecoderFunctions __Sound_DecoderFunctions_WAV = {
    { extensions, "Interface test decoder", "Nexus", "" },
    test_init, test_quit, test_open, test_close, test_read, test_rewind, test_seek
};
static long stream_seek(ALmixer_RWops *stream, long offset, int whence)
{
    (void)stream; (void)whence;
    return offset;
}
static int stream_close(ALmixer_RWops *stream)
{
    ++stream_closes;
    free(stream);
    return 0;
}
int main(int argc, char **argv)
{
    if (argc != 2) return 2;
    if (!SoundDecoder_Init()) return 3;
    if (strcmp(argv[1], "allocation") == 0) {
        for(int n=1;n<=4;++n) {
            ALmixer_RWops *rw=calloc(1,sizeof(*rw)); rw->seek=stream_seek;rw->close=stream_close;
            unsigned before=stream_closes;
            fail_allocation=n;
            SoundDecoder_Sample *s=SoundDecoder_NewSample(rw,"contract",NULL,8);
            fail_allocation=0;
            if(s) return 10;
            if(stream_closes!=before+1) return 11;
        }
        if(decoder_closes!=1) return 12;
        SoundDecoder_Quit(); return 0;
    }
    ALmixer_RWops *stream = calloc(1, sizeof(*stream));
    if (!stream) return 4;
    stream->seek = stream_seek;
    stream->close = stream_close;
    SoundDecoder_Sample *sample = SoundDecoder_NewSample(stream, "contract",
        strcmp(argv[1],"format")==0 ? &(SoundDecoder_AudioInfo){AUDIO_S16SYS,2,48000} : NULL, 8);
    if (!sample) return 5;

    if (strcmp(argv[1], "quit") == 0) {
        SoundDecoder_Quit();
        fprintf(stderr, "decoder closes=%u, stream closes=%u; expected 1 each\n",
                decoder_closes, stream_closes);
        return decoder_closes != 1 || stream_closes != 1;
    }
    if (strcmp(argv[1], "zero-resize") == 0) {
        int result = SoundDecoder_SetBufferSize(sample, 0);
        fprintf(stderr, "zero resize result=%d, recorded size=%zu\n", result, sample->buffer_size);
        if (!result) {
            /* A rejected resize must leave the existing buffer usable. */
            memset(sample->buffer, 42, sample->buffer_size);
        }
    } else if (strcmp(argv[1], "error-count") == 0) {
        oversize_error = 1;
        if(SoundDecoder_DecodeAll(sample)!=0 || !(sample->flags&SOUND_SAMPLEFLAG_ERROR))return 13;
    } else if (strcmp(argv[1], "no-progress") == 0) {
        no_progress=1;
        if(SoundDecoder_DecodeAll(sample)!=0 || !(sample->flags&SOUND_SAMPLEFLAG_ERROR))return 14;
    } else if (strcmp(argv[1], "allocation-resize") == 0) {
        void *old=sample->buffer;
        fail_allocation=1;
        if(SoundDecoder_SetBufferSize(sample,16))return 15;
        fail_allocation=0;
        if(sample->buffer!=old || sample->buffer_size!=8)return 16;
        if(SoundDecoder_Decode(sample)!=8)return 17;
    } else if (strcmp(argv[1], "format") == 0) {
        if(sample->desired.format!=AUDIO_U8 || sample->desired.channels!=1 || sample->desired.rate!=8000)return 18;
        if(SoundDecoder_Decode(sample)!=8)return 19;
    } else if (strcmp(argv[1], "explicit-free") == 0) {
        if (SoundDecoder_Decode(sample) != 8) return 6;
    } else {
        return 2;
    }
    SoundDecoder_FreeSample(sample);
    SoundDecoder_Quit();
    fprintf(stderr, "decoder closes=%u, stream closes=%u; expected 1 each\n",
            decoder_closes, stream_closes);
    return decoder_closes != 1 || stream_closes != 1;
}
