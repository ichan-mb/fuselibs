using Uno;
using Uno.UX;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Reactive.FuseJS
{
	[UXGlobalModule]
	/**
		@scriptmodule FuseJS/Phone

		The Phone API allows you to launch your device's built-in
		phone app and make calls or send messages.

		You need to add a reference to `"Fuse.Launcher"` or
		`"Fuse.Launcher.Phone"` in your project file to use this feature.

		## Example
		```js
			var phone = require("FuseJS/Phone");
			phone.call("+47 123 45 678");
			phone.sms("+47 123 45 678", "Hi there");
		```
	*/
	public sealed class Phone : NativeModule
	{
		static readonly Phone _instance;

		public Phone()
		{
			if (_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Phone");

			AddMember(new NativeFunction("canCall", CanCall));
			AddMember(new NativeFunction("canSendSms", CanSendSms));
			AddMember(new NativeFunction("canFaceTime", CanFaceTime));
			AddMember(new NativePromise<PhoneLaunchStatus, Scripting.Object>("call", Call, ConvertResult));
			AddMember(new NativePromise<PhoneLaunchStatus, Scripting.Object>("sms", Sms, ConvertResult));
		}

		/**
			@scriptmethod canCall()

			Returns `true` when the platform can launch a phone call.

			@return (Bool) Whether a phone app is available.
		*/
		static object CanCall(Context context, object[] args)
		{
			return Fuse.LauncherImpl.PhoneLauncher.CanCall();
		}

		/**
			@scriptmethod canSendSms()

			Returns `true` when the platform can compose an SMS message.

			@return (Bool) Whether a messaging app is available.
		*/
		static object CanSendSms(Context context, object[] args)
		{
			return Fuse.LauncherImpl.PhoneLauncher.CanSendSms();
		}

		/**
			@scriptmethod canFaceTime()

			Returns `true` when the platform can launch a FaceTime call.

			@return (Bool) Whether FaceTime is available.
		*/
		static object CanFaceTime(Context context, object[] args)
		{
			return Fuse.LauncherImpl.PhoneLauncher.CanFaceTime();
		}

		/**
			@scriptmethod call(number, options)

			Launches the phone app with the specified number.

			`options.mode` can be `"dial"` (default) to open the dialer or
			`"call"` to place the call directly. `"call"` requires the
			`CALL_PHONE` permission on Android and falls back to the dialer
			when it is denied.

			Options:
			- `mode` – `"dial"` (default) or `"call"`.
			- `androidPackage` – An Android package to target, for example `"com.android.dialer"`.
			- `faceTime` – Launch a FaceTime call instead of a phone call (iOS only).
			- `faceTimeAudioOnly` – Launch a FaceTime audio call. Implies `faceTime`.

			@param number (String) The number to call
			@param options (Object) Optional launch options

			@return (Promise) Resolves to an object with a `status` string.

			## Example
			```js
				var phone = require("FuseJS/Phone");
				phone.call("+47 123 45 678").then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<PhoneLaunchStatus> Call(Context context, object[] args)
		{
			var promise = new Promise<PhoneLaunchStatus>();

			try
			{
				var options = PhoneArgs.ParseCall(args);
				Fuse.LauncherImpl.PhoneLauncher.LaunchCall(options).Then(
					status => promise.Resolve(status),
					error => promise.Reject(error));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			@scriptmethod sms(options)

			Launches the messaging app with the specified recipients and body.

			`sms` accepts either an options object (`{ to, body }`) or the legacy
			positional arguments `sms(number, body)`. `to` may be a single number
			or an array of numbers.

			Options:
			- `to` – A recipient number, or an array of recipient numbers.
			- `body` – The message body.
			- `subject` – The message subject. Requires the iOS in-app composer.
			- `attachments` – An array of file paths. Requires the iOS in-app composer and iOS 14+.
			- `preferInAppComposer` – Use the iOS in-app composer. Automatically enabled when `subject` or `attachments` is set.
			- `androidPackage` – An Android package to target, for example `"com.google.android.apps.messaging"`.
			- `chooserTitle` – The title of the Android chooser shown when no `androidPackage` is set.

			@param options (Object) The options object, or the recipient number
			@param body (String) The message body (legacy form)

			@return (Promise) Resolves to an object with a `status` string:
			`"opened"`, `"sent"` or `"cancelled"`. Rejects with a user-facing
			message when the message cannot be launched.

			## Example
			```js
				var phone = require("FuseJS/Phone");
				phone.sms({
					to: ["+47 123 45 678"],
					body: "Hi there"
				}).then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<PhoneLaunchStatus> Sms(Context context, object[] args)
		{
			var promise = new Promise<PhoneLaunchStatus>();

			try
			{
				var message = PhoneArgs.ParseSms(args);
				Fuse.LauncherImpl.PhoneLauncher.LaunchSms(message).Then(
					status => promise.Resolve(status),
					error => promise.Reject(error));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		static Scripting.Object ConvertResult(Context context, PhoneLaunchStatus status)
		{
			var result = context.NewObject();
			result["status"] =
				status == PhoneLaunchStatus.Opened ? "opened" :
				status == PhoneLaunchStatus.Sent ? "sent" :
				"cancelled";
			return result;
		}
	}

	static class PhoneArgs
	{
		public static PhoneCallOptions ParseCall(object[] args)
		{
			if (args == null || args.Length == 0 || args[0] == null)
				throw new Exception("call requires a phone number.");

			var options = new PhoneCallOptions
			{
				Number = RequireString(args[0], "number"),
				Mode = PhoneCallMode.Dial
			};

			var config = args.Length > 1 ? args[1] as Scripting.Object : null;
			if (args.Length > 1 && args[1] != null && config == null)
				throw new Exception("options must be an object.");

			if (config != null && config.ContainsKey("mode"))
			{
				var mode = RequireString(config["mode"], "mode").ToLower();
				if (mode == "call")
					options.Mode = PhoneCallMode.Call;
				else if (mode != "dial")
					throw new Exception("'mode' must be 'dial' or 'call'.");
			}

			if (config != null)
			{
				if (config.ContainsKey("androidPackage"))
					options.AndroidPackage = GetString(config, "androidPackage");

				if (config.ContainsKey("faceTime"))
					options.FaceTime = ToBool(config["faceTime"]);

				if (config.ContainsKey("faceTimeAudioOnly"))
					options.FaceTimeAudioOnly = ToBool(config["faceTimeAudioOnly"]);
			}

			return options;
		}

		public static SmsMessage ParseSms(object[] args)
		{
			if (args == null || args.Length == 0)
				throw new Exception("sms requires a recipient or an options object.");

			var config = args[0] as Scripting.Object;
			if (config != null)
			{
				var message = new SmsMessage
				{
					Recipients = GetStringArray(config, "to"),
					Body = GetString(config, "body"),
					Subject = GetString(config, "subject"),
					Attachments = GetStringArray(config, "attachments"),
					AndroidPackage = GetString(config, "androidPackage"),
					ChooserTitle = GetString(config, "chooserTitle")
				};

				// `number` is accepted as an alias for `to` by the options form.
				if (message.Recipients == null || message.Recipients.Length == 0)
					message.Recipients = GetStringArray(config, "number");

				if (message.Recipients == null || message.Recipients.Length == 0)
					throw new Exception("sms requires a recipient.");

				if (config.ContainsKey("preferInAppComposer"))
					message.PreferInAppComposer = ToBool(config["preferInAppComposer"]);

				return message;
			}

			return new SmsMessage
			{
				Recipients = new[] { RequireString(args[0], "number") },
				Body = args.Length > 1 ? GetStringArg(args, 1) : null
			};
		}

		static string RequireString(object value, string name)
		{
			var str = value as string;
			if (str == null)
				throw new Exception("'" + name + "' must be a string.");
			if (string.IsNullOrEmpty(str))
				throw new Exception("'" + name + "' must not be empty.");
			return str;
		}

		static string GetStringArg(object[] args, int index)
		{
			if (index >= args.Length || args[index] == null)
				return null;

			var value = args[index] as string;
			return value != null ? value : args[index].ToString();
		}

		static bool ToBool(object value)
		{
			if (value is bool)
				return (bool)value;

			return value != null && value.ToString() == "true";
		}

		static string GetString(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			var value = options[key];
			if (value == null)
				return null;

			var str = value as string;
			return str != null ? str : value.ToString();
		}

		static string[] GetStringArray(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			return ToStringArray(options[key], key);
		}

		static string[] ToStringArray(object value, string name)
		{
			if (value == null)
				return null;

			var array = value as Scripting.Array;
			if (array != null)
			{
				var result = new string[array.Length];
				for (int i = 0; i < array.Length; i++)
				{
					var item = array[i] as string;
					if (item == null)
						throw new Exception("'" + name + "' must contain only strings.");
					result[i] = item;
				}
				return result;
			}

			var single = value as string;
			if (single != null)
				return new[] { single };

			return new[] { value.ToString() };
		}
	}
}
