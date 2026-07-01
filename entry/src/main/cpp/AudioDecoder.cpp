/*
 * AudioDecoder.cpp - Native audio decoding using OH_AudioCodec (API 11+).
 *
 * Supported formats: AAC, MP3 (MPEG), FLAC, Vorbis, Opus, AMR, G711mu, APE.
 *
 * Decoding pipeline:
 *   1. Open input file → detect MIME type from extension
 *   2. Create OH_AudioCodec decoder by MIME
 *   3. Register async callbacks (OnInputBufferAvailable, OnOutputBufferAvailable)
 *   4. Configure → Prepare → Start
 *   5. Feed encoded data on OnInputBufferAvailable, receive PCM on OnOutputBufferAvailable
 *   6. Accumulate PCM to 640-byte chunks → deliver via ThreadSafeFunction to ArkTS
 *   7. On EOS → signal completion → stop
 *
 * CMake dependencies:
 *   target_link_libraries(... libnative_media_codecbase.so libnative_media_core.so
 *                            libnative_media_acodec.so libace_napi.z.so)
 */

#include "AudioDecoder.h"

#include <condition_variable>
#include <cstring>
#include <hilog/log.h>

#include <multimedia/player_framework/native_avcodec_audiocodec.h>
#include <multimedia/player_framework/native_avcodec_base.h>
#include <multimedia/player_framework/native_avbuffer.h>
#include <multimedia/player_framework/native_avformat.h>
#include <napi/native_api.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0001
#define LOG_TAG "[AudioDecoder:Native]"

// ────────────────────────────────────────────────────────────
// Helper: NAPI ThreadSafeFunction call payload
// ────────────────────────────────────────────────────────────

struct PcmChunkPayload {
    uint8_t *data;
    int32_t size;
};

// ────────────────────────────────────────────────────────────
// MIME type mapping from file extension
// ────────────────────────────────────────────────────────────

std::string AudioDecoder::GetMimeFromPath(const std::string &path) {
    std::string lower = path;
    // Convert to lowercase for the extension portion
    size_t dot = lower.rfind('.');
    if (dot == std::string::npos) {
        return OH_AVCODEC_MIMETYPE_AUDIO_MPEG; // default to MP3
    }
    std::string ext = lower.substr(dot);
    
    if (ext == ".aac" || ext == ".m4a") return OH_AVCODEC_MIMETYPE_AUDIO_AAC;
    if (ext == ".mp3") return OH_AVCODEC_MIMETYPE_AUDIO_MPEG;
    if (ext == ".flac") return OH_AVCODEC_MIMETYPE_AUDIO_FLAC;
    if (ext == ".ogg") return OH_AVCODEC_MIMETYPE_AUDIO_VORBIS;
    if (ext == ".opus") return OH_AVCODEC_MIMETYPE_AUDIO_OPUS;
    if (ext == ".amr") return OH_AVCODEC_MIMETYPE_AUDIO_AMR_NB;
    if (ext == ".wav") return OH_AVCODEC_MIMETYPE_AUDIO_MPEG; // WAV is raw PCM, treat as MP3 fallback
    
    // Video files: need demuxing first, but OH_AudioCodec only decodes raw encoded
    // audio elementary streams. For video files, the caller should demux first.
    // For now, default to MPEG.
    return OH_AVCODEC_MIMETYPE_AUDIO_MPEG;
}

// ────────────────────────────────────────────────────────────
// Constructor / Destructor
// ────────────────────────────────────────────────────────────

AudioDecoder::AudioDecoder() = default;

AudioDecoder::~AudioDecoder() {
    Stop();
}

// ────────────────────────────────────────────────────────────
// ThreadSafeFunction callbacks for delivering data/errors to ArkTS
// ────────────────────────────────────────────────────────────

static void TsfnPcmCallback(napi_env env, napi_value jsCallback,
                             void *context, void *data) {
    if (data == nullptr) return;
    
    PcmChunkPayload *payload = static_cast<PcmChunkPayload *>(data);
    
    // Create an ArrayBuffer from the PCM data
    napi_value arrayBuffer;
    napi_status status = napi_create_external_arraybuffer(
        env, payload->data, payload->size,
        [](napi_env env, void *finalizeData, void *finalizeHint) {
            delete[] static_cast<uint8_t *>(finalizeData);
        },
        nullptr, &arrayBuffer);
    
    if (status != napi_ok) {
        OH_LOG_ERROR(LOG_APP, "TsfnPcmCallback: failed to create ArrayBuffer");
        delete[] payload->data;
        delete payload;
        return;
    }
    
    // Call the ArkTS callback with the ArrayBuffer
    napi_value global;
    napi_get_global(env, &global);
    napi_value result;
    status = napi_call_function(env, global, jsCallback, 1, &arrayBuffer, &result);
    
    if (status != napi_ok) {
        OH_LOG_ERROR(LOG_APP, "TsfnPcmCallback: failed to call JS callback");
    }
    
    delete payload;
}

// ────────────────────────────────────────────────────────────
// Deliver PCM chunk to ArkTS via ThreadSafeFunction
// ────────────────────────────────────────────────────────────

void AudioDecoder::DeliverPcmChunk(const uint8_t *data, int32_t size) {
    if (tsfn_ == nullptr || size <= 0) return;
    
    // Copy the PCM data to a heap buffer (owned by the payload)
    uint8_t *copy = new uint8_t[size];
    memcpy(copy, data, size);
    
    PcmChunkPayload *payload = new PcmChunkPayload{copy, size};
    
    napi_status status = napi_call_threadsafe_function(tsfn_, payload, napi_tsfn_nonblocking);
    if (status != napi_ok) {
        OH_LOG_WARN(LOG_APP, "DeliverPcmChunk: tsfn call failed, dropping chunk");
        delete[] copy;
        delete payload;
    }
}

// ────────────────────────────────────────────────────────────
// Init: set up the decoder with file path and tsfn
// ────────────────────────────────────────────────────────────

int32_t AudioDecoder::Init(napi_env env, const std::string &filePath,
                           napi_threadsafe_function tsfn) {
    env_ = env;
    filePath_ = filePath;
    tsfn_ = tsfn;
    mimeType_ = GetMimeFromPath(filePath_);
    
    OH_LOG_INFO(LOG_APP, "AudioDecoder::Init path=%{public}s mime=%{public}s",
                filePath_.c_str(), mimeType_.c_str());
    
    // Open input file
    inputFile_.open(filePath_, std::ios::in | std::ios::binary);
    if (!inputFile_.is_open()) {
        OH_LOG_ERROR(LOG_APP, "Failed to open input file: %{public}s", filePath_.c_str());
        return -1;
    }
    
    // Create the decoder
    int32_t ret = CreateDecoder();
    if (ret != 0) {
        inputFile_.close();
        return ret;
    }
    
    return 0;
}

// ────────────────────────────────────────────────────────────
// Create the OH_AudioCodec decoder instance
// ────────────────────────────────────────────────────────────

int32_t AudioDecoder::CreateDecoder() {
    // Create decoder by MIME type (isEncoder = false for decoder)
    codec_ = OH_AudioCodec_CreateByMime(mimeType_.c_str(), false);
    if (codec_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "OH_AudioCodec_CreateByMime failed for %{public}s",
                     mimeType_.c_str());
        return -2;
    }
    
    OH_LOG_INFO(LOG_APP, "OH_AudioCodec created successfully for %{public}s",
                mimeType_.c_str());
    
    // Register async callbacks
    OH_AVCodecCallback callbacks;
    callbacks.onError = OnError;
    callbacks.onStreamChanged = OnOutputFormatChanged;
    callbacks.onNeedInputBuffer = OnInputBufferAvailable;
    callbacks.onNewOutputBuffer = OnOutputBufferAvailable;
    
    int32_t ret = OH_AudioCodec_RegisterCallback(codec_, callbacks, this);
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "OH_AudioCodec_RegisterCallback failed: %{public}d", ret);
        OH_AudioCodec_Destroy(codec_);
        codec_ = nullptr;
        return -3;
    }
    
    return 0;
}

// ────────────────────────────────────────────────────────────
// Configure the decoder with default audio parameters
// ────────────────────────────────────────────────────────────

int32_t AudioDecoder::ConfigureDecoder() {
    OH_AVFormat *format = OH_AVFormat_Create();
    if (format == nullptr) {
        OH_LOG_ERROR(LOG_APP, "OH_AVFormat_Create failed");
        return -1;
    }
    
    // Set required decoder parameters
    // These are default values; the decoder may override them via OnOutputFormatChanged
    constexpr int32_t DEFAULT_SAMPLE_RATE = 16000;
    constexpr int32_t DEFAULT_CHANNEL_COUNT = 1;
    constexpr int32_t DEFAULT_BITRATE = 64000;
    constexpr int32_t DEFAULT_MAX_INPUT_SIZE = 8192;
    
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_AUD_SAMPLE_RATE, DEFAULT_SAMPLE_RATE);
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_AUD_CHANNEL_COUNT, DEFAULT_CHANNEL_COUNT);
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_BITRATE, DEFAULT_BITRATE);
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_MAX_INPUT_SIZE, DEFAULT_MAX_INPUT_SIZE);
    
    // For AAC, specify ADTS format (common in .aac files)
    if (mimeType_ == OH_AVCODEC_MIMETYPE_AUDIO_AAC) {
        OH_AVFormat_SetIntValue(format, OH_MD_KEY_AAC_IS_ADTS, 1);
    }
    
    int32_t ret = OH_AudioCodec_Configure(codec_, format);
    OH_AVFormat_Destroy(format);
    
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "OH_AudioCodec_Configure failed: %{public}d", ret);
        return ret;
    }
    
    OH_LOG_INFO(LOG_APP, "Decoder configured successfully");
    return 0;
}

// ────────────────────────────────────────────────────────────
// Start decoding
// ────────────────────────────────────────────────────────────

int32_t AudioDecoder::Start() {
    if (codec_ == nullptr) {
        OH_LOG_ERROR(LOG_APP, "Start called but codec is null");
        return -1;
    }
    
    // Configure
    int32_t ret = ConfigureDecoder();
    if (ret != AV_ERR_OK) return ret;
    
    // Prepare
    ret = OH_AudioCodec_Prepare(codec_);
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "OH_AudioCodec_Prepare failed: %{public}d", ret);
        return ret;
    }
    
    // Start
    ret = OH_AudioCodec_Start(codec_);
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "OH_AudioCodec_Start failed: %{public}d", ret);
        return ret;
    }
    
    isDecoding_ = true;
    inputEos_ = false;
    outputEos_ = false;
    errorCode_ = 0;
    
    OH_LOG_INFO(LOG_APP, "Decoder started. Decoding in progress...");
    return 0;
}

// ────────────────────────────────────────────────────────────
// Fill input buffer from the input file
// Returns true if EOF reached
// ────────────────────────────────────────────────────────────

bool AudioDecoder::FillInputBuffer(OH_AVBuffer *buffer) {
    if (!inputFile_.is_open() || inputFile_.eof()) {
        return true; // EOF
    }
    
    // Get the buffer's writable memory
    uint8_t *bufAddr = reinterpret_cast<uint8_t *>(OH_AVBuffer_GetAddr(buffer));
    if (bufAddr == nullptr) {
        OH_LOG_ERROR(LOG_APP, "FillInputBuffer: OH_AVBuffer_GetAddr returned null");
        return true;
    }
    
    // Get buffer capacity
    int32_t capacity = OH_AVBuffer_GetCapacity(buffer);
    if (capacity <= 0) {
        OH_LOG_ERROR(LOG_APP, "FillInputBuffer: invalid buffer capacity %{public}d", capacity);
        return true;
    }
    
    // Read data from file
    inputFile_.read(reinterpret_cast<char *>(bufAddr), capacity);
    std::streamsize bytesRead = inputFile_.gcount();
    
    OH_AVCodecBufferAttr attr;
    memset(&attr, 0, sizeof(attr));
    
    if (inputFile_.eof() || bytesRead == 0) {
        // End of file
        attr.flags = AVCODEC_BUFFER_FLAGS_EOS;
        attr.size = 0;
        attr.pts = 0;
        inputEos_ = true;
        OH_LOG_INFO(LOG_APP, "Input EOS reached");
    } else {
        attr.flags = AVCODEC_BUFFER_FLAGS_NONE;
        attr.size = static_cast<int32_t>(bytesRead);
        attr.pts = 0;
    }
    
    OH_AVBuffer_SetBufferAttr(buffer, &attr);
    return inputEos_;
}

// ────────────────────────────────────────────────────────────
// Stop decoding and release resources
// ────────────────────────────────────────────────────────────

int32_t AudioDecoder::Stop() {
    isDecoding_ = false;
    
    if (codec_ != nullptr) {
        OH_AudioCodec_Stop(codec_);
        OH_AudioCodec_Destroy(codec_);
        codec_ = nullptr;
        OH_LOG_INFO(LOG_APP, "Decoder stopped and destroyed");
    }
    
    if (inputFile_.is_open()) {
        inputFile_.close();
    }
    
    // Clear queues
    {
        std::lock_guard<std::mutex> lock(inputMutex_);
        while (!inputIndexQueue_.empty()) inputIndexQueue_.pop();
        while (!inputBufferQueue_.empty()) inputBufferQueue_.pop();
    }
    {
        std::lock_guard<std::mutex> lock(outputMutex_);
        while (!outputIndexQueue_.empty()) outputIndexQueue_.pop();
        while (!outputBufferQueue_.empty()) outputBufferQueue_.pop();
    }
    
    return 0;
}

// ════════════════════════════════════════════════════════════
// STATIC CALLBACKS (called by OH_AudioCodec on internal threads)
// ════════════════════════════════════════════════════════════

void AudioDecoder::OnError(OH_AVCodec *codec, int32_t errorCode, void *userData) {
    AudioDecoder *decoder = static_cast<AudioDecoder *>(userData);
    if (decoder == nullptr) return;
    
    OH_LOG_ERROR(LOG_APP, "AudioDecoder::OnError code=%{public}d", errorCode);
    decoder->errorCode_ = errorCode;
    decoder->isDecoding_ = false;
}

void AudioDecoder::OnOutputFormatChanged(OH_AVCodec *codec, OH_AVFormat *format,
                                          void *userData) {
    AudioDecoder *decoder = static_cast<AudioDecoder *>(userData);
    if (decoder == nullptr || format == nullptr) return;
    
    int32_t sampleRate = 0;
    int32_t channelCount = 0;
    int32_t sampleFormat = 0;
    
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_SAMPLE_RATE, &sampleRate);
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUD_CHANNEL_COUNT, &channelCount);
    OH_AVFormat_GetIntValue(format, OH_MD_KEY_AUDIO_SAMPLE_FORMAT, &sampleFormat);
    
    OH_LOG_INFO(LOG_APP,
                "OutputFormatChanged: sampleRate=%{public}d channels=%{public}d format=%{public}d",
                sampleRate, channelCount, sampleFormat);
}

void AudioDecoder::OnInputBufferAvailable(OH_AVCodec *codec, uint32_t index,
                                           OH_AVBuffer *buffer, void *userData) {
    AudioDecoder *decoder = static_cast<AudioDecoder *>(userData);
    if (decoder == nullptr || !decoder->isDecoding_) return;
    
    if (decoder->inputEos_) {
        // No more data to feed; the codec will continue processing remaining buffers
        return;
    }
    
    // Fill the input buffer with encoded data
    bool eof = decoder->FillInputBuffer(buffer);
    
    // Push the filled buffer to the codec
    int32_t ret = OH_AudioCodec_PushInputBuffer(codec, index);
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "PushInputBuffer failed: %{public}d", ret);
        decoder->errorCode_ = ret;
        decoder->isDecoding_ = false;
    }
}

void AudioDecoder::OnOutputBufferAvailable(OH_AVCodec *codec, uint32_t index,
                                            OH_AVBuffer *buffer, void *userData) {
    AudioDecoder *decoder = static_cast<AudioDecoder *>(userData);
    if (decoder == nullptr || !decoder->isDecoding_) {
        // Still need to free the buffer even if decoder is stopping
        if (codec != nullptr) {
            OH_AudioCodec_FreeOutputBuffer(codec, index);
        }
        return;
    }
    
    // Get buffer attributes
    OH_AVCodecBufferAttr attr;
    memset(&attr, 0, sizeof(attr));
    int32_t ret = OH_AVBuffer_GetBufferAttr(buffer, &attr);
    if (ret != AV_ERR_OK) {
        OH_LOG_ERROR(LOG_APP, "GetBufferAttr failed: %{public}d", ret);
        OH_AudioCodec_FreeOutputBuffer(codec, index);
        return;
    }
    
    // Check for EOS
    if (attr.flags & AVCODEC_BUFFER_FLAGS_EOS) {
        OH_LOG_INFO(LOG_APP, "Output EOS reached");
        decoder->outputEos_ = true;
        decoder->isDecoding_ = false;
        OH_AudioCodec_FreeOutputBuffer(codec, index);
        return;
    }
    
    // Get the PCM data
    uint8_t *pcmData = reinterpret_cast<uint8_t *>(OH_AVBuffer_GetAddr(buffer));
    int32_t pcmSize = attr.size;
    
    if (pcmData != nullptr && pcmSize > 0) {
        // Deliver the PCM chunk to ArkTS
        decoder->DeliverPcmChunk(pcmData, pcmSize);
    }
    
    // Free the output buffer
    OH_AudioCodec_FreeOutputBuffer(codec, index);
}
