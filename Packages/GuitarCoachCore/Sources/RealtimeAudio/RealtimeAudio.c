#include "RealtimeAudio.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

_Static_assert(ATOMIC_LONG_LOCK_FREE == 2 && ATOMIC_LLONG_LOCK_FREE == 2,
               "Audio callback counters must use lock-free atomics");

struct GCRing {
    uint32_t capacity, max_frames;
    float *samples;
    GCPacketInfo *packets;
    _Atomic uint64_t written, read, dropped;
};

GCRing *GCRingCreate(uint32_t capacity, uint32_t max_frames) {
    if (capacity < 2 || capacity > 4096 || !max_frames || max_frames > 65536) return NULL;
    GCRing *ring = calloc(1, sizeof(*ring));
    if (!ring) return NULL;
    ring->capacity = capacity; ring->max_frames = max_frames;
    atomic_init(&ring->written, 0); atomic_init(&ring->read, 0); atomic_init(&ring->dropped, 0);
    ring->samples = calloc((size_t)capacity * max_frames, sizeof(float));
    ring->packets = calloc(capacity, sizeof(GCPacketInfo));
    if (!ring->samples || !ring->packets) { GCRingDestroy(ring); return NULL; }
    return ring;
}

void GCRingDestroy(GCRing *ring) {
    if (!ring) return;
    free(ring->samples); free(ring->packets); free(ring);
}

bool GCRingWrite(GCRing *ring, const float *source, uint32_t frames, uint32_t stride, GCPacketInfo info) {
    if (!ring || !source || !stride || !frames) return false;
    uint64_t written = atomic_load_explicit(&ring->written, memory_order_relaxed);
    uint64_t read = atomic_load_explicit(&ring->read, memory_order_acquire);
    if (frames > ring->max_frames || written - read >= ring->capacity) {
        atomic_fetch_add_explicit(&ring->dropped, 1, memory_order_relaxed);
        return false;
    }
    uint32_t slot = written % ring->capacity;
    float *out = ring->samples + (size_t)slot * ring->max_frames;
    for (uint32_t i = 0; i < frames; ++i) out[i] = source[(size_t)i * stride];
    info.frame_count = frames;
    ring->packets[slot] = info;
    atomic_store_explicit(&ring->written, written + 1, memory_order_release);
    return true;
}

bool GCRingRead(GCRing *ring, float *destination, uint32_t max_frames, GCPacketInfo *info) {
    if (!ring || !destination || !info) return false;
    uint64_t read = atomic_load_explicit(&ring->read, memory_order_relaxed);
    uint64_t written = atomic_load_explicit(&ring->written, memory_order_acquire);
    if (read == written) return false;
    uint32_t slot = read % ring->capacity;
    GCPacketInfo packet = ring->packets[slot];
    // A small consumer buffer must not silently truncate or discard a packet.
    if (packet.frame_count > max_frames) return false;
    memcpy(destination, ring->samples + (size_t)slot * ring->max_frames, packet.frame_count * sizeof(float));
    *info = packet;
    atomic_store_explicit(&ring->read, read + 1, memory_order_release);
    return true;
}

uint64_t GCRingDropped(const GCRing *ring) {
    return ring ? atomic_load_explicit(&ring->dropped, memory_order_relaxed) : 0;
}

struct GCInput {
    AudioUnit unit;
    GCRing *ring;
    AudioBufferList buffers;
    uint32_t selected_channel, channels, max_frames;
    double sample_rate;
};

static OSStatus capture(void *context, AudioUnitRenderActionFlags *flags,
                        const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *unused) {
    GCInput *input = context;
    if (frames > input->max_frames) {
        atomic_fetch_add_explicit(&input->ring->dropped, 1, memory_order_relaxed);
        return kAudioUnitErr_TooManyFramesToProcess;
    }
    input->buffers.mBuffers[0].mDataByteSize = frames * input->channels * sizeof(float);
    OSStatus status = AudioUnitRender(input->unit, flags, time, 1, frames, &input->buffers);
    if (status != noErr) {
        atomic_fetch_add_explicit(&input->ring->dropped, 1, memory_order_relaxed);
        return status;
    }
    GCPacketInfo info = {
        .host_time = time->mHostTime, .sample_time = time->mSampleTime,
        .sample_rate = input->sample_rate, .frame_count = frames,
        .host_time_valid = (time->mFlags & kAudioTimeStampHostTimeValid) != 0,
        .sample_time_valid = (time->mFlags & kAudioTimeStampSampleTimeValid) != 0
    };
    const float *source = input->buffers.mBuffers[0].mData;
    GCRingWrite(input->ring, source + input->selected_channel, frames, input->channels, info);
    return noErr;
}

GCInput *GCInputCreate(uint32_t device_id, uint32_t channel, GCRing *ring, OSStatus *status) {
    if (!status) return NULL;
    *status = kAudio_ParamError;
    if (!ring) return NULL;
    GCInput *input = calloc(1, sizeof(*input));
    if (!input) { *status = kAudio_MemFullError; return NULL; }
    input->ring = ring; input->selected_channel = channel; input->max_frames = ring->max_frames;
    AudioComponentDescription description = {
        .componentType = kAudioUnitType_Output, .componentSubType = kAudioUnitSubType_HALOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple
    };
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    if (!component) { *status = kAudioUnitErr_FailedInitialization; goto failed; }
    *status = AudioComponentInstanceNew(component, &input->unit);
    if (*status) goto failed;
    UInt32 one = 1, zero = 0;
    *status = AudioUnitSetProperty(input->unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
    if (*status) goto failed;
    *status = AudioUnitSetProperty(input->unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &zero, sizeof(zero));
    if (*status) goto failed;
    *status = AudioUnitSetProperty(input->unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device_id, sizeof(device_id));
    if (*status) goto failed;
    AudioStreamBasicDescription format = {0}; UInt32 size = sizeof(format);
    *status = AudioUnitGetProperty(input->unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &format, &size);
    if (*status) goto failed;
    if (!format.mChannelsPerFrame || channel >= format.mChannelsPerFrame || format.mSampleRate <= 0 || format.mChannelsPerFrame > 256) {
        *status = kAudio_ParamError; goto failed;
    }
    input->channels = format.mChannelsPerFrame; input->sample_rate = format.mSampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    format.mBitsPerChannel = 32; format.mFramesPerPacket = 1;
    format.mBytesPerFrame = format.mBytesPerPacket = sizeof(float) * input->channels;
    *status = AudioUnitSetProperty(input->unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &format, sizeof(format));
    if (*status) goto failed;
    *status = AudioUnitSetProperty(input->unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &input->max_frames, sizeof(input->max_frames));
    if (*status) goto failed;
    input->buffers.mNumberBuffers = 1;
    input->buffers.mBuffers[0].mNumberChannels = input->channels;
    input->buffers.mBuffers[0].mDataByteSize = input->max_frames * format.mBytesPerFrame;
    input->buffers.mBuffers[0].mData = calloc(input->max_frames, format.mBytesPerFrame);
    if (!input->buffers.mBuffers[0].mData) { *status = kAudio_MemFullError; goto failed; }
    AURenderCallbackStruct callback = { .inputProc = capture, .inputProcRefCon = input };
    *status = AudioUnitSetProperty(input->unit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, sizeof(callback));
    if (*status) goto failed;
    *status = AudioUnitInitialize(input->unit);
    if (*status) goto failed;
    return input;
failed:
    GCInputDestroy(input);
    return NULL;
}

OSStatus GCInputStart(GCInput *input) { return input ? AudioOutputUnitStart(input->unit) : kAudio_ParamError; }
void GCInputStop(GCInput *input) { if (input && input->unit) AudioOutputUnitStop(input->unit); }
void GCInputDestroy(GCInput *input) {
    if (!input) return;
    if (input->unit) {
        AudioOutputUnitStop(input->unit); AudioUnitUninitialize(input->unit);
        AudioComponentInstanceDispose(input->unit);
    }
    free(input->buffers.mBuffers[0].mData); free(input);
}
double GCInputSampleRate(const GCInput *input) { return input ? input->sample_rate : 0; }
uint32_t GCInputChannelCount(const GCInput *input) { return input ? input->channels : 0; }
