/*
 * napi_init.cpp - NAPI bridge between ArkTS and Native AudioDecoder.
 *
 * Exported functions:
 *   startDecode(filePath: string, pcmCallback: (chunk: ArrayBuffer) => void): Promise<void>
 *   stopDecode(): void
 */

#include "AudioDecoder.h"

#include <cstring>
#include <hilog/log.h>
#include <napi/native_api.h>
#include <string>
#include <unistd.h>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0001
#define LOG_TAG "[AudioDecoder:NAPI]"

// ────────────────────────────────────────────────────────────
// Global decoder instance (single decode session at a time)
// ────────────────────────────────────────────────────────────

static AudioDecoder *g_decoder = nullptr;
static napi_threadsafe_function g_tsfn = nullptr;
static napi_env g_env = nullptr;

// ────────────────────────────────────────────────────────────
// ThreadSafeFunction call callback (delivers PCM to ArkTS)
// ────────────────────────────────────────────────────────────

static void TsfnCallJs(napi_env env, napi_value jsCallback,
                       void *context, void *data) {
    if (data == nullptr) return;
    
    // data is a heap-allocated buffer: { size: int32_t, bytes: uint8_t[] }
    struct PcmChunk {
        int32_t size;
        uint8_t data[];
    };
    PcmChunk *chunk = static_cast<PcmChunk *>(data);
    
    if (chunk->size <= 0) {
        delete[] reinterpret_cast<uint8_t *>(chunk);
        return;
    }
    
    // Create an external ArrayBuffer that takes ownership of the data
    napi_value arrayBuffer;
    napi_status status = napi_create_external_arraybuffer(
        env, chunk->data, chunk->size,
        [](napi_env env, void *finalizeData, void *finalizeHint) {
            // The chunk struct and its data are contiguous
            delete[] reinterpret_cast<uint8_t *>(finalizeData);
        },
        nullptr, &arrayBuffer);
    
    if (status != napi_ok) {
        OH_LOG_ERROR(LOG_APP, "TsfnCallJs: napi_create_external_arraybuffer failed");
        delete[] reinterpret_cast<uint8_t *>(chunk);
        return;
    }
    
    // Call the JS callback: callback(arrayBuffer)
    napi_value global;
    napi_get_global(env, &global);
    napi_value result;
    napi_call_function(env, global, jsCallback, 1, &arrayBuffer, &result);
}

// ────────────────────────────────────────────────────────────
// NAPI: startDecode(filePath: string, pcmCallback: function) → Promise<void>
// ────────────────────────────────────────────────────────────

struct DecodeAsyncData {
    napi_async_work asyncWork = nullptr;
    napi_deferred deferred = nullptr;
    std::string filePath;
    bool success = false;
    std::string errorMsg;
};

static void DecodeExecute(napi_env env, void *data) {
    DecodeAsyncData *asyncData = static_cast<DecodeAsyncData *>(data);
    
    if (g_decoder == nullptr) {
        asyncData->success = false;
        asyncData->errorMsg = "Decoder not initialized";
        return;
    }
    
    int32_t ret = g_decoder->Start();
    if (ret != 0) {
        asyncData->success = false;
        asyncData->errorMsg = "Failed to start decoder (code " + std::to_string(ret) + ")";
        return;
    }
    
    // Wait for decoding to complete (polling with sleep)
    // The decoder stops when output EOS is reached or on error
    while (g_decoder->IsDecoding()) {
        usleep(10000); // 10ms sleep
    }
    
    // Check if we hit an error
    if (g_decoder->GetErrorCode() != 0) {
        asyncData->success = false;
        asyncData->errorMsg = "Decoder error (code " + std::to_string(g_decoder->GetErrorCode()) + ")";
        return;
    }
    
    asyncData->success = true;
}

static void DecodeComplete(napi_env env, napi_status status, void *data) {
    DecodeAsyncData *asyncData = static_cast<DecodeAsyncData *>(data);
    
    if (asyncData->success) {
        napi_value result;
        napi_get_undefined(env, &result);
        napi_resolve_deferred(env, asyncData->deferred, result);
    } else {
        napi_value errorMsg;
        napi_create_string_utf8(env, asyncData->errorMsg.c_str(),
                                NAPI_AUTO_LENGTH, &errorMsg);
        napi_reject_deferred(env, asyncData->deferred, errorMsg);
    }
    
    napi_delete_async_work(env, asyncData->asyncWork);
    delete asyncData;
}

static napi_value StartDecode(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    if (argc < 2) {
        napi_throw_error(env, nullptr, "Expected 2 arguments: filePath, pcmCallback");
        return nullptr;
    }
    
    // Parse filePath (string)
    size_t strLen = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &strLen);
    std::string filePath(strLen, '\0');
    napi_get_value_string_utf8(env, args[0], &filePath[0], strLen + 1, &strLen);
    
    // Validate callback (function)
    napi_valuetype callbackType;
    napi_typeof(env, args[1], &callbackType);
    if (callbackType != napi_function) {
        napi_throw_error(env, nullptr, "Second argument must be a function (pcmCallback)");
        return nullptr;
    }
    
    OH_LOG_INFO(LOG_APP, "StartDecode called: %{public}s", filePath.c_str());
    
    // Stop any existing decoder
    if (g_decoder != nullptr) {
        g_decoder->Stop();
        delete g_decoder;
        g_decoder = nullptr;
    }
    
    // Release old tsfn
    if (g_tsfn != nullptr) {
        napi_release_threadsafe_function(g_tsfn, napi_tsfn_release);
        g_tsfn = nullptr;
    }
    
    // Create a ThreadSafeFunction for delivering PCM chunks
    napi_value tsfnName;
    napi_create_string_utf8(env, "AudioDecodePcm", NAPI_AUTO_LENGTH, &tsfnName);
    
    napi_status tsfnStatus = napi_create_threadsafe_function(
        env, args[1],       // JS callback
        nullptr,            // async resource (optional)
        tsfnName,           // resource name
        0,                  // max queue size (0 = unlimited)
        1,                  // initial thread count
        nullptr,            // thread finalize data
        nullptr,            // thread finalize callback
        nullptr,            // context
        TsfnCallJs,         // call callback
        &g_tsfn            // result
    );
    
    if (tsfnStatus != napi_ok) {
        OH_LOG_ERROR(LOG_APP, "Failed to create threadsafe function");
        napi_throw_error(env, nullptr, "Failed to create PCM delivery channel");
        return nullptr;
    }
    
    // Create the decoder
    g_decoder = new AudioDecoder();
    int32_t initRet = g_decoder->Init(env, filePath, g_tsfn);
    if (initRet != 0) {
        delete g_decoder;
        g_decoder = nullptr;
        napi_release_threadsafe_function(g_tsfn, napi_tsfn_release);
        g_tsfn = nullptr;
        
        napi_throw_error(env, nullptr,
                         ("Failed to initialize decoder (code " +
                          std::to_string(initRet) + ")").c_str());
        return nullptr;
    }
    
    g_env = env;
    
    // Create Promise + AsyncWork for decode execution
    napi_value promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &promise);
    
    DecodeAsyncData *asyncData = new DecodeAsyncData();
    asyncData->deferred = deferred;
    asyncData->filePath = filePath;
    
    napi_value resourceName;
    napi_create_string_utf8(env, "DecodeAsync", NAPI_AUTO_LENGTH, &resourceName);
    
    napi_create_async_work(env, nullptr, resourceName,
                           DecodeExecute, DecodeComplete,
                           asyncData, &asyncData->asyncWork);
    napi_queue_async_work(env, asyncData->asyncWork);
    
    return promise;
}

// ────────────────────────────────────────────────────────────
// NAPI: stopDecode() → void
// ────────────────────────────────────────────────────────────

static napi_value StopDecode(napi_env env, napi_callback_info info) {
    OH_LOG_INFO(LOG_APP, "StopDecode called");
    
    if (g_decoder != nullptr) {
        g_decoder->Stop();
        delete g_decoder;
        g_decoder = nullptr;
    }
    
    if (g_tsfn != nullptr) {
        napi_release_threadsafe_function(g_tsfn, napi_tsfn_release);
        g_tsfn = nullptr;
    }
    
    g_env = nullptr;
    
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ────────────────────────────────────────────────────────────
// Module registration
// ────────────────────────────────────────────────────────────

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"startDecode", nullptr, StartDecode, nullptr, nullptr, nullptr,
         napi_default, nullptr},
        {"stopDecode", nullptr, StopDecode, nullptr, nullptr, nullptr,
         napi_default, nullptr},
    };
    
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module audioDecoderModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterAudioDecoderModule(void) {
    napi_module_register(&audioDecoderModule);
}
