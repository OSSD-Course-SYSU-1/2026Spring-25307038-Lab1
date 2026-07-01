# CMakeLists.txt - Native audio decoder module for HarmonyOS
cmake_minimum_required(VERSION 3.5.0)
project(audiodecoder)

# Include source directory
set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(entry SHARED
    napi_init.cpp
    AudioDecoder.cpp
    HuaweiCloudASRNative.cpp
)

# System libraries
target_link_libraries(entry PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
    libnative_media_codecbase.so
    libnative_media_core.so
    libnative_media_acodec.so
    libnet_websocket.so
)
