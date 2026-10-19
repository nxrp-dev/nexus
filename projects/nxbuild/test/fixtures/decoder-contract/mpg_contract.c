// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
/* Actual mpg123 adapter, deterministic codec API double for boundary/failure paths. */
#include "SoundDecoder_Internal.h"
#include "mpg123.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>
extern const Sound_DecoderFunctions __Sound_DecoderFunctions_MPG123;
struct mpg123_handle_struct {int fd;};
static ssize_t (*reader)(int,void*,size_t);
static off_t (*seeker)(int,off_t,int);
static int fail_realloc,seek_failed;
static size_t read_request;
static off_t last_frame;
void *__real_realloc(void*,size_t);
void *__wrap_realloc(void *p,size_t n) {if(fail_realloc){fail_realloc=0;return NULL;}return __real_realloc(p,n);}
void SoundDecoder_SetError(const char *s,...) {}
int mpg123_init(void){return MPG123_OK;}
void mpg123_exit(void){}
const char **mpg123_decoders(void){static const char *names[]={"test",NULL};return names;}
const char **mpg123_supported_decoders(void){return mpg123_decoders();}
mpg123_handle *mpg123_new(const char *name,int *err){return calloc(1,sizeof(mpg123_handle));}
void mpg123_delete(mpg123_handle *m){free(m);}
int mpg123_format_none(mpg123_handle *m){return MPG123_OK;}
int mpg123_format(mpg123_handle *m,long rate,int channels,int encoding){return MPG123_OK;}
void mpg123_rates(const long **rates,size_t *count){static const long r[]={48000};*rates=r;*count=1;}
int mpg123_replace_reader(mpg123_handle *m,ssize_t(*r)(int,void*,size_t),off_t(*s)(int,off_t,int)){reader=r;seeker=s;return MPG123_OK;}
int mpg123_open_fd(mpg123_handle *m,int fd){m->fd=fd;return MPG123_OK;}
int mpg123_scan(mpg123_handle *m){return MPG123_OK;}
int mpg123_getformat(mpg123_handle *m,long *rate,int *channels,int *encoding){*rate=48000;*channels=2;*encoding=MPG123_ENC_SIGNED_16;return MPG123_OK;}
off_t mpg123_tell(mpg123_handle *m){return (off_t)240000000000LL;}
off_t mpg123_seek(mpg123_handle *m,off_t frame,int whence){last_frame=frame;return seek_failed?-1:frame;}
int mpg123_close(mpg123_handle *m){return MPG123_OK;}
const char *mpg123_strerror(mpg123_handle *m){return "fixture error";}
const char *mpg123_plain_strerror(int err){return "fixture error";}
int mpg123_read(mpg123_handle *m,unsigned char *p,size_t size,size_t *done){memset(p,7,size);*done=size;return MPG123_DONE;}
static size_t read_stream(ALmixer_RWops *r,void *p,size_t size,size_t n){read_request=n;return ALMIXER_RWOPS_ERROR;}
static long seek_stream(ALmixer_RWops *r,long p,int whence){return p;}
int main(void)
{
 const Sound_DecoderFunctions *d=&__Sound_DecoderFunctions_MPG123;
 ALmixer_RWops rw={0};rw.read=read_stream;rw.seek=seek_stream;
 unsigned char buffer[8];Sound_SampleInternal internal={0};internal.rw=&rw;internal.buffer=buffer;internal.buffer_size=8;
 Sound_Sample sample={0};sample.opaque=&internal;
 assert(d->init());fail_realloc=1;assert(!d->open(&sample,"MP3"));assert(d->open(&sample,"MP3"));
 mpg123_handle *m=internal.decoder_private;
 assert(internal.total_time==5000000000LL);
 assert(reader(m->fd,buffer,8)==-1);
 assert(reader(m->fd,buffer,SIZE_MAX)==-1);
 assert(read_request==(sizeof(ssize_t)==8?(size_t)INT64_MAX:(size_t)INT32_MAX));
 assert(seeker(m->fd,123,SEEK_SET)==123);
 assert(d->read(&sample)==8);assert(sample.flags&SOUND_SAMPLEFLAG_EOF);
 assert(d->seek(&sample,5000000000ULL));assert(last_frame==240000000000LL);
 assert(!d->seek(&sample,SIZE_MAX));seek_failed=1;assert(!d->rewind(&sample));
 seek_failed=0;assert(d->rewind(&sample));d->close(&sample);d->quit();return 0;
}
