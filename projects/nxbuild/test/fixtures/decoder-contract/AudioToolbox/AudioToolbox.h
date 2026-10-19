/* Test double only: validates the actual adapter on Linux; not an Apple SDK. */
#ifndef TEST_AUDIO_TOOLBOX_H
#define TEST_AUDIO_TOOLBOX_H
#include <stdint.h>
#include <stdbool.h>
typedef int32_t OSStatus;
typedef int64_t SInt64;
typedef int32_t SInt32;
typedef uint32_t UInt32;
typedef uint8_t UInt8;
typedef double Float64;
typedef uint32_t AudioFileTypeID;
typedef void *AudioFileID;
typedef void *ExtAudioFileRef;
typedef struct { double mSampleRate; UInt32 mFormatID,mFormatFlags,mBytesPerPacket,mFramesPerPacket,mBytesPerFrame,mChannelsPerFrame,mBitsPerChannel,mReserved; } AudioStreamBasicDescription;
typedef struct {UInt32 mNumberChannels,mDataByteSize;void *mData;} AudioBuffer;
typedef struct {UInt32 mNumberBuffers;AudioBuffer mBuffers[1];} AudioBufferList;
enum {noErr=0,kAudioFile3GP2Type=1,kAudioFile3GPType=2,kAudioFileAAC_ADTSType=4,kAudioFileAC3Type=8,kAudioFileAIFCType=16,kAudioFileAIFFType=32,kAudioFileAMRType=64,kAudioFileCAFType=128,kAudioFileM4AType=256,kAudioFileMP1Type=512,kAudioFileMP2Type=1024,kAudioFileMP3Type=2048,kAudioFileMPEG4Type=4096,kAudioFileNextType=8192,kAudioFilePropertyDataFormat=16384,kAudioFilePropertyEstimatedDuration=32768,kAudioFileSoundDesigner2Type=65536,kAudioFileUnspecifiedError=131072,kAudioFileWAVEType=262144,kAudioFormatFlagIsBigEndian=524288,kAudioFormatFlagIsPacked=1048576,kAudioFormatFlagIsSignedInteger=2097152,kAudioFormatFlagsNativeEndian=4194304,kAudioFormatLinearPCM=8388608,kExtAudioFileProperty_ClientDataFormat=16777216};
OSStatus AudioFileOpenWithCallbacks(void *,OSStatus(*)(void *,SInt64,UInt32,void *,UInt32 *),void *,SInt64(*)(void *),void *,AudioFileTypeID,AudioFileID *);
OSStatus AudioFileClose(AudioFileID);
OSStatus AudioFileGetProperty(AudioFileID,UInt32,UInt32 *,void *);
OSStatus ExtAudioFileWrapAudioFileID(AudioFileID,bool,ExtAudioFileRef *);
OSStatus ExtAudioFileSetProperty(ExtAudioFileRef,UInt32,UInt32,const void *);
OSStatus ExtAudioFileDispose(ExtAudioFileRef);
OSStatus ExtAudioFileRead(ExtAudioFileRef,UInt32 *,AudioBufferList *);
OSStatus ExtAudioFileSeek(ExtAudioFileRef,SInt64);
#endif
