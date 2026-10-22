using Uno;
using Fuse.Android.Permissions;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.Vibration
{
	public enum VibrationType
	{
		Undefined,
		Soft,
		Rigid,
		Light,
		Medium,
		Heavy,
		Success,
		Warning,
		Error,
		Selection
	}

	/**
		Describes how a vibration should be categorized by the platform.
	*/
	public enum HapticUsage
	{
		Default,
		Touch,
		Notification,
		Alarm,
		Accessibility
	}

	/**
		A native haptic primitive.
	*/
	public enum HapticPrimitive
	{
		Undefined,
		Click,
		Thud,
		Tick,
		LowTick,
		Spin,
		QuickRise,
		QuickFall,
		SlowRise
	}

	/**
		A waveform vibration.

		`Timings` alternates off/on durations in milliseconds and starts with an
		off duration, matching Android's waveform semantics. `Amplitudes`, when
		provided, must have the same length and holds normalized 0..1 values.
		`Repeat` is the index in `Timings` to loop from, or `-1` to play once.
	*/
	public sealed class VibrationPattern
	{
		public double[] Timings;
		public double[] Amplitudes;
		public int Repeat;
		public double Intensity;
		public double Sharpness;
		public HapticUsage Usage;

		public VibrationPattern(double[] timings, double[] amplitudes, int repeat, double intensity, double sharpness, HapticUsage usage)
		{
			if (timings == null || timings.Length < 2)
				throw new ArgumentException("A vibration pattern must contain at least one off and one on duration.");

			if (amplitudes != null && amplitudes.Length != timings.Length)
				throw new ArgumentException("The amplitude array must have the same length as the timings array.");

			Timings = timings;
			Amplitudes = amplitudes;
			Repeat = (repeat >= -1 && repeat < timings.Length) ? repeat : -1;
			Intensity = Clamp01(intensity);
			Sharpness = Clamp01(sharpness);
			Usage = usage;
		}

		static double Clamp01(double value)
		{
			if (double.IsNaN(value) || value <= 0) return 0;
			if (value >= 1) return 1;
			return value;
		}
	}

	[ForeignInclude(Language.Java,
					"android.os.Vibrator",
					"android.app.Activity",
					"android.view.View",
					"android.view.HapticFeedbackConstants",
					"android.media.AudioAttributes",
					"android.os.Build",
					"android.os.VibrationEffect",
					"android.content.Context")]
	class AndroidVibrator
	{
		double[] _timings;
		double[] _amplitudes;
		bool _hasAmplitudes;
		int _amplitude;
		int _repeat;
		double _intensity;
		int _usage;
		VibrationType _style;
		HapticPrimitive _primitive;

		public AndroidVibrator(VibrationPattern pattern)
		{
			_timings = pattern.Timings;
			_amplitudes = pattern.Amplitudes;
			_hasAmplitudes = pattern.Amplitudes != null;
			_amplitude = ToAmplitude(pattern.Intensity);
			_repeat = pattern.Repeat;
			_usage = (int)pattern.Usage;
		}

		public AndroidVibrator(VibrationType style, double intensity)
		{
			_style = style;
			_intensity = intensity;
		}

		public AndroidVibrator(HapticPrimitive primitive, double intensity)
		{
			_primitive = primitive;
			_intensity = intensity;
		}

		static int ToAmplitude(double intensity)
		{
			if (double.IsNaN(intensity) || intensity <= 0) return 0;
			if (intensity >= 1) return 255;
			var value = (int)Math.Round(intensity * 255.0);
			return value < 1 ? 1 : value;
		}

		[Foreign(Language.Java)]
		public extern(Android) void Done(PlatformPermission permission)
		@{
			Activity a = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)a.getSystemService(Context.VIBRATOR_SERVICE);
			if (v == null)
				return;

			double[] unoTimings = @{AndroidVibrator:of(_this)._timings}.copyArray();
			long[] timings = new long[unoTimings.length];
			for (int i = 0; i < unoTimings.length; i++)
				timings[i] = (long)unoTimings[i];

			int usage = @{AndroidVibrator:of(_this)._usage};
			int audioUsage = AudioAttributes.USAGE_ASSISTANCE_SONIFICATION;
			switch (usage)
			{
				case 2: audioUsage = AudioAttributes.USAGE_NOTIFICATION; break;
				case 3: audioUsage = AudioAttributes.USAGE_ALARM; break;
				case 4: audioUsage = AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY; break;
				default: audioUsage = AudioAttributes.USAGE_ASSISTANCE_SONIFICATION; break;
			}

			AudioAttributes attributes = new AudioAttributes.Builder()
				.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
				.setUsage(audioUsage)
				.build();

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
			{
				VibrationEffect effect;
				if (@{AndroidVibrator:of(_this)._hasAmplitudes})
				{
					double[] unoAmplitudes = @{AndroidVibrator:of(_this)._amplitudes}.copyArray();
					int globalAmplitude = @{AndroidVibrator:of(_this)._amplitude};
					int[] amplitudes = new int[unoAmplitudes.length];
					for (int i = 0; i < unoAmplitudes.length; i++)
					{
						int baseAmplitude;
						if (unoAmplitudes[i] <= 0)
							baseAmplitude = 0;
						else if (unoAmplitudes[i] >= 1)
							baseAmplitude = 255;
						else
							baseAmplitude = Math.max(1, (int)Math.round(unoAmplitudes[i] * 255.0));

						amplitudes[i] = baseAmplitude <= 0 || globalAmplitude <= 0
							? 0
							: Math.max(1, (int)Math.round(baseAmplitude * globalAmplitude / 255.0));
					}
					effect = VibrationEffect.createWaveform(timings, amplitudes, @{AndroidVibrator:of(_this)._repeat});
				}
				else if (@{AndroidVibrator:of(_this)._amplitude} < 255)
				{
					int amplitude = @{AndroidVibrator:of(_this)._amplitude};
					int[] amplitudes = new int[timings.length];
					for (int i = 0; i < timings.length; i++)
						amplitudes[i] = (i % 2) == 1 ? amplitude : 0;
					effect = VibrationEffect.createWaveform(timings, amplitudes, @{AndroidVibrator:of(_this)._repeat});
				}
				else
				{
					effect = VibrationEffect.createWaveform(timings, @{AndroidVibrator:of(_this)._repeat});
				}
				v.vibrate(effect, attributes);
			}
			else
			{
				v.vibrate(timings, @{AndroidVibrator:of(_this)._repeat});
			}
		@}

		[Foreign(Language.Java)]
		public static extern(Android) bool IsSupported()
		@{
			Activity a = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)a.getSystemService(Context.VIBRATOR_SERVICE);
			return v != null && v.hasVibrator();
		@}

		[Foreign(Language.Java)]
		public static extern(Android) bool HasAmplitudeControl()
		@{
			if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
				return false;

			Activity a = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)a.getSystemService(Context.VIBRATOR_SERVICE);
			return v != null && v.hasVibrator() && v.hasAmplitudeControl();
		@}

		[Foreign(Language.Java)]
		public static extern(Android) void Cancel()
		@{
			Activity a = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)a.getSystemService(Context.VIBRATOR_SERVICE);
			if (v != null)
				v.cancel();
		@}

		public extern(Android) void Perform(PlatformPermission permission)
		{
			var amplitude = ToAmplitude(_intensity);
			switch (_style)
			{
				case VibrationType.Soft:
					PerformSoft(amplitude);
					break;
				case VibrationType.Rigid:
					PerformRigid(amplitude);
					break;
				case VibrationType.Light:
					PerformLight(amplitude);
					break;
				case VibrationType.Medium:
					PerformMedium(amplitude);
					break;
				case VibrationType.Heavy:
					PerformHeavy(amplitude);
					break;
				case VibrationType.Success:
					PerformSuccess(amplitude);
					break;
				case VibrationType.Warning:
					PerformWarning(amplitude);
					break;
				case VibrationType.Error:
					PerformError(amplitude);
					break;
				case VibrationType.Selection:
					PerformSelection(amplitude);
					break;
				default:
					PerformLight(amplitude);
					break;
			}
		}

		public extern(Android) void PerformPrimitive(PlatformPermission permission)
		{
			PerformPrimitiveNative((int)_primitive, ToAmplitude(_intensity));
		}

		[Foreign(Language.Java)]
		static extern(Android) void PerformPrimitiveNative(int primitive, int amplitude)
		@{
			if (amplitude <= 0)
				return;

			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			if (v == null)
				return;

			AudioAttributes attributes = new AudioAttributes.Builder()
				.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
				.setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
				.build();

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
			{
				int primitiveId;
				switch (primitive)
				{
					case 2: primitiveId = VibrationEffect.Composition.PRIMITIVE_THUD; break;
					case 3: primitiveId = VibrationEffect.Composition.PRIMITIVE_TICK; break;
					case 4: primitiveId = VibrationEffect.Composition.PRIMITIVE_LOW_TICK; break;
					case 5: primitiveId = VibrationEffect.Composition.PRIMITIVE_SPIN; break;
					case 6: primitiveId = VibrationEffect.Composition.PRIMITIVE_QUICK_RISE; break;
					case 7: primitiveId = VibrationEffect.Composition.PRIMITIVE_QUICK_FALL; break;
					case 8: primitiveId = VibrationEffect.Composition.PRIMITIVE_SLOW_RISE; break;
					default: primitiveId = VibrationEffect.Composition.PRIMITIVE_CLICK; break;
				}

				VibrationEffect effect = VibrationEffect.startComposition()
					.addPrimitive(primitiveId, (float)(amplitude / 255.0), 0)
					.compose();
				v.vibrate(effect, attributes);
			}
			else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
			{
				int duration = 30;
				switch (primitive)
				{
					case 2: duration = 60; break;
					case 5: duration = 50; break;
					case 6: case 7: case 8: duration = 40; break;
					default: duration = 30; break;
				}
				v.vibrate(VibrationEffect.createOneShot(duration, amplitude), attributes);
			}
			else
			{
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformSoft(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && amplitude >= 255) {
				v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK), audioAttributes);
			} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(30, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformRigid(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(50, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformLight(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && amplitude >= 255) {
				v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK), audioAttributes);
			} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(30, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformMedium(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(50, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformHeavy(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && amplitude >= 255) {
				v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK), audioAttributes);
			} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(70, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformSuccess(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			long[] pattern = new long[]{0, 50, 80, 50};
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				int[] base = new int[]{0, 50, 0, 50};
				int[] amplitudes = new int[base.length];
				for (int i = 0; i < base.length; i++)
					amplitudes[i] = base[i] > 0 ? Math.max(1, (int)Math.round(base[i] * amplitude / 255.0)) : 0;
				AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
				v.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1), audioAttributes);
			} else {
				v.vibrate(pattern, -1);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformWarning(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			long[] pattern = new long[]{0, 80, 20, 80};
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				int[] base = new int[]{0, 120, 0, 120};
				int[] amplitudes = new int[base.length];
				for (int i = 0; i < base.length; i++)
					amplitudes[i] = base[i] > 0 ? Math.max(1, (int)Math.round(base[i] * amplitude / 255.0)) : 0;
				AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
				v.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1), audioAttributes);
			} else {
				v.vibrate(pattern, -1);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformError(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			long[] pattern = new long[]{0, 40, 40, 40, 40, 40, 40, 60};
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				int[] base = new int[]{0, 100, 0, 100, 0, 100, 0, 120};
				int[] amplitudes = new int[base.length];
				for (int i = 0; i < base.length; i++)
					amplitudes[i] = base[i] > 0 ? Math.max(1, (int)Math.round(base[i] * amplitude / 255.0)) : 0;
				AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
				v.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1), audioAttributes);
			} else {
				v.vibrate(pattern, -1);
			}
		@}

		[Foreign(Language.Java)]
		static extern(Android) void PerformSelection(int amplitude)
		@{
			if (amplitude <= 0) return;
			Activity activity = com.fuse.Activity.getRootActivity();
			Vibrator v = (Vibrator)activity.getSystemService(Context.VIBRATOR_SERVICE);
			AudioAttributes audioAttributes = new AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build();
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && amplitude >= 255) {
				v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK), audioAttributes);
			} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				v.vibrate(VibrationEffect.createOneShot(20, amplitude), audioAttributes);
			} else {
				View view = activity.getWindow().getDecorView();
				view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING);
			}
		@}
	}

	[Require("source.include", "UIKit/UIKit.h")]
	[Require("source.include", "iOS/VibrationHelper.h")]
	[Require("xcode.framework", "AudioToolbox")]
	[Require("xcode.framework", "CoreHaptics")]
	[ForeignInclude(Language.ObjC, "AudioToolbox/AudioToolbox.h")]
	extern(iOS) class IOSTapticFeedback
	{
		[Foreign(Language.ObjC)]
		public static extern(iOS) bool IsSupported()
		@{
			return [[FuseVibrationService sharedInstance] isSupported];
		@}

		[Foreign(Language.ObjC)]
		public static extern(iOS) bool HasAmplitudeControl()
		@{
			return [[FuseVibrationService sharedInstance] hasAmplitudeControl];
		@}

		[Foreign(Language.ObjC)]
		public static extern(iOS) string BuildVersion()
		@{
			return [[FuseVibrationService sharedInstance] buildVersion];
		@}

		[Foreign(Language.ObjC)]
		public static extern(iOS) bool Prepare()
		@{
			return [[FuseVibrationService sharedInstance] prepare];
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) bool VibrateDuration(double seconds, double intensity, double sharpness)
		@{
			return [[FuseVibrationService sharedInstance] vibrateForDuration:seconds intensity:intensity sharpness:sharpness];
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) bool VibrateTimings(double[] timings, double[] amplitudes, bool hasAmplitudes, int repeat, double intensity, double sharpness)
		@{
			int timingCount = @{double[]:of(timings).Length:Get()};
			NSMutableArray<NSNumber*>* timingArray = [NSMutableArray arrayWithCapacity:timingCount];
			for (int i = 0; i < timingCount; i++)
				[timingArray addObject:[NSNumber numberWithDouble:@{double[]:of(timings).Get(i)}]];

			NSMutableArray<NSNumber*>* amplitudeArray = nil;
			if (hasAmplitudes)
			{
				int amplitudeCount = @{double[]:of(amplitudes).Length:Get()};
				amplitudeArray = [NSMutableArray arrayWithCapacity:amplitudeCount];
				for (int i = 0; i < amplitudeCount; i++)
					[amplitudeArray addObject:[NSNumber numberWithDouble:@{double[]:of(amplitudes).Get(i)}]];
			}

			return [[FuseVibrationService sharedInstance]
				vibrateWithTimings:timingArray
					   amplitudes:amplitudeArray
						   repeat:(NSInteger)repeat
						intensity:intensity
						sharpness:sharpness];
		@}

		public static extern(iOS) bool Vibrate(double seconds)
		{
			return VibrateDuration(seconds, 1.0, 0.5);
		}

		public static extern(iOS) bool Vibrate(double seconds, double intensity, double sharpness)
		{
			return VibrateDuration(seconds, intensity, sharpness);
		}

		public static extern(iOS) bool Vibrate(VibrationPattern pattern)
		{
			return VibrateTimings(pattern.Timings, pattern.Amplitudes, pattern.Amplitudes != null, pattern.Repeat, pattern.Intensity, pattern.Sharpness);
		}

		[Foreign(Language.ObjC)]
		public static extern(iOS) void Cancel()
		@{
			[[FuseVibrationService sharedInstance] cancel];
		@}

		[Foreign(Language.ObjC)]
		public static extern(iOS) void PlaySystemVibration()
		@{
			AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
		@}

		public static extern(iOS) void Perform(VibrationType style)
		{
			Perform(style, 1.0);
		}

		public static extern(iOS) void Perform(VibrationType style, double intensity)
		{
			switch (style)
			{
				case VibrationType.Soft:
					PerformSoft(intensity);
					break;
				case VibrationType.Rigid:
					PerformRigid(intensity);
					break;
				case VibrationType.Light:
					PerformLight(intensity);
					break;
				case VibrationType.Medium:
					PerformMedium(intensity);
					break;
				case VibrationType.Heavy:
					PerformHeavy(intensity);
					break;
				case VibrationType.Success:
					PerformSuccess(intensity);
					break;
				case VibrationType.Warning:
					PerformWarning(intensity);
					break;
				case VibrationType.Error:
					PerformError(intensity);
					break;
				case VibrationType.Selection:
					PerformSelection(intensity);
					break;
				default:
					PerformLight(intensity);
					break;
			}
		}

		public static extern(iOS) void Perform(HapticPrimitive primitive, double intensity)
		{
			switch (primitive)
			{
				case HapticPrimitive.Thud:
				case HapticPrimitive.QuickFall:
					PerformHeavy(intensity);
					break;
				case HapticPrimitive.Spin:
				case HapticPrimitive.SlowRise:
					PerformMedium(intensity);
					break;
				default:
					PerformLight(intensity);
					break;
			}
		}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformSoft(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImpactFeedbackGenerator * feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
				[feedback impactOccurredWithIntensity:MIN(MAX(intensity, 0.0), 1.0)];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformRigid(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImpactFeedbackGenerator * feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
				[feedback impactOccurredWithIntensity:MIN(MAX(intensity, 0.0), 1.0)];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformLight(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImpactFeedbackGenerator * feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
				[feedback impactOccurredWithIntensity:MIN(MAX(intensity, 0.0), 1.0)];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformMedium(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImpactFeedbackGenerator * feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
				[feedback impactOccurredWithIntensity:MIN(MAX(intensity, 0.0), 1.0)];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformHeavy(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UIImpactFeedbackGenerator * feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
				[feedback impactOccurredWithIntensity:MIN(MAX(intensity, 0.0), 1.0)];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformSuccess(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UINotificationFeedbackGenerator * feedback = [[UINotificationFeedbackGenerator alloc] init];
				[feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformWarning(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UINotificationFeedbackGenerator * feedback = [[UINotificationFeedbackGenerator alloc] init];
				[feedback notificationOccurred:UINotificationFeedbackTypeWarning];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformError(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UINotificationFeedbackGenerator * feedback = [[UINotificationFeedbackGenerator alloc] init];
				[feedback notificationOccurred:UINotificationFeedbackTypeError];
			});
		@}

		[Foreign(Language.ObjC)]
		static extern(iOS) void PerformSelection(double intensity)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				UISelectionFeedbackGenerator * feedback = [[UISelectionFeedbackGenerator alloc] init];
				[feedback selectionChanged];
				[feedback prepare];
			});
		@}
	}

	[Require("xcode.framework", "AudioToolbox")]
	[ForeignInclude(Language.ObjC, "AudioToolbox/AudioToolbox.h")]
	public static class Vibration
	{
		static bool IsValidDuration(double seconds)
		{
			return !double.IsNaN(seconds) && !double.IsInfinity(seconds) && seconds > 0;
		}

		public static extern(Android) bool IsSupported()
		{
			return AndroidVibrator.IsSupported();
		}

		public static extern(iOS) bool IsSupported()
		{
			return IOSTapticFeedback.IsSupported();
		}

		public static extern(Android) bool HasAmplitudeControl()
		{
			return AndroidVibrator.HasAmplitudeControl();
		}

		public static extern(iOS) bool HasAmplitudeControl()
		{
			return IOSTapticFeedback.HasAmplitudeControl();
		}

		/**
			Prepares the platform haptics. Returns `false` when the device cannot
			vibrate.
		*/
		public static extern(Android) bool Prepare()
		{
			return AndroidVibrator.IsSupported();
		}

		public static extern(iOS) bool Prepare()
		{
			return IOSTapticFeedback.Prepare();
		}

		public static extern(Android) string HelperBuild()
		{
			return "android";
		}

		public static extern(iOS) string HelperBuild()
		{
			return IOSTapticFeedback.BuildVersion();
		}

		/**
			Vibrates for `seconds` seconds. Returns `false` when the device cannot
			vibrate or the duration is not a positive, finite number.
		*/
		public static extern(Android) bool Vibrate(double seconds)
		{
			return Vibrate(seconds, 1.0, 0.5, HapticUsage.Default);
		}

		public static extern(iOS) bool Vibrate(double seconds)
		{
			if (!IsValidDuration(seconds))
				return false;

			if (!IOSTapticFeedback.Vibrate(seconds))
				IOSTapticFeedback.PlaySystemVibration();

			return true;
		}

		public static extern(Android) bool Vibrate(double seconds, double amplitude, double sharpness, HapticUsage usage)
		{
			if (!IsValidDuration(seconds) || !AndroidVibrator.IsSupported())
				return false;

			var pattern = new VibrationPattern(new double[] { 0, seconds * 1000 }, null, -1, amplitude, sharpness, usage);
			return Vibrate(pattern);
		}

		public static extern(iOS) bool Vibrate(double seconds, double amplitude, double sharpness, HapticUsage usage)
		{
			if (!IsValidDuration(seconds))
				return false;

			if (!IOSTapticFeedback.Vibrate(seconds, amplitude, sharpness))
				IOSTapticFeedback.PlaySystemVibration();

			return true;
		}

		/**
			Plays a waveform. Returns `false` when the device cannot vibrate.
		*/
		public static extern(Android) bool Vibrate(VibrationPattern pattern)
		{
			if (pattern == null || !AndroidVibrator.IsSupported())
				return false;

			Permissions.Request(Permissions.Android.VIBRATE).Then(new AndroidVibrator(pattern).Done);
			return true;
		}

		public static extern(iOS) bool Vibrate(VibrationPattern pattern)
		{
			if (pattern == null)
				return false;

			if (!IOSTapticFeedback.Vibrate(pattern))
				IOSTapticFeedback.PlaySystemVibration();

			return true;
		}

		/**
			Plays a short haptic feedback pattern. Returns `false` when the device
			cannot vibrate.
		*/
		public static extern(Android) bool Feedback(VibrationType type)
		{
			return Feedback(type, 1.0);
		}

		public static extern(iOS) bool Feedback(VibrationType type)
		{
			return Feedback(type, 1.0);
		}

		public static extern(Android) bool Feedback(VibrationType type, double intensity)
		{
			if (!AndroidVibrator.IsSupported())
				return false;

			Permissions.Request(Permissions.Android.VIBRATE).Then(new AndroidVibrator(type, intensity).Perform);
			return true;
		}

		public static extern(iOS) bool Feedback(VibrationType type, double intensity)
		{
			IOSTapticFeedback.Perform(type, intensity);
			return IOSTapticFeedback.IsSupported();
		}

		/**
			Plays a native haptic primitive. Returns `false` when the device
			cannot vibrate.
		*/
		public static extern(Android) bool Primitive(HapticPrimitive primitive, double intensity)
		{
			if (primitive == HapticPrimitive.Undefined || !AndroidVibrator.IsSupported())
				return false;

			Permissions.Request(Permissions.Android.VIBRATE).Then(new AndroidVibrator(primitive, intensity).PerformPrimitive);
			return true;
		}

		public static extern(iOS) bool Primitive(HapticPrimitive primitive, double intensity)
		{
			if (primitive == HapticPrimitive.Undefined)
				return false;

			IOSTapticFeedback.Perform(primitive, intensity);
			return IOSTapticFeedback.IsSupported();
		}

		/**
			Stops any ongoing vibration.
		*/
		public static extern(Android) void Cancel()
		{
			AndroidVibrator.Cancel();
		}

		public static extern(iOS) void Cancel()
		{
			IOSTapticFeedback.Cancel();
		}

		public static extern(!MOBILE) bool IsSupported() { return false; }

		public static extern(!MOBILE) bool HasAmplitudeControl() { return false; }

		public static extern(!MOBILE) bool Prepare() { return false; }

		public static extern(!MOBILE) string HelperBuild() { return "desktop"; }

		public static extern(!MOBILE) bool Vibrate(double seconds) { return false; }

		public static extern(!MOBILE) bool Vibrate(double seconds, double amplitude, double sharpness, HapticUsage usage) { return false; }

		public static extern(!MOBILE) bool Vibrate(VibrationPattern pattern) { return false; }

		public static extern(!MOBILE) bool Feedback(VibrationType type) { return false; }

		public static extern(!MOBILE) bool Feedback(VibrationType type, double intensity) { return false; }

		public static extern(!MOBILE) bool Primitive(HapticPrimitive primitive, double intensity) { return false; }

		public static extern(!MOBILE) void Cancel() { }
	}
}
