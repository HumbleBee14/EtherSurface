cmake_minimum_required(VERSION 3.22.1)
project(ether_engine LANGUAGES CXX)

# Oboe comes from the AAR via prefab=true in app/build.gradle.kts.
find_package(oboe REQUIRED CONFIG)

# Pre-built Csound 6.19 lives under jniLibs/. We declare it as an IMPORTED
# library so CMake can link against it without trying to rebuild from source.
# The CMAKE_ANDROID_ARCH_ABI variable expands to arm64-v8a / armeabi-v7a /
# x86_64 — exactly the per-ABI subdirectory names we already use.
add_library(csoundandroid SHARED IMPORTED)
set_target_properties(csoundandroid PROPERTIES
    IMPORTED_LOCATION
        "${CMAKE_SOURCE_DIR}/../jniLibs/${CMAKE_ANDROID_ARCH_ABI}/libcsoundandroid.so"
)

add_library(sndfile SHARED IMPORTED)
set_target_properties(sndfile PROPERTIES
    IMPORTED_LOCATION
        "${CMAKE_SOURCE_DIR}/../jniLibs/${CMAKE_ANDROID_ARCH_ABI}/libsndfile.so"
)

# Csound headers — pulled from the local clone we built the .so files from.
# These are headers only; no library code is referenced from this path.
set(CSOUND_INCLUDE_DIR
    "${CMAKE_SOURCE_DIR}/../../../../../legacy/csound-android-src/CsoundForAndroid/ndk-libraries/csound"
)

add_library(ether_engine SHARED
    engine.cpp
)

target_include_directories(ether_engine PRIVATE
    "${CSOUND_INCLUDE_DIR}/H"
    "${CSOUND_INCLUDE_DIR}/include"
)

target_link_libraries(ether_engine
    PRIVATE
        oboe::oboe
        csoundandroid
        sndfile
        log
        android
)

target_compile_options(ether_engine PRIVATE
    -Wall
    -Wextra
    -fexceptions
    -frtti
)
