using Uno;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Vibration
{
	/**
		@scriptmodule FuseJS/Vibration

		Allows you to use the device's vibration functionality.

		You need to add a reference to `"Fuse.Vibration"` in your project file to use this feature.

		## Example

		The following code vibrates the device for 0.8 seconds.
		```js
			var vibration = require('FuseJS/Vibration');
			vibration.vibrate(0.8);
			// works on iOS using TapticEngine and on Android using haptic feedback
			vibration.vibrate('medium');
		```

		## Exported members

		* `vibrate([seconds | type | pattern | options])` - starts a vibration. Returns `true` when a vibration was started, otherwise `false`.
		* `primitive(name, [scale])` - plays a native haptic primitive such as `click` or `thud`.
		* `cancel()` - stops any ongoing vibration.
		* `prepare()` - pre-warms the haptic engine to reduce latency on the next vibration.
		* `isSupported()` - returns whether the device can vibrate.
		* `hasAmplitudeControl()` - returns whether the device can vary vibration strength.

		## Options

		* `amplitude` (or `intensity`) - strength from `0` to `1`. Defaults to `1`.
		* `sharpness` - texture from `0` to `1` (iOS only). Defaults to `0.5`.
		* `usage` - `default`, `touch`, `notification`, `alarm`, or `accessibility` (Android only).
		* `repeat` - index in the pattern to loop from, or `-1` to play once.
		* `amplitudes` - per-segment strengths from `0` to `1` for a pattern.

		## Pattern example

		Pattern timings alternate off/on durations in milliseconds and start with
		an off duration, matching Android's waveform semantics. On iOS, patterns
		require Core Haptics; other devices fall back to a single system vibration.
		```js
			// Wait 100 ms, vibrate 50 ms, wait 100 ms, vibrate 50 ms, then loop.
			vibration.vibrate([100, 50, 100, 50], { repeat: 0, amplitude: 0.7 });
		```

		## Options example

		```js
			vibration.vibrate({ duration: 0.5, amplitude: 0.6, sharpness: 0.3, usage: 'touch' });
			vibration.vibrate({ type: 'success', intensity: 0.8 });
		```
	*/
	[UXGlobalModule]
	public sealed class VibrationModule : NativeModule
	{
		static readonly VibrationModule _instance;

		public VibrationModule()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Vibration");
			AddMember(new NativeFunction("vibrate", Vibrate));
			AddMember(new NativeFunction("primitive", Primitive));
			AddMember(new NativeFunction("cancel", Cancel));
			AddMember(new NativeFunction("prepare", Prepare));
			AddMember(new NativeFunction("isSupported", IsSupported));
			AddMember(new NativeFunction("hasAmplitudeControl", HasAmplitudeControl));
			AddMember(new NativeProperty<string, string>("build", "2026-10-21-duration-fix-7"));
			AddMember(new NativeProperty<string, string>("helperBuild", Fuse.Vibration.Vibration.HelperBuild()));
		}

		/**
			@scriptmethod vibrate(seconds)
			@param seconds (double) seconds the vibration should last. 1 = 1 second, 0.5 = 0.5 seconds or
			vibrationType (string) the type of vibration. Available vibrationType are (case-insensitive) : `soft`, `rigid`, `light`, `medium`, `heavy`, `success`, `warning`, `error`, `selection`
			or pattern (array) an array of millisecond durations, starting with an off duration
			or options (object) an object with `duration`, `pattern`, or `type` and optional `amplitude`, `sharpness`, `usage`, `repeat`, and `amplitudes`
			@return (bool) `true` when a vibration was started, otherwise `false`.
		*/
		static object Vibrate(Scripting.Context context, object[] args)
		{
			if (args.Length == 0)
				return Fuse.Vibration.Vibration.Vibrate(0.4);

			var arg = args[0];

			var typeString = arg as string;
			if (typeString != null)
			{
				var type = ParseType(typeString);
				var intensity = args.Length > 1 ? GetIntensityArgument(args[1]) : 1.0;
				return Fuse.Vibration.Vibration.Feedback(type, intensity);
			}

			var array = arg as Scripting.Array;
			if (array != null)
			{
				var timings = ToDoubleArray(array, "pattern");
				var repeat = -1;
				Scripting.Object options = null;

				if (args.Length > 1)
				{
					options = args[1] as Scripting.Object;
					if (options == null)
					{
						double value;
						if (!Marshal.TryToDouble(args[1], out value))
							throw new Fuse.Scripting.Error("vibrate(): the second argument must be a repeat index or an options object.");

						repeat = (int)value;
						if (args.Length > 2)
							options = args[2] as Scripting.Object;
					}
				}

				return VibratePattern(timings, repeat, options);
			}

			var optionsObject = arg as Scripting.Object;
			if (optionsObject != null)
				return VibrateOptions(optionsObject);

			double seconds;
			if (!Marshal.TryToDouble(arg, out seconds))
				throw new Fuse.Scripting.Error("vibrate(): expected a number of seconds, a vibration type string, a pattern array, or an options object.");

			if (!IsValidDuration(seconds))
				return false;

			if (args.Length <= 1)
				return Fuse.Vibration.Vibration.Vibrate(seconds);

			var argumentOptions = args[1] as Scripting.Object;
			if (argumentOptions != null)
				return Fuse.Vibration.Vibration.Vibrate(
					seconds,
					GetAmplitude(argumentOptions, 1.0),
					GetDouble(argumentOptions, "sharpness", 0.5),
					GetUsage(argumentOptions));

			double amplitude;
			if (!Marshal.TryToDouble(args[1], out amplitude))
				throw new Fuse.Scripting.Error("vibrate(): the second argument must be an amplitude or an options object.");

			return Fuse.Vibration.Vibration.Vibrate(seconds, amplitude, 0.5, HapticUsage.Default);
		}

		static object VibratePattern(double[] timings, int repeat, Scripting.Object options)
		{
			var amplitudes = GetDoubleArray(options, "amplitudes");
			var intensity = GetAmplitude(options, 1.0);
			var sharpness = GetDouble(options, "sharpness", 0.5);
			var usage = GetUsage(options);

			if (options != null && options.ContainsKey("repeat"))
				repeat = (int)GetDouble(options, "repeat", repeat);

			if (repeat < -1 || repeat >= timings.Length)
				throw new Fuse.Scripting.Error("vibrate(): repeat must be -1 or an index within the pattern.");

			if (amplitudes != null && amplitudes.Length != timings.Length)
				throw new Fuse.Scripting.Error("vibrate(): 'amplitudes' must have the same length as the pattern.");

			try
			{
				return Fuse.Vibration.Vibration.Vibrate(new VibrationPattern(timings, amplitudes, repeat, intensity, sharpness, usage));
			}
			catch (ArgumentException e)
			{
				throw new Fuse.Scripting.Error("vibrate(): " + e.Message);
			}
		}

		static object VibrateOptions(Scripting.Object options)
		{
			if (options.ContainsKey("pattern"))
			{
				var timings = GetDoubleArray(options, "pattern");
				var repeat = (int)GetDouble(options, "repeat", -1);
				return VibratePattern(timings, repeat, options);
			}

			if (options.ContainsKey("type"))
			{
				var typeString = options["type"] as string;
				if (typeString == null)
					throw new Fuse.Scripting.Error("vibrate(): option 'type' must be a string.");

				return Fuse.Vibration.Vibration.Feedback(ParseType(typeString), GetAmplitude(options, 1.0));
			}

			if (options.ContainsKey("duration"))
			{
				var seconds = GetDouble(options, "duration", 0);
				if (!IsValidDuration(seconds))
					return false;

				return Fuse.Vibration.Vibration.Vibrate(
					seconds,
					GetAmplitude(options, 1.0),
					GetDouble(options, "sharpness", 0.5),
					GetUsage(options));
			}

			throw new Fuse.Scripting.Error("vibrate(): options must contain 'duration', 'pattern', or 'type'.");
		}

		static double GetIntensityArgument(object value)
		{
			var options = value as Scripting.Object;
			if (options != null)
				return GetAmplitude(options, 1.0);

			double result;
			if (!Marshal.TryToDouble(value, out result))
				throw new Fuse.Scripting.Error("vibrate(): intensity must be a number or an options object.");

			return result;
		}

		static double GetDouble(Scripting.Object options, string key, double fallback)
		{
			if (options == null || !options.ContainsKey(key))
				return fallback;

			double result;
			if (!Marshal.TryToDouble(options[key], out result) || double.IsNaN(result) || double.IsInfinity(result))
				throw new Fuse.Scripting.Error("vibrate(): option '" + key + "' must be a finite number.");

			return result;
		}

		static double GetAmplitude(Scripting.Object options, double fallback)
		{
			if (options == null)
				return fallback;

			if (options.ContainsKey("amplitude"))
				return GetDouble(options, "amplitude", fallback);

			if (options.ContainsKey("intensity"))
				return GetDouble(options, "intensity", fallback);

			return fallback;
		}

		static double[] GetDoubleArray(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			var array = options[key] as Scripting.Array;
			if (array == null)
				throw new Fuse.Scripting.Error("vibrate(): option '" + key + "' must be an array.");

			return ToDoubleArray(array, key);
		}

		static double[] ToDoubleArray(Scripting.Array array, string name)
		{
			var result = new double[array.Length];
			for (int i = 0; i < array.Length; i++)
			{
				double value;
				if (!Marshal.TryToDouble(array[i], out value) || double.IsNaN(value) || double.IsInfinity(value) || value < 0)
					throw new Fuse.Scripting.Error("vibrate(): " + name + " values must be finite, non-negative numbers.");

				result[i] = value;
			}

			return result;
		}

		static HapticUsage GetUsage(Scripting.Object options)
		{
			if (options == null || !options.ContainsKey("usage"))
				return HapticUsage.Default;

			var usage = options["usage"] as string;
			if (usage == null)
				throw new Fuse.Scripting.Error("vibrate(): option 'usage' must be a string.");

			HapticUsage result;
			if (!Uno.Enum.TryParse<HapticUsage>(usage, true, out result))
				throw new Fuse.Scripting.Error("vibrate(): unknown usage '" + usage + "'. Valid usages are: default, touch, notification, alarm, accessibility.");

			return result;
		}

		static VibrationType ParseType(string value)
		{
			VibrationType result;
			if (!Uno.Enum.TryParse<VibrationType>(value, true, out result) || result == VibrationType.Undefined)
				throw new Fuse.Scripting.Error("vibrate(): unknown vibration type '" + value
					+ "'. Valid types are: soft, rigid, light, medium, heavy, success, warning, error, selection.");

			return result;
		}

		static bool IsValidDuration(double seconds)
		{
			return !double.IsNaN(seconds) && !double.IsInfinity(seconds) && seconds > 0;
		}

		/**
			@scriptmethod primitive(name, scale)
			@param name (string) the primitive name (case-insensitive) : `click`, `thud`, `tick`, `lowTick`, `spin`, `quickRise`, `quickFall`, `slowRise`
			@param scale (double) strength from `0` to `1`. Defaults to `1`.
			@return (bool) `true` when a vibration was started, otherwise `false`.
		*/
		static object Primitive(Scripting.Context context, object[] args)
		{
			if (args.Length == 0)
				throw new Fuse.Scripting.Error("primitive(): expected a primitive name.");

			var name = args[0] as string;
			if (name == null)
				throw new Fuse.Scripting.Error("primitive(): the primitive name must be a string.");

			HapticPrimitive primitive;
			if (!Uno.Enum.TryParse<HapticPrimitive>(name, true, out primitive) || primitive == HapticPrimitive.Undefined)
				throw new Fuse.Scripting.Error("primitive(): unknown primitive '" + name
					+ "'. Valid primitives are: click, thud, tick, lowTick, spin, quickRise, quickFall, slowRise.");

			double scale = 1.0;
			if (args.Length > 1 && !Marshal.TryToDouble(args[1], out scale))
				throw new Fuse.Scripting.Error("primitive(): scale must be a number.");

			return Fuse.Vibration.Vibration.Primitive(primitive, scale);
		}

		/**
			@scriptmethod cancel()
			Stops any ongoing vibration.
		*/
		static object Cancel(Scripting.Context context, object[] args)
		{
			Fuse.Vibration.Vibration.Cancel();
			return null;
		}

		/**
			@scriptmethod prepare()
			Pre-warms the haptic engine to reduce latency on the next vibration.
			@return (bool) whether the device can vibrate.
		*/
		static object Prepare(Scripting.Context context, object[] args)
		{
			return Fuse.Vibration.Vibration.Prepare();
		}

		/**
			@scriptmethod isSupported()
			@return (bool) whether the device can vibrate.
		*/
		static object IsSupported(Scripting.Context context, object[] args)
		{
			return Fuse.Vibration.Vibration.IsSupported();
		}

		/**
			@scriptmethod hasAmplitudeControl()
			@return (bool) whether the device can vary vibration strength.
		*/
		static object HasAmplitudeControl(Scripting.Context context, object[] args)
		{
			return Fuse.Vibration.Vibration.HasAmplitudeControl();
		}
	}
}
