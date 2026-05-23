#!/usr/bin/env bash
# Populate app/src/main/jniLibs/ with libcsoundandroid.so + libc++_shared.so
# for arm64-v8a, armeabi-v7a, x86_64, by pulling the latest Csound for Android
# release APK and extracting just the native libraries we need.
#
# Usage:  ./scripts/fetch-csound.sh
#
# Re-run if you ever delete jniLibs/ or want to upgrade to a newer release.

set -euo pipefail

CSOUND_RELEASE_TAG="${CSOUND_RELEASE_TAG:-v48beta2}"
APK_URL="https://github.com/gogins/csound-android/releases/download/${CSOUND_RELEASE_TAG}/CsoundApplication-release.apk"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JNI_DIR="$ROOT_DIR/app/src/main/jniLibs"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Fetching Csound for Android $CSOUND_RELEASE_TAG ..."
curl -L --fail --progress-bar -o "$TMP_DIR/csound.apk" "$APK_URL"

mkdir -p "$JNI_DIR"/{arm64-v8a,armeabi-v7a,x86_64}

for abi in arm64-v8a armeabi-v7a x86_64; do
    echo "Extracting lib/$abi/ ..."
    unzip -j -o "$TMP_DIR/csound.apk" \
        "lib/$abi/libcsoundandroid.so" \
        "lib/$abi/libc++_shared.so" \
        "lib/$abi/libsndfile.so" \
        "lib/$abi/liboboe.so" \
        -d "$JNI_DIR/$abi/" >/dev/null
done

# Refresh the csnd Java bindings JAR too. Requires d2j-dex2jar on PATH; if
# missing, we skip — app/libs/csnd.jar is already checked in.
if command -v d2j-dex2jar.sh >/dev/null 2>&1; then
    echo "Refreshing app/libs/csnd.jar from APK classes.dex ..."
    d2j-dex2jar.sh -f -o "$TMP_DIR/all-classes.jar" "$TMP_DIR/csound.apk" >/dev/null
    mkdir -p "$TMP_DIR/unpacked"
    (cd "$TMP_DIR/unpacked" && unzip -q "$TMP_DIR/all-classes.jar" "csnd/*")
    (cd "$TMP_DIR/unpacked" && jar cf "$ROOT_DIR/app/libs/csnd.jar" csnd/)
    echo "Wrote $(ls -lh "$ROOT_DIR/app/libs/csnd.jar" | awk '{print $5}') to app/libs/csnd.jar"
else
    echo "(d2j-dex2jar.sh not found on PATH — skipping csnd.jar refresh; existing one will be used.)"
fi

echo "Done. Native libraries placed under app/src/main/jniLibs/"
ls -lh "$JNI_DIR"/*/*.so
