using Uno;
using Uno.UX;
using Uno.Threading;
using Fuse.Scripting;

namespace Fuse.Reactive.FuseJS
{
	/**
		@scriptmodule FuseJS/Email

		Launches the default email app, and starts composing a message.

		You need to add a reference to `"Fuse.Launcher"` (or
		`"Fuse.Launcher.Email"`) in your project file to use this feature.
		```js
			var email = require('FuseJS/Email');
			email.compose({
				to: ["to@example.com"],
				cc: ["cc@example.com"],
				bcc: ["bcc@example.com"],
				subject: "Subject",
				body: "Message"
			}).then(function(result) {
				console.log(result.status);
			});
		```

		The legacy positional form is still supported:
		```js
			email.compose("to@example.com", "cc@example.com", "bcc@example.com", "subject", "message");
		```
	*/
	[UXGlobalModule]
	public sealed class Email : NativeModule
	{
		static readonly Email _instance;

		public Email()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/Email");

			AddMember(new NativeFunction("isAvailable", IsAvailable));
			AddMember(new NativePromise<EmailLaunchStatus, Scripting.Object>(
				"compose", Compose, ConvertResult));
		}

		/**
			@scriptmethod isAvailable()

			Returns `true` when the platform can launch an email application.

			@return (Bool) Whether an email application is available.
		*/
		static object IsAvailable(Scripting.Context context, object[] args)
		{
			return Fuse.LauncherImpl.EmailLauncher.IsAvailable();
		}

		/**
			@scriptmethod compose(options)

			Launches the default email app, and starts composing a message.

			`compose` accepts either an options object or the legacy positional
			arguments `compose(to, cc, bcc, subject, message)`.

			Options:
			- `to` – A recipient address, or an array of recipient addresses.
			- `cc` – A carbon copy address, or an array of addresses.
			- `bcc` – A blind carbon copy address, or an array of addresses.
			- `subject` – The subject of the email.
			- `body` – The plain text body.
			- `htmlBody` – An HTML body. Supported by the iOS in-app composer and by Android clients that handle `EXTRA_HTML_TEXT`.
			- `attachments` – An array of file paths to attach.
			- `chooserTitle` – The title of the Android chooser.
			- `androidPackage` – An Android package to target, for example `"com.google.android.gm"`.
			- `preferInAppComposer` – Use the iOS in-app composer. Automatically enabled when `attachments` or `htmlBody` is set.

			@return (Promise) Resolves to an object with a `status` string:
			`"opened"`, `"sent"`, `"saved"` or `"cancelled"`. Rejects with a
			user-facing message when the message cannot be launched.
		*/
		static Future<EmailLaunchStatus> Compose(Scripting.Context context, object[] args)
		{
			var promise = new Promise<EmailLaunchStatus>();

			try
			{
				var message = EmailMessageParser.FromArgs(args);
				Fuse.LauncherImpl.EmailLauncher.Launch(message).Then(
					status => promise.Resolve(status),
					error => promise.Reject(error));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		static Scripting.Object ConvertResult(Scripting.Context context, EmailLaunchStatus status)
		{
			var result = context.NewObject();
			result["status"] =
				status == EmailLaunchStatus.Opened ? "opened" :
				status == EmailLaunchStatus.Sent ? "sent" :
				status == EmailLaunchStatus.Saved ? "saved" :
				"cancelled";
			return result;
		}
	}

	static class EmailMessageParser
	{
		public static EmailMessage FromArgs(object[] args)
		{
			if (args == null || args.Length == 0)
				throw new Exception("compose requires an options object or a recipient address.");

			var options = args[0] as Scripting.Object;
			if (options != null)
				return FromOptions(options);

			return new EmailMessage
			{
				To = GetStringArrayArg(args, 0),
				CarbonCopy = GetStringArrayArg(args, 1),
				BlindCarbonCopy = GetStringArrayArg(args, 2),
				Subject = GetStringArg(args, 3),
				Body = GetStringArg(args, 4)
			};
		}

		static EmailMessage FromOptions(Scripting.Object options)
		{
			var message = new EmailMessage
			{
				To = GetStringArray(options, "to"),
				CarbonCopy = GetStringArray(options, "cc"),
				BlindCarbonCopy = GetStringArray(options, "bcc"),
				Subject = GetString(options, "subject"),
				Body = GetString(options, "body"),
				HtmlBody = GetString(options, "htmlBody"),
				Attachments = GetStringArray(options, "attachments"),
				ChooserTitle = GetString(options, "chooserTitle"),
				AndroidPackage = GetString(options, "androidPackage")
			};

			// `message` was used by the original positional API and is accepted
			// as a body alias by the options form as well.
			if (string.IsNullOrEmpty(message.Body))
				message.Body = GetString(options, "message");

			if (options.ContainsKey("preferInAppComposer"))
				message.PreferInAppComposer = ToBool(options["preferInAppComposer"]);

			return message;
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

		static string[] GetStringArrayArg(object[] args, int index)
		{
			if (index >= args.Length || args[index] == null)
				return null;

			return ToStringArray(args[index], "Argument " + (index + 1));
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
				return new string[] { single };

			return new string[] { value.ToString() };
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
	}
}
