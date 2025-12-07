#pragma once

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AudioPlayerHelper : NSObject

+ (void)setupAudioSession;
+ (void)teardownAudioSession;

@end
