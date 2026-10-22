#import <Foundation/Foundation.h>

/**
	Shared iOS vibration backend.

	Uses a timed `UIImpactFeedbackGenerator` sequence for durations and
	patterns. Amplitude maps to impact intensity and sharpness selects the
	impact style. `cancel` stops the current sequence.
*/
@interface FuseVibrationService : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isSupported;
- (BOOL)hasAmplitudeControl;
- (NSString *)buildVersion;
- (BOOL)prepare;

/**
	Vibrates for `seconds` seconds.
*/
- (BOOL)vibrateForDuration:(double)seconds
                 intensity:(double)intensity
                 sharpness:(double)sharpness;

/**
	Plays a waveform.

	`timings` alternates off/on durations in milliseconds and starts with an
	off duration, matching Android's `VibrationEffect.createWaveform`.
	`amplitudes`, when provided, holds normalized 0..1 values with the same
	length as `timings`. `repeat` is the index in `timings` to loop from, or
	`-1` to play once.
*/
- (BOOL)vibrateWithTimings:(NSArray<NSNumber *> *)timings
                amplitudes:(NSArray<NSNumber *> *)amplitudes
                    repeat:(NSInteger)repeat
                 intensity:(double)intensity
                 sharpness:(double)sharpness;

- (void)cancel;

@end
