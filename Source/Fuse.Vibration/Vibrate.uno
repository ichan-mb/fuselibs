using Uno;
using Uno.UX;
using Fuse.Triggers.Actions;

namespace Fuse.Vibration
{
	/** Vibrate the device for a duration, by vibration type, or with a pattern

		You'll find this trigger action in the Fuse.Vibration package, which have to be referenced from your uno project.
		For example:
		```json
			{
				"references": [
					"Fuse",
					"FuseJS",
					"Fuse.Vibration"
				]
		  	}
		```
		## Example
		```xml
			<StackPanel Margin="20">
				<Button Margin="10" Text="Vibrate">
					<Clicked>
						<Vibrate Duration="5" />
					</Clicked>
				</Button>
			</StackPanel>
		```

		`Duration` is in seconds and defaults to `0.4`. On iOS, durations are
		honored through Core Haptics on devices that support it; other devices
		fall back to the system vibration, which has a fixed length.

		On iOS you can do vibration by leveraging Taptic Engine, and on Android
		the types are mapped to the closest `VibrationEffect` or haptic feedback
		constant. There are 9 types of vibration :
		* Soft
		* Rigid
		* Light
		* Medium
		* Heavy
		* Success
		* Warning
		* Error
		* Selection
		To activate it, just pass those value to `VibrationType` property

		##Example
		```xml
			<StackPanel Margin="20">
				<!-- Uses the Taptic Engine on iOS and haptic effects on Android -->
				<Button Margin="10" Text="Heavy Vibrate">
					<Clicked>
						<Vibrate VibrationType="Heavy" />
					</Clicked>
				</Button>
			</StackPanel>
		```

		## Pattern example

		`Pattern` is a comma-separated list of millisecond durations. It starts
		with an off duration and alternates off/on, matching Android's waveform
		semantics. Use `Repeat` to loop from an index, or leave it at `-1` to
		play once. On iOS, patterns require Core Haptics; other devices fall
		back to a single system vibration.
		```xml
			<Button Text="Pattern">
				<Clicked>
					<Vibrate Pattern="0,100,60,100" Repeat="0" Amplitude="0.7" />
				</Clicked>
			</Button>
		```

		## Options

		* `Amplitude` - strength from `0` to `1`. Defaults to `1`.
		* `Sharpness` - texture from `0` to `1` (iOS only). Defaults to `0.5`.
		* `Usage` - `Default`, `Touch`, `Notification`, `Alarm`, or `Accessibility` (Android only).
		* `Primitive` - a native haptic primitive such as `Click` or `Thud`.
	*/
	public class Vibrate : TriggerAction
	{
		double _duration = 0.4;
		/**
			The duration of the vibration in seconds. Defaults to `0.4`.
			Values that are not positive, finite numbers fall back to `0.4`.
		*/
		public double Duration
		{
			get { return _duration; }
			set { _duration = value; }
		}

		string _pattern;
		/**
			A comma-separated waveform of millisecond durations. The first value
			is an off duration and the rest alternate off/on.
		*/
		public string Pattern
		{
			get { return _pattern; }
			set { _pattern = value; }
		}

		int _repeat = -1;
		/**
			The index in `Pattern` to loop from, or `-1` to play once.
		*/
		public int Repeat
		{
			get { return _repeat; }
			set { _repeat = value; }
		}

		double _amplitude = 1.0;
		/**
			The strength of the vibration from `0` to `1`. Defaults to `1`.
		*/
		public double Amplitude
		{
			get { return _amplitude; }
			set { _amplitude = value; }
		}

		double _sharpness = 0.5;
		/**
			The texture of the vibration from `0` to `1` (iOS only). Defaults to `0.5`.
		*/
		public double Sharpness
		{
			get { return _sharpness; }
			set { _sharpness = value; }
		}

		/**
			How the vibration should be categorized by the platform.
		*/
		public HapticUsage Usage { get; set; }

		HapticPrimitive _primitive = HapticPrimitive.Undefined;
		/**
			A native haptic primitive. When set, it takes precedence over
			`VibrationType` and `Duration`.
		*/
		public HapticPrimitive Primitive
		{
			get { return _primitive; }
			set { _primitive = value; }
		}

		VibrationType _vibrationType = VibrationType.Undefined;
		public VibrationType VibrationType
		{
			get
			{
				return _vibrationType;
			}
			set
			{
				_vibrationType = value;
			}
		}

		protected override void Perform(Node target)
		{
			if (!string.IsNullOrEmpty(_pattern))
			{
				var timings = ParsePattern(_pattern);
				Vibration.Vibrate(new VibrationPattern(timings, null, _repeat, _amplitude, _sharpness, Usage));
			}
			else if (_primitive != HapticPrimitive.Undefined)
			{
				Vibration.Primitive(_primitive, _amplitude);
			}
			else if (_vibrationType != VibrationType.Undefined)
			{
				Vibration.Feedback(_vibrationType, _amplitude);
			}
			else
			{
				var duration = (double.IsNaN(_duration) || double.IsInfinity(_duration) || _duration <= 0)
					? 0.4 : _duration;
				Vibration.Vibrate(duration, _amplitude, _sharpness, Usage);
			}
		}

		static double[] ParsePattern(string value)
		{
			var parts = value.Split(',');
			var result = new double[parts.Length];

			for (int i = 0; i < parts.Length; i++)
			{
				double timing;
				if (!double.TryParse(parts[i].Trim(), out timing) || double.IsNaN(timing) || double.IsInfinity(timing) || timing < 0)
					throw new ArgumentException("Vibrate: Pattern values must be finite, non-negative numbers.");

				result[i] = timing;
			}

			return result;
		}
	}

	/**
		Stops an ongoing vibration started by @Vibrate.

		## Example
		```xml
			<Button Text="Stop">
				<Clicked>
					<StopVibration />
				</Clicked>
			</Button>
		```
	*/
	public class StopVibration : TriggerAction
	{
		protected override void Perform(Node target)
		{
			Vibration.Cancel();
		}
	}
}
