// CsoundObj.h — Stub header for compile-testing the iOS port.
//
// This file provides the minimal API surface that EtherSurface uses.
// Replace with the real CsoundObj.h from the Csound iOS framework
// before running on a device.
//
// The real CsoundObj comes from:
//   https://github.com/csound/csound/tree/develop/iOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CsoundObj : NSObject

/// Compile the CSD at `csdFilePath` and start the audio engine.
- (void)play:(NSString *)csdFilePath;

/// Stop the audio engine.
- (void)stop;

/// Send a score event string (e.g. "i1.0 0 -2 0").
- (void)sendScore:(NSString *)score;

/// Get a pointer to a named input control channel.
/// Write to the returned float* to set channel values read by chnget in the CSD.
- (nullable float *)getInputChannelPtr:(NSString *)channelName;

/// Get the raw CSOUND pointer (for advanced use).
- (nullable void *)getCsound;

@end

NS_ASSUME_NONNULL_END
