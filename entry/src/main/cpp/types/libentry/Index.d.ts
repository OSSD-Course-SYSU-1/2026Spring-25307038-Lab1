/**
 * Native audio decoder type declarations.
 *
 * startDecode: Decode an audio file to PCM and deliver chunks via callback.
 *   @param filePath - Absolute path to the audio file (.aac, .mp3, .flac, .ogg, .opus, .amr)
 *   @param pcmCallback - Callback receiving PCM data as ArrayBuffer chunks
 *   @returns Promise that resolves when decoding completes, rejects on error
 *
 * stopDecode: Stop an ongoing decode operation and release resources.
 */
export const startDecode: (filePath: string, pcmCallback: (chunk: ArrayBuffer) => void) => Promise<void>;

export const stopDecode: () => void;

/**
 * Native WebSocket for Huawei Cloud ASR.
 * Uses OH_WebSocketClient (C API) to inject X-Auth-Token header,
 * which the ArkTS WebSocket API cannot do during WSS handshake.
 */

/**
 * Connect to ASR WebSocket with IAM token.
 *
 * @param wsUrl  - WSS endpoint (e.g. wss://sis-ext.cn-north-4.myhuaweicloud.com/v1/{project}/rasr/sentence-stream)
 * @param token  - IAM X-Auth-Token string
 * @param dispatcher - Callback receiving JSON event strings:
 *     {"type":"open"}
 *     {"type":"message","data":"<JSON from ASR>"}
 *     {"type":"error","code":200,"msg":"..."}
 *     {"type":"close","code":1000,"reason":"..."}
 */
export const asrConnect: (wsUrl: string, token: string, dispatcher: (eventJson: string) => void) => void;

/**
 * Send binary audio data (PCM 16kHz 16bit mono) to the ASR server.
 */
export const asrSend: (audioData: ArrayBuffer) => void;

/**
 * Gracefully close the WebSocket connection.
 */
export const asrClose: () => void;
