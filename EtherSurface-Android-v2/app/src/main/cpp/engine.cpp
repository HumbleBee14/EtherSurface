// EtherSurface v2 — native audio engine.
//
// Architecture (mirrors the iOS app):
//
//   Oboe AudioStream (PCM_FLOAT, low-latency)
//        |
//        v   onAudioReady()
//   EngineCallback::onAudioReady
//        |
//        v   for each k-period in the Oboe burst:
//   csoundPerformKsmps(csound)
//        |
//        v   memcpy csoundGetSpout(csound) into Oboe output buffer
//
// Key design rules:
//   1. We NEVER call csoundCleanup() or csoundReset() from the audio thread.
//      Those functions destroy internal pthread mutexes; calling them while
//      another Csound thread is mid-lock is what produced the FORTIFY
//      "pthread_mutex_lock called on a destroyed mutex" abort in v1.
//   2. If csoundPerformKsmps returns non-zero (score ended), we just zero-fill
//      the rest of the buffer and keep the stream alive. The host can send a
//      new InputMessage to spawn another note, which Csound will happily
//      schedule even after "score ended" — the engine stays viable as long as
//      we don't tear it down.
//   3. The C++ engine owns the Csound + Oboe lifecycle end to end. Java/Kotlin
//      never touches Csound directly; it only sends sparse events via JNI.

#include <jni.h>
#include <android/log.h>
#include <oboe/Oboe.h>
#include "csound.h"

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <cstring>

#define LOG_TAG "EtherEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// Csound's own message printer — by default it writes to stderr which goes
// nowhere on Android. Route every line into logcat under the same tag so we
// can see compile warnings, "new alloc for instr N", and runtime errors.
void csoundMessageCallback(CSOUND* /*cs*/, int attr, const char* fmt, va_list args) {
    char buf[1024];
    vsnprintf(buf, sizeof(buf), fmt, args);
    int level = (attr & CSOUNDMSG_TYPE_MASK);
    int pri = ANDROID_LOG_INFO;
    if      (level == CSOUNDMSG_ERROR)   pri = ANDROID_LOG_ERROR;
    else if (level == CSOUNDMSG_WARNING) pri = ANDROID_LOG_WARN;
    __android_log_print(pri, "EtherCsound", "%s", buf);
}

class EtherEngine final : public oboe::AudioStreamCallback {
 public:
    EtherEngine() = default;
    ~EtherEngine() override { stop(); }

    bool load(const std::string& csdText) {
        std::lock_guard<std::mutex> lk(lifecycle_mutex_);
        if (csound_ != nullptr) {
            LOGW("load called while engine already running — ignoring");
            return false;
        }
        csound_ = csoundCreate(nullptr);
        if (csound_ == nullptr) {
            LOGE("csoundCreate failed");
            return false;
        }
        csoundSetMessageCallback(csound_, csoundMessageCallback);
        // -odac tells Csound to use real-time audio output, but since we're
        // pulling samples manually via csoundGetSpout, this is informational.
        // The host buffer size doesn't really matter here because we control
        // the per-callback sample count via the Oboe burst.
        // Use the null rtaudio module — we pull samples manually via
        // csoundGetSpout in onAudioReady; Csound's own audio I/O is unused.
        csoundSetOption(csound_, "-+rtaudio=null");
        csoundSetOption(csound_, "--nodisplays");
        // Message level 135 = notes-amps (1) + out-of-range (2) + warnings
        // (4) + a few other Csound diagnostic bits. Gives us per-touch
        // 'rtevent' L/R amp readouts in logcat plus 'new alloc for instr N'
        // lines — useful debugging info that only fires on actual events,
        // not in a tight loop.
        csoundSetMessageLevel(csound_, 135);

        int compileRc = csoundCompileCsdText(csound_, csdText.c_str());
        if (compileRc != 0) {
            LOGE("csoundCompileCsdText failed: %d", compileRc);
            csoundDestroy(csound_);
            csound_ = nullptr;
            return false;
        }

        int startRc = csoundStart(csound_);
        if (startRc != 0) {
            LOGE("csoundStart failed: %d", startRc);
            csoundDestroy(csound_);
            csound_ = nullptr;
            return false;
        }

        sr_       = csoundGetSr(csound_);
        ksmps_    = csoundGetKsmps(csound_);
        nchnls_   = csoundGetNchnls(csound_);
        zerodbfs_ = csoundGet0dBFS(csound_);
        LOGI("csound loaded: sr=%.0f ksmps=%d nchnls=%d 0dbfs=%.1f",
             sr_, ksmps_, nchnls_, zerodbfs_);
        return true;
    }

    bool start() {
        std::lock_guard<std::mutex> lk(lifecycle_mutex_);
        if (csound_ == nullptr) {
            LOGE("start called before load");
            return false;
        }
        if (stream_) {
            LOGW("start called while stream already open — ignoring");
            return true;
        }
        oboe::AudioStreamBuilder builder;
        builder.setDirection(oboe::Direction::Output)
               ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
               ->setSharingMode(oboe::SharingMode::Exclusive)
               ->setFormat(oboe::AudioFormat::Float)
               ->setSampleRate(static_cast<int32_t>(sr_))
               ->setChannelCount(nchnls_)
               ->setUsage(oboe::Usage::Media)
               ->setContentType(oboe::ContentType::Music)
               ->setCallback(this);

        oboe::Result r = builder.openStream(stream_);
        if (r != oboe::Result::OK) {
            LOGE("openStream failed: %s", oboe::convertToText(r));
            return false;
        }
        // Match Oboe's chosen burst to Csound's k-period if possible. We
        // don't strictly require alignment because our render loop chunks
        // multiple k-periods per onAudioReady, but matching reduces jitter.
        stream_->setBufferSizeInFrames(stream_->getFramesPerBurst() * 2);

        r = stream_->requestStart();
        if (r != oboe::Result::OK) {
            LOGE("requestStart failed: %s", oboe::convertToText(r));
            stream_->close();
            stream_.reset();
            return false;
        }
        LOGI("oboe stream started: framesPerBurst=%d bufferSize=%d api=%s",
             stream_->getFramesPerBurst(),
             stream_->getBufferSizeInFrames(),
             oboe::convertToText(stream_->getAudioApi()));
        return true;
    }

    void stop() {
        // Lock first so we don't race with start(). The audio callback can
        // be running on a different thread when stop is called; Oboe's
        // requestStop + close handle the synchronization with it. We do
        // NOT call csoundCleanup or csoundDestroy here for the same
        // reason — Csound has internal threads (the message buffer reader,
        // for instance) that may still be holding mutexes. Calling Destroy
        // races those threads and reproduces the v1 FORTIFY abort.
        // Instead we leak the Csound instance for the activity's lifetime;
        // it'll be reclaimed when the process exits.
        std::lock_guard<std::mutex> lk(lifecycle_mutex_);
        if (stream_) {
            stream_->requestStop();
            stream_->close();
            stream_.reset();
            LOGI("oboe stream stopped");
        }
    }

    // Called from the audio thread by Oboe.
    oboe::DataCallbackResult onAudioReady(oboe::AudioStream* /*stream*/,
                                          void* audioData,
                                          int32_t numFrames) override {
        // CSOUND is single-threaded for performance-style calls; we never
        // touch it from any thread other than this one once started. Java
        // event injection (SetControlChannel, InputMessage) is safe because
        // Csound's channel/event ring buffers are documented thread-safe.
        if (csound_ == nullptr) {
            std::memset(audioData, 0, numFrames * nchnls_ * sizeof(float));
            return oboe::DataCallbackResult::Continue;
        }

        auto* out = static_cast<float*>(audioData);
        const int channels = nchnls_;
        const float invZeroDb = static_cast<float>(1.0 / zerodbfs_);

        int frameIndex = 0;
        while (frameIndex < numFrames) {
            // Render one Csound k-period if our pending buffer is empty.
            if (spoutCursor_ >= ksmps_) {
                int rc = csoundPerformKsmps(csound_);
                if (rc != 0) {
                    // Score finished or engine soft-stopped. Don't tear down
                    // (see class-doc rule #1). Zero out the rest of this
                    // Oboe buffer and keep the stream alive.
                    int remaining = (numFrames - frameIndex) * channels;
                    std::memset(out + frameIndex * channels, 0,
                                remaining * sizeof(float));
                    return oboe::DataCallbackResult::Continue;
                }
                spoutCursor_ = 0;
            }

            const MYFLT* spout = csoundGetSpout(csound_);
            int copyFrames = std::min(numFrames - frameIndex, ksmps_ - spoutCursor_);
            for (int f = 0; f < copyFrames; ++f) {
                for (int c = 0; c < channels; ++c) {
                    MYFLT s = spout[(spoutCursor_ + f) * channels + c];
                    out[(frameIndex + f) * channels + c] =
                        static_cast<float>(s) * invZeroDb;
                }
            }
            spoutCursor_ += copyFrames;
            frameIndex   += copyFrames;
        }
        return oboe::DataCallbackResult::Continue;
    }

    // ─── Event injection (called from UI thread via JNI) ────────────────

    void setControlChannel(const char* name, double value) {
        if (csound_ != nullptr) {
            csoundSetControlChannel(csound_, name, value);
        }
    }

    void inputMessage(const char* score) {
        if (csound_ != nullptr) {
            csoundInputMessage(csound_, score);
        }
    }

    double getControlChannel(const char* name) {
        if (csound_ == nullptr) return 0.0;
        return csoundGetControlChannel(csound_, name, nullptr);
    }

 private:
    std::mutex lifecycle_mutex_;
    CSOUND* csound_ = nullptr;
    std::shared_ptr<oboe::AudioStream> stream_;

    double sr_       = 44100.0;
    int    ksmps_    = 32;
    int    nchnls_   = 2;
    double zerodbfs_ = 1.0;

    // Position within the current Csound k-period buffer. Initial value of
    // ksmps_ means "the buffer is empty, render a fresh one immediately."
    int spoutCursor_ = 1 << 30;
};

// One engine per process. The activity owns its lifecycle but the C++ object
// outlives onDestroy — see EtherEngine::stop() comment for why we never
// destroy Csound.
EtherEngine& gEngine() {
    static EtherEngine instance;
    return instance;
}

std::string jstringToStd(JNIEnv* env, jstring js) {
    if (js == nullptr) return {};
    const char* chars = env->GetStringUTFChars(js, nullptr);
    std::string s = chars ? chars : "";
    if (chars) env->ReleaseStringUTFChars(js, chars);
    return s;
}

} // namespace

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeLoad(JNIEnv* env, jobject, jstring csdText) {
    return gEngine().load(jstringToStd(env, csdText)) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jboolean JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeStart(JNIEnv*, jobject) {
    return gEngine().start() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeStop(JNIEnv*, jobject) {
    gEngine().stop();
}

JNIEXPORT void JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeSetControlChannel(JNIEnv* env, jobject,
                                                                jstring name, jdouble value) {
    auto n = jstringToStd(env, name);
    gEngine().setControlChannel(n.c_str(), value);
}

JNIEXPORT void JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeInputMessage(JNIEnv* env, jobject, jstring score) {
    auto s = jstringToStd(env, score);
    gEngine().inputMessage(s.c_str());
}

JNIEXPORT jdouble JNICALL
Java_com_humblebee_etherpad_EtherEngine_nativeGetControlChannel(JNIEnv* env, jobject, jstring name) {
    auto n = jstringToStd(env, name);
    return gEngine().getControlChannel(n.c_str());
}

} // extern "C"
