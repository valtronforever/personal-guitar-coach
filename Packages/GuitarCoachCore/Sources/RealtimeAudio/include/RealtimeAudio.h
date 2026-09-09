#ifndef REALTIME_AUDIO_H
#define REALTIME_AUDIO_H
#include <stdbool.h>
#include <stdint.h>
#include <AudioToolbox/AudioToolbox.h>

typedef struct GCRing GCRing;
typedef struct GCInput GCInput;
typedef struct {
    uint64_t host_time;
    double sample_time;
    double sample_rate;
    uint32_t frame_count;
    bool host_time_valid;
    bool sample_time_valid;
} GCPacketInfo;

// Exactly one producer and one consumer. Allocate/destroy only while stopped.
GCRing *GCRingCreate(uint32_t capacity, uint32_t max_frames);
void GCRingDestroy(GCRing *ring);
bool GCRingWrite(GCRing *ring, const float *source, uint32_t frames,
                 uint32_t stride, GCPacketInfo info);
bool GCRingRead(GCRing *ring, float *destination, uint32_t max_frames, GCPacketInfo *info);
uint64_t GCRingDropped(const GCRing *ring);

// Input and ring must outlive the active render callback.
GCInput *GCInputCreate(uint32_t device_id, uint32_t channel_zero_based, GCRing *ring, OSStatus *status);
OSStatus GCInputStart(GCInput *input);
void GCInputStop(GCInput *input);
void GCInputDestroy(GCInput *input);
double GCInputSampleRate(const GCInput *input);
uint32_t GCInputChannelCount(const GCInput *input);
#endif
