#ifndef AUDIO_DELAY_CORE_H
#define AUDIO_DELAY_CORE_H

#include <CoreAudio/CoreAudio.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ADDelayProcessor ADDelayProcessor;

ADDelayProcessor *ADDelayProcessorCreate(uint64_t delayFrames);
void ADDelayProcessorDestroy(ADDelayProcessor *processor);

OSStatus ADDelayProcessorStart(
    ADDelayProcessor *processor,
    AudioObjectID deviceID
);
void ADDelayProcessorStop(ADDelayProcessor *processor);

void ADDelayProcessorGetPeaks(
    const ADDelayProcessor *processor,
    float *left,
    float *right
);

void ADDelayProcessorGetInputPeaks(
    const ADDelayProcessor *processor,
    float *left,
    float *right
);

#ifdef __cplusplus
}
#endif

#endif