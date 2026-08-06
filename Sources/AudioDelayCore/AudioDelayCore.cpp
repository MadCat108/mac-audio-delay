#include "AudioDelayCore.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <new>

struct ADDelayProcessor {
    explicit ADDelayProcessor(uint64_t frames)
        : delayFrames(frames),
          leftDelay(frames > 0 ? new (std::nothrow) float[frames]() : nullptr),
          rightDelay(frames > 0 ? new (std::nothrow) float[frames]() : nullptr) {}

    ~ADDelayProcessor() {
        delete[] leftDelay;
        delete[] rightDelay;
    }

    const uint64_t delayFrames;
    float *leftDelay;
    float *rightDelay;
    uint64_t position = 0;
    AudioObjectID deviceID = kAudioObjectUnknown;
    AudioDeviceIOProcID ioProcID = nullptr;
    std::atomic<float> leftInputPeak{0};
    std::atomic<float> rightInputPeak{0};
    std::atomic<float> leftPeak{0};
    std::atomic<float> rightPeak{0};
};

static UInt32 frameCount(const AudioBuffer& buffer) noexcept {
    if (buffer.mData == nullptr || buffer.mNumberChannels == 0) {
        return 0;
    }
    return buffer.mDataByteSize / (buffer.mNumberChannels * sizeof(Float32));
}

static void readStereoFrame(
    const AudioBufferList *input,
    UInt32 frame,
    float& left,
    float& right
) noexcept {
    left = 0;
    right = 0;
    if (input == nullptr || input->mNumberBuffers == 0) {
        return;
    }

    // A stereo mixdown tap is the final input stream in the private aggregate
    // device. Physical output devices normally contribute no input stream.
    const AudioBuffer& buffer = input->mBuffers[input->mNumberBuffers - 1];
    const UInt32 frames = frameCount(buffer);
    if (frame >= frames || buffer.mData == nullptr) {
        return;
    }

    const auto *samples = static_cast<const Float32 *>(buffer.mData);
    if (buffer.mNumberChannels == 1) {
        left = samples[frame];
        right = left;
        return;
    }

    const size_t offset = static_cast<size_t>(frame) * buffer.mNumberChannels;
    left = samples[offset];
    right = samples[offset + 1];
}

static void clearOutput(AudioBufferList *output) noexcept {
    if (output == nullptr) {
        return;
    }
    for (UInt32 bufferIndex = 0; bufferIndex < output->mNumberBuffers; ++bufferIndex) {
        AudioBuffer& buffer = output->mBuffers[bufferIndex];
        if (buffer.mData != nullptr) {
            std::memset(buffer.mData, 0, buffer.mDataByteSize);
        }
    }
}

static void writeStereoFrame(
    AudioBufferList *output,
    UInt32 frame,
    float left,
    float right
) noexcept {
    if (output == nullptr || output->mNumberBuffers == 0) {
        return;
    }

    UInt32 channelOffset = 0;
    for (UInt32 bufferIndex = 0; bufferIndex < output->mNumberBuffers; ++bufferIndex) {
        AudioBuffer& buffer = output->mBuffers[bufferIndex];
        const UInt32 frames = frameCount(buffer);
        if (frame >= frames || buffer.mData == nullptr) {
            channelOffset += buffer.mNumberChannels;
            continue;
        }

        auto *samples = static_cast<Float32 *>(buffer.mData);
        const size_t frameOffset = static_cast<size_t>(frame) * buffer.mNumberChannels;
        for (UInt32 channel = 0; channel < buffer.mNumberChannels; ++channel) {
            const UInt32 absoluteChannel = channelOffset + channel;
            if (output->mNumberBuffers == 1 && buffer.mNumberChannels == 1) {
                samples[frameOffset + channel] = (left + right) * 0.5f;
            } else if (absoluteChannel == 0) {
                samples[frameOffset + channel] = left;
            } else if (absoluteChannel == 1) {
                samples[frameOffset + channel] = right;
            }
        }
        channelOffset += buffer.mNumberChannels;
    }
}

static OSStatus delayIOProc(
    AudioObjectID,
    const AudioTimeStamp *,
    const AudioBufferList *input,
    const AudioTimeStamp *,
    AudioBufferList *output,
    const AudioTimeStamp *,
    void *clientData
) noexcept {
    auto *processor = static_cast<ADDelayProcessor *>(clientData);
    if (processor == nullptr || output == nullptr || output->mNumberBuffers == 0) {
        return noErr;
    }

    clearOutput(output);
    const UInt32 frames = frameCount(output->mBuffers[0]);
    float leftInputPeak = 0;
    float rightInputPeak = 0;
    float leftPeak = 0;
    float rightPeak = 0;

    for (UInt32 frame = 0; frame < frames; ++frame) {
        float inputLeft = 0;
        float inputRight = 0;
        readStereoFrame(input, frame, inputLeft, inputRight);
        leftInputPeak = std::max(leftInputPeak, std::abs(inputLeft));
        rightInputPeak = std::max(rightInputPeak, std::abs(inputRight));

        float outputLeft = inputLeft;
        float outputRight = inputRight;
        if (processor->delayFrames > 0) {
            outputLeft = processor->leftDelay[processor->position];
            outputRight = processor->rightDelay[processor->position];
            processor->leftDelay[processor->position] = inputLeft;
            processor->rightDelay[processor->position] = inputRight;
            processor->position = (processor->position + 1) % processor->delayFrames;
        }

        writeStereoFrame(output, frame, outputLeft, outputRight);
        leftPeak = std::max(leftPeak, std::abs(outputLeft));
        rightPeak = std::max(rightPeak, std::abs(outputRight));
    }

    processor->leftInputPeak.store(leftInputPeak, std::memory_order_relaxed);
    processor->rightInputPeak.store(rightInputPeak, std::memory_order_relaxed);
    processor->leftPeak.store(leftPeak, std::memory_order_relaxed);
    processor->rightPeak.store(rightPeak, std::memory_order_relaxed);
    return noErr;
}

ADDelayProcessor *ADDelayProcessorCreate(uint64_t delayFrames) {
    auto *processor = new (std::nothrow) ADDelayProcessor(delayFrames);
    if (processor == nullptr) {
        return nullptr;
    }
    if (delayFrames > 0 && (processor->leftDelay == nullptr || processor->rightDelay == nullptr)) {
        delete processor;
        return nullptr;
    }
    return processor;
}

void ADDelayProcessorDestroy(ADDelayProcessor *processor) {
    if (processor == nullptr) {
        return;
    }
    ADDelayProcessorStop(processor);
    delete processor;
}

OSStatus ADDelayProcessorStart(ADDelayProcessor *processor, AudioObjectID deviceID) {
    if (processor == nullptr || deviceID == kAudioObjectUnknown) {
        return kAudioHardwareBadObjectError;
    }
    if (processor->ioProcID != nullptr) {
        return kAudioHardwareIllegalOperationError;
    }

    AudioDeviceIOProcID ioProcID = nullptr;
    OSStatus status = AudioDeviceCreateIOProcID(deviceID, delayIOProc, processor, &ioProcID);
    if (status != noErr) {
        return status;
    }

    status = AudioDeviceStart(deviceID, ioProcID);
    if (status != noErr) {
        AudioDeviceDestroyIOProcID(deviceID, ioProcID);
        return status;
    }

    processor->deviceID = deviceID;
    processor->ioProcID = ioProcID;
    return noErr;
}

void ADDelayProcessorStop(ADDelayProcessor *processor) {
    if (processor == nullptr || processor->ioProcID == nullptr) {
        return;
    }

    AudioDeviceStop(processor->deviceID, processor->ioProcID);
    AudioDeviceDestroyIOProcID(processor->deviceID, processor->ioProcID);
    processor->ioProcID = nullptr;
    processor->deviceID = kAudioObjectUnknown;
    processor->leftInputPeak.store(0, std::memory_order_relaxed);
    processor->rightInputPeak.store(0, std::memory_order_relaxed);
    processor->leftPeak.store(0, std::memory_order_relaxed);
    processor->rightPeak.store(0, std::memory_order_relaxed);
}

void ADDelayProcessorGetPeaks(
    const ADDelayProcessor *processor,
    float *left,
    float *right
) {
    if (left != nullptr) {
        *left = processor == nullptr ? 0 : processor->leftPeak.load(std::memory_order_relaxed);
    }
    if (right != nullptr) {
        *right = processor == nullptr ? 0 : processor->rightPeak.load(std::memory_order_relaxed);
    }
}

void ADDelayProcessorGetInputPeaks(
    const ADDelayProcessor *processor,
    float *left,
    float *right
) {
    if (left != nullptr) {
        *left = processor == nullptr ? 0 : processor->leftInputPeak.load(std::memory_order_relaxed);
    }
    if (right != nullptr) {
        *right = processor == nullptr ? 0 : processor->rightInputPeak.load(std::memory_order_relaxed);
    }
}