#import <iOS/VibrationHelper.h>

#import <UIKit/UIKit.h>
#import <math.h>

@interface FuseVibrationService ()

@property (nonatomic, strong) NSTimer *impactTimer;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;
@property (nonatomic, assign) NSInteger impactGeneration;

- (BOOL)playTimedImpactForTimings:(NSArray<NSNumber *> *)timings
                       amplitudes:(NSArray<NSNumber *> *)amplitudes
                           repeat:(NSInteger)repeat
                        intensity:(double)intensity
                        sharpness:(double)sharpness;
- (void)stopTimedImpact;

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

- (BOOL)isSupported
{
	return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
}

- (BOOL)hasAmplitudeControl
{
	return [self isSupported];
}

- (NSString *)buildVersion
{
	return @"2026-10-21-duration-fix-7";
}

- (BOOL)prepare
{
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
}

@end
