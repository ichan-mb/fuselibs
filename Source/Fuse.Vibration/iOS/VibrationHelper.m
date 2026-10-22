#import <iOS/VibrationHelper.h>

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <math.h>

#if __has_include(<CoreHaptics/CoreHaptics.h>)
#import <CoreHaptics/CoreHaptics.h>
#endif

@interface FuseVibrationService ()

#if __has_include(<CoreHaptics/CoreHaptics.h>)
@property (nonatomic, strong) CHHapticEngine *engine;
@property (nonatomic, strong) NSMutableArray<id<CHHapticAdvancedPatternPlayer>> *players;
@property (nonatomic, assign) NSInteger generation;
#endif

@property (nonatomic, strong) NSTimer *impactTimer;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;
@property (nonatomic, assign) NSInteger impactGeneration;

- (BOOL)playTimedImpactForTimings:(NSArray<NSNumber *> *)timings
                       amplitudes:(NSArray<NSNumber *> *)amplitudes
                           repeat:(NSInteger)repeat
                        intensity:(double)intensity
                        sharpness:(double)sharpness;
- (void)stopTimedImpact;
- (void)resetEngine;

@end

@implementation FuseVibrationService

+ (instancetype)sharedInstance
{
	static FuseVibrationService *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[FuseVibrationService alloc] init];
	});
	return instance;
}

- (instancetype)init
{
	self = [super init];
	if (self)
	{
#if __has_include(<CoreHaptics/CoreHaptics.h>)
		_players = [NSMutableArray array];
#endif
	}
	return self;
}

- (BOOL)isSupported
{
#if __has_include(<CoreHaptics/CoreHaptics.h>)
	if (@available(iOS 13.0, *))
	{
		if ([CHHapticEngine capabilitiesForHardware].supportsHaptics)
			return YES;
	}
#endif

	// Core Haptics is unavailable on some devices that still have a vibration
	// motor (for example iPhone 7), so fall back to the device idiom.
	return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
}

- (NSString *)buildVersion
{
	return @"2026-10-21-duration-fix-7";
}

- (BOOL)hasAmplitudeControl
{
	// Core Haptics lets us control haptic intensity; the impact feedback
	// generators expose `impactOccurredWithIntensity:` as well.
	return [self isSupported];
}

- (BOOL)prepare
{
	// The timed impact sequencer uses UIImpactFeedbackGenerator, so there is
	// no audio session or Core Haptics engine to pre-warm.
	return [self isSupported];
}

- (BOOL)vibrateForDuration:(double)seconds
                 intensity:(double)intensity
                 sharpness:(double)sharpness
{
	if (!(seconds > 0) || isinf(seconds) || isnan(seconds))
		return NO;

	return [self playTimedImpactForTimings:@[ @0, [NSNumber numberWithDouble:seconds * 1000.0] ]
	                            amplitudes:nil
	                                repeat:-1
	                             intensity:intensity
	                             sharpness:sharpness];
}

- (BOOL)vibrateWithTimings:(NSArray<NSNumber *> *)timings
                amplitudes:(NSArray<NSNumber *> *)amplitudes
                    repeat:(NSInteger)repeat
                 intensity:(double)intensity
                 sharpness:(double)sharpness
{
	if (timings.count == 0)
		return NO;

	BOOL hasVibratingSegment = NO;
	for (NSUInteger i = 1; i < timings.count; i += 2)
	{
		if ([timings[i] doubleValue] > 0)
		{
			hasVibratingSegment = YES;
			break;
		}
	}

	if (!hasVibratingSegment)
		return NO;

	return [self playTimedImpactForTimings:timings
	                            amplitudes:amplitudes
	                                repeat:repeat
	                             intensity:intensity
	                             sharpness:sharpness];
}

- (BOOL)playTimedImpactForTimings:(NSArray<NSNumber *> *)timings
                       amplitudes:(NSArray<NSNumber *> *)amplitudes
                           repeat:(NSInteger)repeat
                        intensity:(double)intensity
                        sharpness:(double)sharpness
{
	if (timings.count == 0)
		return NO;

	if (repeat < -1 || repeat >= (NSInteger)timings.count)
		repeat = -1;

	double totalDuration = 0;
	BOOL hasVibratingSegment = NO;
	for (NSUInteger i = 0; i < timings.count; i++)
	{
		double duration = MAX(0.0, [timings[i] doubleValue] / 1000.0);
		totalDuration += duration;
		if ((i % 2) == 1 && duration > 0)
			hasVibratingSegment = YES;
	}

	if (!hasVibratingSegment || totalDuration <= 0)
		return NO;

	double prefixDuration = 0;
	if (repeat > 0)
	{
		for (NSInteger i = 0; i < repeat; i++)
			prefixDuration += MAX(0.0, [timings[i] doubleValue] / 1000.0);
	}

	double tailDuration = 0;
	if (repeat >= 0)
	{
		for (NSUInteger i = (NSUInteger)repeat; i < timings.count; i++)
			tailDuration += MAX(0.0, [timings[i] doubleValue] / 1000.0);
	}

	if (repeat >= 0 && tailDuration <= 0)
		repeat = -1;

	UIImpactFeedbackStyle style = UIImpactFeedbackStyleMedium;
	if (sharpness < 0.34)
		style = UIImpactFeedbackStyleSoft;
	else if (sharpness > 0.66)
		style = UIImpactFeedbackStyleRigid;

	double clampedIntensity = MIN(MAX(intensity, 0.0), 1.0);
	BOOL looping = repeat >= 0;

	// Timer and generator state is only touched on the main queue.
	dispatch_async(dispatch_get_main_queue(), ^{
		self.impactGeneration++;
		NSInteger generation = self.impactGeneration;

		[self.impactTimer invalidate];
		self.impactTimer = nil;

		self.impactGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
		[self.impactGenerator prepare];

		NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
		__block double nextImpact = 0;

		self.impactTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES block:^(NSTimer *timer) {
			if (generation != self.impactGeneration)
			{
				[timer invalidate];
				return;
			}

			double elapsed = [NSDate timeIntervalSinceReferenceDate] - start;
			double phase;

			if (!looping)
			{
				if (elapsed >= totalDuration)
				{
					[timer invalidate];
					if (self.impactTimer == timer)
						self.impactTimer = nil;
					return;
				}

				phase = elapsed;
			}
			else if (repeat == 0)
			{
				phase = fmod(elapsed, totalDuration);
			}
			else
			{
				if (elapsed < prefixDuration)
					phase = elapsed;
				else
					phase = prefixDuration + fmod(elapsed - prefixDuration, tailDuration);
			}

			double cursor = 0;
			BOOL inOnSegment = NO;
			double amplitude = clampedIntensity;

			for (NSUInteger i = 0; i < timings.count; i++)
			{
				double duration = MAX(0.0, [timings[i] doubleValue] / 1000.0);
				if (phase >= cursor && phase < cursor + duration)
				{
					if ((i % 2) == 1)
					{
						inOnSegment = YES;
						if (amplitudes != nil && i < amplitudes.count)
							amplitude *= [amplitudes[i] doubleValue];
					}

					break;
				}

				cursor += duration;
			}

			if (!inOnSegment)
			{
				// Fire immediately when the next on-segment starts.
				nextImpact = elapsed;
				return;
			}

			if (elapsed >= nextImpact)
			{
				[self.impactGenerator impactOccurredWithIntensity:MIN(MAX(amplitude, 0.0), 1.0)];
				nextImpact = elapsed + 0.12;
			}
		}];
	});

	return YES;
}

- (void)stopTimedImpact
{
	dispatch_async(dispatch_get_main_queue(), ^{
		self.impactGeneration++;
		[self.impactTimer invalidate];
		self.impactTimer = nil;
		self.impactGenerator = nil;
	});
}

- (void)cancel
{
	[self stopTimedImpact];

#if __has_include(<CoreHaptics/CoreHaptics.h>)
	if (@available(iOS 13.0, *))
	{
		[self stopAllPlayers];
	}
#endif
}

#if __has_include(<CoreHaptics/CoreHaptics.h>)
- (BOOL)playCoreHapticsTimings:(NSArray<NSNumber *> *)timings
                    amplitudes:(NSArray<NSNumber *> *)amplitudes
                        repeat:(NSInteger)repeat
                     intensity:(double)intensity
                     sharpness:(double)sharpness
{
	if (![self ensureEngine])
		return NO;

	[self stopAllPlayers];
	NSError *error = nil;

	if (repeat < 0)
	{
		if ([self playEventsForTimings:timings
		                      amplitudes:amplitudes
		                       intensity:intensity
		                       sharpness:sharpness
		                        loop:NO
		                        loopEnd:0
		                           error:&error])
			return YES;

		// The engine may have stopped while idle. Recreate it and retry once.
		[self resetEngine];
		if (![self ensureEngine])
			return NO;

		return [self playEventsForTimings:timings
		                       amplitudes:amplitudes
		                        intensity:intensity
		                        sharpness:sharpness
		                         loop:NO
		                         loopEnd:0
		                            error:&error];
	}

	// `repeat` is the index in the timings array to loop from. Play the
	// prefix once, then loop the tail.
	NSArray<NSNumber *> *prefixTimings = [timings subarrayWithRange:NSMakeRange(0, repeat)];
	NSArray<NSNumber *> *tailTimings = [timings subarrayWithRange:NSMakeRange(repeat, timings.count - repeat)];

	NSArray<NSNumber *> *prefixAmplitudes = nil;
	NSArray<NSNumber *> *tailAmplitudes = nil;
	if (amplitudes != nil && amplitudes.count == timings.count)
	{
		prefixAmplitudes = [amplitudes subarrayWithRange:NSMakeRange(0, repeat)];
		tailAmplitudes = [amplitudes subarrayWithRange:NSMakeRange(repeat, timings.count - repeat)];
	}

	double prefixDuration = [self durationForTimings:prefixTimings];
	double tailDuration = [self durationForTimings:tailTimings];

	if (prefixTimings.count > 0)
	{
		if (![self playEventsForTimings:prefixTimings
		                     amplitudes:prefixAmplitudes
		                      intensity:intensity
		                      sharpness:sharpness
		                           loop:NO
		                        loopEnd:0
		                          error:&error])
		{
			[self resetEngine];
			if (![self ensureEngine])
				return NO;

			[self playEventsForTimings:prefixTimings
			               amplitudes:prefixAmplitudes
			                intensity:intensity
			                sharpness:sharpness
			                     loop:NO
			                  loopEnd:0
			                    error:&error];
		}
	}

	if (tailTimings.count == 0)
		return YES;

	NSInteger generation = self.generation;
	dispatch_block_t startTail = ^{
		if (generation != self.generation)
			return;

		[self playEventsForTimings:tailTimings
		                amplitudes:tailAmplitudes
		                 intensity:intensity
		                 sharpness:sharpness
		                  loop:YES
		                  loopEnd:tailDuration
		                     error:nil];
	};

	if (prefixDuration <= 0)
		startTail();
	else
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(prefixDuration * NSEC_PER_SEC)),
			dispatch_get_main_queue(), startTail);

	return YES;
}

- (BOOL)playEventsForTimings:(NSArray<NSNumber *> *)timings
                  amplitudes:(NSArray<NSNumber *> *)amplitudes
                   intensity:(double)intensity
                   sharpness:(double)sharpness
                    loop:(BOOL)loop
                    loopEnd:(double)loopEnd
                       error:(NSError **)error
{
	NSArray<CHHapticEvent *> *events = [self eventsForTimings:timings
	                                               amplitudes:amplitudes
	                                                intensity:intensity
	                                                sharpness:sharpness];
	if (events.count == 0)
		return NO;

	CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:events parameters:@[] error:error];
	if (pattern == nil)
	{
		NSLog(@"Fuse.Vibration: could not create haptic pattern: %@", error != nil ? *error : nil);
		return NO;
	}

	id<CHHapticAdvancedPatternPlayer> player = [self.engine createAdvancedPlayerWithPattern:pattern error:error];
	if (player == nil)
	{
		NSLog(@"Fuse.Vibration: could not create haptic player: %@", error != nil ? *error : nil);
		return NO;
	}

	if (loop)
	{
		player.loopEnabled = YES;
		player.loopEnd = loopEnd;
	}

	[self.players addObject:player];

	BOOL started = [player startAtTime:0 error:error];
	if (!started)
		NSLog(@"Fuse.Vibration: could not start haptic player: %@", error != nil ? *error : nil);

	return started;
}

- (NSArray<CHHapticEvent *> *)eventsForTimings:(NSArray<NSNumber *> *)timings
                                    amplitudes:(NSArray<NSNumber *> *)amplitudes
                                     intensity:(double)intensity
                                     sharpness:(double)sharpness
{
	NSMutableArray<CHHapticEvent *> *events = [NSMutableArray array];
	double time = 0;

	for (NSUInteger i = 0; i < timings.count; i++)
	{
		double duration = MAX(0.0, [timings[i] doubleValue] / 1000.0);

		// Index 0 is the initial off delay, so "on" segments are odd indexes.
		if ((i % 2) == 1 && duration > 0)
		{
			double amplitude = intensity;
			if (amplitudes != nil && i < amplitudes.count)
				amplitude *= [amplitudes[i] doubleValue];

			amplitude = MIN(MAX(amplitude, 0.0), 1.0);
			double texture = MIN(MAX(sharpness, 0.0), 1.0);

			CHHapticEventParameter *intensityParameter =
				[[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:(float)amplitude];
			CHHapticEventParameter *sharpnessParameter =
				[[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:(float)texture];

			CHHapticEvent *event =
				[[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
				                              parameters:@[intensityParameter, sharpnessParameter]
				                            relativeTime:time
				                                duration:duration];
			[events addObject:event];
		}

		time += duration;
	}

	return events;
}

- (double)durationForTimings:(NSArray<NSNumber *> *)timings
{
	double total = 0;
	for (NSNumber *timing in timings)
		total += MAX(0.0, [timing doubleValue] / 1000.0);
	return total;
}

- (BOOL)ensureEngine
{
	if (self.engine != nil)
		return YES;

	// Core Haptics needs an active audio session on some devices. Configure it
	// on a background queue; AVAudioSession warns when activated on the main
	// thread while the session is active.
	static dispatch_queue_t audioQueue;
	static dispatch_once_t audioQueueOnce;
	dispatch_once(&audioQueueOnce, ^{
		audioQueue = dispatch_queue_create("com.fuse.vibration.audio", DISPATCH_QUEUE_SERIAL);
	});

	dispatch_sync(audioQueue, ^{
		AVAudioSession *audioSession = [AVAudioSession sharedInstance];
		[audioSession setCategory:AVAudioSessionCategoryAmbient error:nil];
		[audioSession setActive:YES error:nil];
	});

	NSError *error = nil;
	self.engine = [[CHHapticEngine alloc] initAndReturnError:&error];
	if (self.engine == nil)
	{
		NSLog(@"Fuse.Vibration: could not create the haptic engine: %@", error);
		return NO;
	}

	self.engine.playsHapticsOnly = YES;
	self.engine.autoShutdownEnabled = NO;

	__weak FuseVibrationService *weakSelf = self;
	self.engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
		weakSelf.engine = nil;
		[weakSelf.players removeAllObjects];
	};
	self.engine.resetHandler = ^{
		[weakSelf.engine startAndReturnError:nil];
	};

	if ([self.engine startAndReturnError:&error])
		return YES;

	NSLog(@"Fuse.Vibration: could not start the haptic engine: %@", error);
	return NO;
}

- (void)resetEngine
{
	[self stopAllPlayers];
	self.engine = nil;
}

- (void)stopAllPlayers
{
	self.generation++;

	for (id<CHHapticAdvancedPatternPlayer> player in self.players)
		[player stopAtTime:0 error:nil];

	[self.players removeAllObjects];
}
#endif

@end
