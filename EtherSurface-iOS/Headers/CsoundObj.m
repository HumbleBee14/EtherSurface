// CsoundObj.m — Stub implementation for compile-testing only.
// Replace with the real Csound iOS framework before running on device.

#import "CsoundObj.h"

@implementation CsoundObj

- (void)play:(NSString *)csdFilePath {
    NSLog(@"[CsoundObj STUB] play: %@", csdFilePath);
}

- (void)stop {
    NSLog(@"[CsoundObj STUB] stop");
}

- (void)sendScore:(NSString *)score {
    NSLog(@"[CsoundObj STUB] sendScore: %@", score);
}

- (nullable float *)getInputChannelPtr:(NSString *)channelName {
    NSLog(@"[CsoundObj STUB] getInputChannelPtr: %@", channelName);
    return NULL;
}

- (nullable void *)getCsound {
    return NULL;
}

@end
