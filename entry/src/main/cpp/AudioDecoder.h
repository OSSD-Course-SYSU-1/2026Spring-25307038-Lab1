/*
 * AudioDecoder - Native C++ wrapper around OH_AudioCodec for decoding
 * AAC/MP3/FLAC/Vorbis/Opus audio files to PCM.
 *
 * Uses the unified OH_AudioCodec API (API 11+) with async callbacks.
 * Decoded PCM is delivered in 640-byte chunks via a thread-safe function.
 */

#ifndef AUDIO_DECODER_H
#define AUDIO_DECODER_H

#include <cstdint>
#include <fstream>
#include <mutex>
#include <queue>
#include <string>

// Forward-declare NAPI types to avoid header dependency
struct napi_env__;
typedef napi_env__* napi_env;
struct napi_value__;
typedef napi_value__* napi_value;
struct napi_threadsafe_function__;
typedef napi_threadsafe_function__* napi_threadsafe_function;

// Forward-declare OH_AVCodec types (from native_avcodec_audiocodec.h)
struct OH_AVCodec;
struct OH_AVFormat;
struct OH_AVBuffer;
struct OH_AVCodecBufferAttr;

class AudioDecoder {
public:
    AudioDecoder();
    ~AudioDecoder();

    // Initialize the decoder with a file path and a threadsafe function for PCM delivery.
    // Returns 0 on success, negative on error.
    int32_t Init(napi_env env, const std::string &filePath,
                 napi_threadsafe_function tsfn);

    // Start decoding (called after Init succeeds).
    int32_t Start();

    // Stop decoding and release resources.
    int32_t Stop();

    // Check if decoding is in progress.
    bool IsDecoding() const { return isDecoding_; }

    // Get the last error code (0 = no error).
    int32_t GetErrorCode() const { return errorCode_; }

private:
    // Determine MIME type from file extension.
    static std::string GetMimeFromPath(const std::string &path);

    // Create and configure the OH_AudioCodec decoder.
    int32_t CreateDecoder();

    // Configure the decoder with default params (will be overridden by stream info).
    int32_t ConfigureDecoder();

    // Read raw encoded data from the input file.
    // Returns true if EOF reached.
    bool FillInputBuffer(OH_AVBuffer *buffer);

    // Deliver PCM data to ArkTS via tsfn.
    void DeliverPcmChunk(const uint8_t *data, int32_t size);

    // Static callbacks for OH_AudioCodec (must be static or C-linkage).
    static void OnError(OH_AVCodec *codec, int32_t errorCode, void *userData);
    static void OnOutputFormatChanged(OH_AVCodec *codec, OH_AVFormat *format,
                                      void *userData);
    static void OnInputBufferAvailable(OH_AVCodec *codec, uint32_t index,
                                       OH_AVBuffer *buffer, void *userData);
    static void OnOutputBufferAvailable(OH_AVCodec *codec, uint32_t index,
                                        OH_AVBuffer *buffer, void *userData);

    // Member state
    napi_env env_ = nullptr;
    napi_threadsafe_function tsfn_ = nullptr;
    std::string filePath_;
    std::string mimeType_;

    OH_AVCodec *codec_ = nullptr;
    bool isDecoding_ = false;
    bool inputEos_ = false;
    bool outputEos_ = false;

    // Input file
    std::ifstream inputFile_;

    // Buffer queues for async callback coordination
    std::mutex inputMutex_;
    std::queue<uint32_t> inputIndexQueue_;
    std::queue<OH_AVBuffer *> inputBufferQueue_;

    std::mutex outputMutex_;
    std::queue<uint32_t> outputIndexQueue_;
    std::queue<OH_AVBuffer *> outputBufferQueue_;

    // Output PCM accumulation (640 bytes per chunk)
    static constexpr int32_t CHUNK_SIZE = 640;

    // Decoder error code
    int32_t errorCode_ = 0;

    friend class AudioDecoderCallbackHelper;
};

#endif // AUDIO_DECODER_H
