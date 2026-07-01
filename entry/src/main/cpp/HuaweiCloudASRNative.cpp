/*
 * HuaweiCloudASRNative.cpp
 *
 * Native WebSocket for Huawei Cloud ASR using OH_WebSocketClient C API.
 * The ArkTS WebSocket fails to inject X-Auth-Token during WSS handshake;
 * the C API OH_WebSocketClient_AddHeader solves this at the native layer.
 *
 * Exported NAPI functions:
 *   asrConnect(wsUrl, token, onOpen, onMessage, onError, onClose)
 *   asrSend(audioData: ArrayBuffer)
 *   asrClose()
 */

#include <network/netstack/net_websocket.h>
#include <network/netstack/net_websocket_type.h>
#include <napi/native_api.h>
#include <hilog/log.h>
#include <string>
#include <cstring>
#include <mutex>
#include <atomic>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x0001
#define LOG_TAG "[ASRNative]"

// ──────────────────────────────────────────────────────────────
// Global state (single ASR session at a time)
// ──────────────────────────────────────────────────────────────

static struct WebSocket *g_wsClient = nullptr;

// Unified ThreadSafeFunction for all events.
// The callback receives a JSON string encoding the event type and payload.
static napi_threadsafe_function g_tsfnEvents = nullptr;

// Track whether connect has been called to avoid double-init.
static std::atomic<bool> g_connected{false};

// Mutex for protecting WS client operations.
static std::mutex g_mutex;

// Store the IAM token string so the C-string pointer passed to
// WebSocket_Header::fieldValue stays valid after AsrConnect returns.
static std::string g_asrToken;

// ──────────────────────────────────────────────────────────────
// Event types (serialised as JSON for the single TSFN channel)
//   {"type":"open"}
//   {"type":"message","data":"..."}
//   {"type":"error","code":200,"msg":"..."}
//   {"type":"close","code":1000,"reason":"..."}
// ──────────────────────────────────────────────────────────────

static void BuildAndCallTSFN(const char *json, size_t len) {
    if (g_tsfnEvents == nullptr) return;
    char *copy = new char[len + 1];
    std::memcpy(copy, json, len);
    copy[len] = '\0';
    napi_call_threadsafe_function(g_tsfnEvents, copy, napi_tsfn_blocking);
}

// ──────────────────────────────────────────────────────────────
// C WebSocket callbacks (invoked by lws event-loop thread)
// ──────────────────────────────────────────────────────────────

static void OnOpenCallback(struct WebSocket *client,
                           WebSocket_OpenResult result) {
    OH_LOG_INFO(LOG_APP, "[C] OnOpen  code=%{public}u  reason=%{public}s",
                result.code,
                result.reason ? result.reason : "");
    char json[256];
    snprintf(json, sizeof(json),
             R"({"type":"open","code":%u})", result.code);
    BuildAndCallTSFN(json, strlen(json));
}

static void OnMessageCallback(struct WebSocket *client,
                              char *data, uint32_t length) {
    // Text messages (ASR results) or binary echoes
    std::string payload(data, length);

    // Quick peek for logging
    if (length <= 200) {
        OH_LOG_INFO(LOG_APP, "[C] OnMessage  len=%{public}u  raw=%.*s",
                    length, (int)length, data);
    } else {
        OH_LOG_INFO(LOG_APP, "[C] OnMessage  len=%{public}u", length);
    }

    // Build JSON: {"type":"message","data":"<escaped>"}
    // Minimal escaping: only backslash and double-quote
    std::string escaped;
    escaped.reserve(payload.size() + 32);
    for (char c : payload) {
        if (c == '\\') { escaped += "\\\\"; }
        else if (c == '"') { escaped += "\\\""; }
        else if (c == '\n') { escaped += "\\n"; }
        else if (c == '\r') { escaped += "\\r"; }
        else if (c == '\t') { escaped += "\\t"; }
        else { escaped += c; }
    }

    std::string json = R"({"type":"message","data":")";
    json += escaped;
    json += "\"}";

    char *copy = new char[json.size() + 1];
    std::memcpy(copy, json.data(), json.size());
    copy[json.size()] = '\0';
    napi_call_threadsafe_function(g_tsfnEvents, copy, napi_tsfn_blocking);
}

static void OnErrorCallback(struct WebSocket *client,
                            WebSocket_ErrorResult result) {
    const char *msg = result.errorMessage ? result.errorMessage : "";
    OH_LOG_ERROR(LOG_APP, "[C] OnError  code=%{public}u  msg=%{public}s",
                 result.errorCode, msg);

    char json[512];
    snprintf(json, sizeof(json),
             R"({"type":"error","code":%u,"msg":"%s"})",
             result.errorCode, msg);
    BuildAndCallTSFN(json, strlen(json));
}

static void OnCloseCallback(struct WebSocket *client,
                            WebSocket_CloseResult result) {
    const char *reason = result.reason ? result.reason : "";
    OH_LOG_INFO(LOG_APP, "[C] OnClose  code=%{public}u  reason=%{public}s",
                result.code, reason);

    char json[512];
    snprintf(json, sizeof(json),
             R"({"type":"close","code":%u,"reason":"%s"})",
             result.code, reason);
    BuildAndCallTSFN(json, strlen(json));

    // Mark disconnected so asrSend/asrClose safely no-op
    g_connected.store(false);
    g_asrToken.clear();
}

// ──────────────────────────────────────────────────────────────
// ThreadSafeFunction JS callback (runs on main thread)
// Parses the JSON event string and dispatches to the correct
// ArkTS callback registered via asrConnect.
// ──────────────────────────────────────────────────────────────

static void TSFN_Dispatch(napi_env env, napi_value jsCallback,
                          void *context, void *data) {
    if (data == nullptr || jsCallback == nullptr) return;

    // data is a C string (JSON event)
    char *json = static_cast<char *>(data);

    // Create JS string from the JSON
    napi_value arg;
    napi_create_string_utf8(env, json, NAPI_AUTO_LENGTH, &arg);

    // Call the ArkTS dispatcher: dispatcher(jsonString)
    napi_value global;
    napi_get_global(env, &global);
    napi_call_function(env, global, jsCallback, 1, &arg, nullptr);

    delete[] json;
}

// ──────────────────────────────────────────────────────────────
// NAPI: asrConnect(wsUrl, token, dispatcher)
//
//   wsUrl     : WSS endpoint
//   token     : IAM X-Auth-Token
//   dispatcher: function(jsonEvent) – receives JSON event strings
//
// Returns synchronously (void). The dispatcher receives events:
//   {"type":"open"}
//   {"type":"message","data":"<ASR JSON response>"}
//   {"type":"error","code":200,"msg":"..."}
//   {"type":"close","code":1000,"reason":"..."}
// ──────────────────────────────────────────────────────────────

extern "C" napi_value AsrConnect(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr,
                         "Expected 3 args: wsUrl, token, dispatcher");
        return nullptr;
    }

    // ── Parse wsUrl ──────────────────────────────────────────
    size_t urlLen = 0;
    napi_get_value_string_utf8(env, args[0], nullptr, 0, &urlLen);
    std::string wsUrl(urlLen, '\0');
    napi_get_value_string_utf8(env, args[0], &wsUrl[0], urlLen + 1,
                               &urlLen);

    // ── Parse token ──────────────────────────────────────────
    size_t tokenLen = 0;
    napi_get_value_string_utf8(env, args[1], nullptr, 0, &tokenLen);
    std::string token(tokenLen, '\0');
    napi_get_value_string_utf8(env, args[1], &token[0], tokenLen + 1,
                               &tokenLen);

    // ── Validate dispatcher callback ─────────────────────────
    napi_valuetype cbType;
    napi_typeof(env, args[2], &cbType);
    if (cbType != napi_function) {
        napi_throw_error(env, nullptr, "Third arg must be a function");
        return nullptr;
    }

    OH_LOG_INFO(LOG_APP, "asrConnect  url=%{public}s  token_len=%{public}zu",
                wsUrl.c_str(), token.length());

    std::lock_guard<std::mutex> lock(g_mutex);

    // ── Release previous connection if any ───────────────────
    if (g_wsClient != nullptr) {
        OH_LOG_WARN(LOG_APP, "Releasing previous WS client");
        OH_WebSocketClient_Destroy(g_wsClient);
        g_wsClient = nullptr;
    }
    if (g_tsfnEvents != nullptr) {
        napi_release_threadsafe_function(g_tsfnEvents, napi_tsfn_release);
        g_tsfnEvents = nullptr;
    }
    g_connected.store(false);
    g_asrToken.clear();

    // ── Create ThreadSafeFunction for event dispatch ─────────
    napi_value tsfnName;
    napi_create_string_utf8(env, "ASREventTSFN", NAPI_AUTO_LENGTH, &tsfnName);
    napi_status tsfnStatus = napi_create_threadsafe_function(
        env,
        args[2],          // JS dispatcher callback
        nullptr,
        tsfnName,
        0,                // unlimited queue
        1,
        nullptr, nullptr, nullptr,
        TSFN_Dispatch,
        &g_tsfnEvents);
    if (tsfnStatus != napi_ok) {
        napi_throw_error(env, nullptr, "Failed to create TSFN");
        return nullptr;
    }

    // ── Create native WebSocket client ───────────────────────
    g_wsClient = OH_WebSocketClient_Constructor(
        OnOpenCallback, OnMessageCallback,
        OnErrorCallback, OnCloseCallback);
    if (g_wsClient == nullptr) {
        napi_release_threadsafe_function(g_tsfnEvents, napi_tsfn_release);
        g_tsfnEvents = nullptr;
        napi_throw_error(env, nullptr, "Failed to construct WS client");
        return nullptr;
    }

    // ── Build X-Auth-Token header chain ──────────────────────
    //   Passed via Connect()′s WebSocket_RequestOptions, not AddHeader().
    //   AddHeader() is unreliable for WSS handshake custom headers.
    //   token is saved to g_asrToken so the fieldValue pointer stays valid.
    g_asrToken = std::move(token);
    struct WebSocket_Header authHeader;
    authHeader.fieldName  = "X-Auth-Token";
    authHeader.fieldValue = g_asrToken.c_str();
    authHeader.next       = nullptr;

    struct WebSocket_RequestOptions opts;
    opts.headers = &authHeader;

    // ── Connect ──────────────────────────────────────────────
    int connRet = OH_WebSocketClient_Connect(g_wsClient, wsUrl.c_str(), opts);
    if (connRet != 0) {
        OH_LOG_ERROR(LOG_APP, "Connect failed  ret=%{public}d", connRet);
        OH_WebSocketClient_Destroy(g_wsClient);
        g_wsClient = nullptr;
        napi_release_threadsafe_function(g_tsfnEvents, napi_tsfn_release);
        g_tsfnEvents = nullptr;
        napi_throw_error(env, nullptr,
                         ("Connect failed, code=" +
                          std::to_string(connRet)).c_str());
        return nullptr;
    }

    g_connected.store(true);
    OH_LOG_INFO(LOG_APP, "Connect request submitted successfully");

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ──────────────────────────────────────────────────────────────
// NAPI: asrSend(audioData: ArrayBuffer)
//   Sends raw binary audio data to the ASR server.
// ──────────────────────────────────────────────────────────────

extern "C" napi_value AsrSend(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Expected 1 arg: ArrayBuffer");
        return nullptr;
    }

    // Validate it's an ArrayBuffer
    bool isArrayBuffer = false;
    napi_is_arraybuffer(env, args[0], &isArrayBuffer);
    if (!isArrayBuffer) {
        napi_throw_error(env, nullptr, "Arg must be ArrayBuffer");
        return nullptr;
    }

    void *dataPtr = nullptr;
    size_t dataLen = 0;
    napi_get_arraybuffer_info(env, args[0], &dataPtr, &dataLen);

    if (dataPtr == nullptr || dataLen == 0) {
        napi_value result;
        napi_get_undefined(env, &result);
        return result;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_wsClient == nullptr || !g_connected.load()) {
        OH_LOG_WARN(LOG_APP, "asrSend skipped – not connected");
        napi_value result;
        napi_get_undefined(env, &result);
        return result;
    }

    int sendRet = OH_WebSocketClient_Send(
        g_wsClient, static_cast<char *>(dataPtr), dataLen);
    if (sendRet != 0) {
        OH_LOG_ERROR(LOG_APP, "Send failed  ret=%{public}d  len=%{public}zu",
                     sendRet, dataLen);
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ──────────────────────────────────────────────────────────────
// NAPI: asrClose()
//   Gracefully close the WebSocket and release native resources.
// ──────────────────────────────────────────────────────────────

extern "C" napi_value AsrClose(napi_env env, napi_callback_info info) {
    OH_LOG_INFO(LOG_APP, "asrClose called");

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_wsClient != nullptr) {
        OH_WebSocketClient_Close(g_wsClient, {
            .code = 1000,
            .reason = "Client closing"
        });
        // Destroy will be called in OnCloseCallback
        // (the C API requires destroy after close callback fires)
    }
    g_connected.store(false);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// ──────────────────────────────────────────────────────────────
// Module registration (merged with existing "entry" module)
// ──────────────────────────────────────────────────────────────

EXTERN_C_START
static napi_value InitAsrNative(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"asrConnect", nullptr, AsrConnect, nullptr, nullptr, nullptr,
         napi_default, nullptr},
        {"asrSend",    nullptr, AsrSend,    nullptr, nullptr, nullptr,
         napi_default, nullptr},
        {"asrClose",   nullptr, AsrClose,   nullptr, nullptr, nullptr,
         napi_default, nullptr},
    };

    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]),
                           desc);
    return exports;
}
EXTERN_C_END

static napi_module asrModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = InitAsrNative,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterAsrNativeModule(void) {
    napi_module_register(&asrModule);
}
