using Uno;
using Uno.Collections;
using Uno.Platform.EventSources;
using Uno.Threading;
using Uno.UX;
using Fuse.Scripting;

namespace Fuse.Reactive.FuseJS
{
	/**
		@scriptmodule FuseJS/InterApp

		The InterApp API allows you to launch other apps, as well as respond to being launched via URI schemes.
		It can also open the application's system settings page and store page.

		This module is an @EventEmitter, so the methods from @EventEmitter can be used to listen to events.

		You need to add a reference to `"Fuse.Launcher"` in your project file to use this feature.

		## Example
		```javascript
			var InterApp = require("FuseJS/InterApp");

			InterApp.on("receivedUri", function(uri) {
				console.log("Launched with URI", uri);
			});

			InterApp.on("receivedUriData", function(data) {
				console.log(data.uri, data.query, data.sourceApplication, data.universalLink);
			});

			if (InterApp.canOpenUri("https://fuseopen.com/")) {
				InterApp.launchUri("https://fuseopen.com/").then(function(result) {
					console.log(result.status);
				});
			}
		```

		In the above example we're using the @EventEmitter `on` method to listen to the `"receivedUri"` event.

		For the [receivedUri](api:fuse/reactive/fusejs/interapp/onreceiveduri_968f99a6.json) event to be triggered, you need register a custom URI scheme for your app, as shown [here](articles:basics/uno-projects#mobile-urischeme).


		## Deep Links - Universal and App Links

		You can receive the `receivedUri` event, mentioned above, for associated web urls that have been tapped on in other apps.

		Apple: [https://developer.apple.com/ios/universal-links](https://developer.apple.com/ios/universal-links)

		Android: [https://developer.android.com/training/app-links](https://developer.android.com/training/app-links)

		## Apple Universal Links

		1. Add the associated domains in your `.unoproj`
		2. Add the Apple App Site Association file to your website

		### 1. Add associated domains to your .unoproj

		```JSON
		{
			"iOS": {
				"SystemCapabilities": {
					"AssociatedDomains": ["applinks:example.com", "applinks:sub.example.com"]
				}
			}
		}
		```

		### 2. Add the Apple App Site Association file to your website

		Apple-app-site-association file format
		```JSON
		{
			"applinks": {
				"apps": [],
				"details": [
					{
						"appID": "<team identifier>.<bundle identifier>",
						"paths": [<paths>]
					}
				]
			}
		}
		```

		Basic example, this allows all urls of the domain to be validated:
		```JSON
		{
			"applinks": {
				"apps": [],
				"details": [
					{
						"appID": "1234567890.com.mypackage.myapp",
						"paths": ["*"]
					}
				]
			}
		}
		```


		Place this file either in your site’s `.well-known` directory, or directly in its root directory. If you use the `.well-known` directory, the file’s URL should match the following format:
		```
		https://<fully qualified domain>/.well-known/apple-app-site-association
		```
		Tip: make sure you can access the file and view the JSON of the apple-app-site-association file from a browser.

		Full reference: [https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/enabling_universal_links?language=objc](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/enabling_universal_links?language=objc)

		## Android App Links

		1. Add the associated domains in your `.unoproj`
		2. Add the asset links file to your website

		### 1. Add associated domains to your .unoproj

		```JSON
		{
			"Android": {
				"AssociatedDomains": ["example.com", "sub.example.com"]
			}
		}
		```

		### 2. Add the asset links file to your website

		Example:
		```json
		[{
		  "relation": ["delegate_permission/common.handle_all_urls"],
		    "target": {
		      "namespace": "android_app",
		      "package_name": "com.example.puppies.app",
		      "sha256_cert_fingerprints":
		      ["14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"]
		    }
		  },
		  {
		    "relation": ["delegate_permission/common.handle_all_urls"],
		    "target": {
		      "namespace": "android_app",
		      "package_name": "com.example.monkeys.app",
		      "sha256_cert_fingerprints":
		      ["14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"]
		    }
		}]
		```

		Each group represents an app, you will likely need one for your development version and one for your release version of your app.

		To get the `sha256_cert_fingerprints`, use the following:
		```
		keytool -list -v -keystore my-release-key.keystore
		```

		To get the sha256 for the development version of exporting with fuse, use with `android` as the password:
		`keytool -list -v -keystore ~/.android/debug.keystore`

		Place this file in your site’s `.well-known` directory. The file’s URL should match the following format:
		```
		https://domain.name/.well-known/assetlinks.json
		```
	*/
	[UXGlobalModule]
	public sealed class InterApp : NativeEventEmitterModule
	{
		static readonly InterApp _instance;

		delegate Future<InterAppLaunchStatus> LaunchOperation();

		public InterApp()
			: base(true,
				"receivedUri",
				"receivedUriData")
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/InterApp");
			var onReceivedUri = new NativeEvent("onReceivedUri");
			var onReceivedUriData = new NativeEvent("onReceivedUriData");

			On("receivedUri", onReceivedUri);
			On("receivedUriData", onReceivedUriData);

			AddMember(onReceivedUri);
			AddMember(onReceivedUriData);
			AddMember(new NativeFunction("canOpenUri", CanOpenUri));
			AddMember(new NativeFunction("canLaunchApp", CanLaunchApp));
			AddMember(new NativePromise<InterAppLaunchStatus, Scripting.Object>(
				"launchUri", LaunchUri, ConvertResult));
			AddMember(new NativePromise<InterAppLaunchStatus, Scripting.Object>(
				"launchApp", LaunchApp, ConvertResult));
			AddMember(new NativePromise<InterAppLaunchStatus, Scripting.Object>(
				"launchPackage", LaunchPackage, ConvertResult));
			AddMember(new NativePromise<InterAppLaunchStatus, Scripting.Object>(
				"openSettings", OpenSettings, ConvertResult));
			AddMember(new NativePromise<InterAppLaunchStatus, Scripting.Object>(
				"openStore", OpenStore, ConvertResult));

			Fuse.Platform.InterApp.ReceivedURI += OnReceivedUri;
			Fuse.Platform.InterApp.ReceivedURIData += OnReceivedUriData;
		}

		/**
			@scriptevent receivedUri
			@param uri (String) The URI to launch
			Called when the app is launched via its own URI scheme.

			For this to be called, you need register a custom URI scheme for your app, as shown [here](/docs/basics/uno-projects#mobile-urischeme).

			See [the InterApp module](api:fuse/reactive/fusejs/interapp.json) for an example.
		*/
		void OnReceivedUri(string uri)
		{
			Emit("receivedUri", uri);
		}

		/**
			@scriptevent receivedUriData
			@param data (Object) An object with the URI and its metadata.

			Called when the app is launched via its own URI scheme, a universal
			link or an Android App Link.

			The object has the following properties:
			- `uri` – The URI that launched the app.
			- `query` – The query string of the URI, including the leading `?`, or `null`.
			- `sourceApplication` – The application that opened the URI, or `null` when unavailable.
			- `universalLink` – `true` when the URI arrived as a universal link or Android App Link.
			- `openInPlace` – `true` when iOS opened the URI in place.
			- `coldStart` – `true` when the URI arrived while the app was starting.

			`receivedUri` remains available for code that only needs the URI.
		*/
		void OnReceivedUriData(InterAppInvokeArgs args)
		{
			EmitFactory((Context context, InterAppInvokeArgs data) =>
			{
				var result = context.NewObject();
				result["uri"] = data.Uri;
				result["query"] = data.Query;
				result["sourceApplication"] = data.SourceApplication;
				result["universalLink"] = data.IsUniversalLink;
				result["openInPlace"] = data.IsOpenInPlace;
				result["coldStart"] = data.IsColdStart;
				return new object[] { "receivedUriData", result };
			}, args);
		}

		/**
			@scriptmethod canOpenUri(uri)
			@param uri (String) The URI to check.

			Returns `true` when the platform has an application that can open
			the URI.

			On Android this is subject to Android 11 package visibility. Custom
			schemes must be declared with `Android.Queries.Schemes`.

			On iOS schemes must be declared in `LSApplicationQueriesSchemes`.

			@return (Bool) Whether an app can handle the URI.
		*/
		static object CanOpenUri(Scripting.Context context, object[] args)
		{
			return Fuse.LauncherImpl.InterAppLauncher.CanOpenUri(GetString(args, 0));
		}

		/**
			@scriptmethod canLaunchApp(applicationId)
			@param applicationId (String) An Android package name or an iOS URI scheme.

			Returns `true` when the platform can launch the application.

			On Android pass a package name, for example `"com.example.app"`.
			Package visibility rules apply; declare the package with
			`Android.Queries.Packages`. On iOS pass a URI scheme, for example
			`"myapp://"`, and declare the scheme in `LSApplicationQueriesSchemes`.

			@return (Bool) Whether the app can be launched.
		*/
		static object CanLaunchApp(Scripting.Context context, object[] args)
		{
			return Fuse.LauncherImpl.InterAppLauncher.CanLaunchApp(GetString(args, 0));
		}

		/**
			@scriptmethod launchUri(uri, options)
			@param uri (String) The URI to launch.
			@param options (Object) Optional launch options.

			Requests the system to launch an app that handles the specified URI.

			Options:
			- `androidPackage` – An Android package to target.
			- `androidClassName` – An explicit Android activity class. Requires `androidPackage`.
			- `androidFlags` – An array of Android intent flag names, such as `"newTask"` or `"clearTop"`.
			- `mimeType` – A MIME type for the intent data, for example `"text/plain"`.
			- `androidExtras` – An object of string extras added to the Android intent.
			- `universalLinksOnly` – iOS: only open universal links.

			Note: you can pass any URI string to `launchUri`, but how it is handled will depend on the target platform and particular device settings.

			There are several common URI schemes that you can use on both Android and iOS:
				http://<website address>
				https://<website address>
				tel:<phone number>
				sms:<phone number>

			Other platform-specific URI schemes are known to be working fine, for example `geo:<parameters>` launches Maps application on Android
			and `facetime:<parameters>` launches a Facetime video call on iOS.
			More information on supported URI schemes: [on Android](https://developer.android.com/guide/components/intents-common.html) and [on iOS](https://developer.apple.com/library/content/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html).

			@return (Promise) Resolves to an object with `status` (`"opened"`).
			Rejects with a user-facing message when the URI cannot be opened.

			## Example
			```javascript
				InterApp.launchUri("https://fuseopen.com/", {
					androidFlags: ["newTask"]
				}).then(function(result) {
					console.log(result.status);
				}).catch(function(error) {
					console.log("Could not open URI: " + error);
				});
			```
		*/
		static Future<InterAppLaunchStatus> LaunchUri(Scripting.Context context, object[] args)
		{
			return Run(() =>
			{
				var uri = RequireString(args, 0, "uri");
				return Fuse.LauncherImpl.InterAppLauncher.LaunchUri(ParseLaunchUriOptions(uri, args));
			});
		}

		/**
			@scriptmethod launchApp(uri, options)
			@param uri (String) The URI to launch, or an Android application id.
			@param options (Object|String) Optional launch options, or the legacy app store URI.

			Requests the system to launch an app.

			On Android `uri` may be either a URI (for example `"myapp://"`) or a
			package name (for example `"com.example.app"`). On iOS it must be a
			URI that the app registers a scheme for.

			Options:
			- `appStoreUri` – A store URI to open when the app cannot be launched.
			- `androidPackage` – An Android package to target when opening a URI.
			- `androidClassName` – An explicit Android activity class. Requires `androidPackage`.
			- `androidFlags` – An array of Android intent flag names, such as `"newTask"` or `"clearTop"`.
			- `mimeType` – A MIME type for the intent data, for example `"text/plain"`.
			- `androidExtras` – An object of string extras added to the Android intent.
			- `universalLinksOnly` – iOS: only open universal links.

			On Android, the positional `launchApp(uri, appStoreUri)` form falls
			back to the Play Store when `uri` is a package id.

			@return (Promise) Resolves to an object with `status` (`"opened"`).
			Rejects with a user-facing message when the app cannot be launched.

			## Example
			```javascript
				InterApp.launchApp("com.example.app", {
					appStoreUri: "https://play.google.com/store/apps/details?id=com.example.app"
				}).then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<InterAppLaunchStatus> LaunchApp(Scripting.Context context, object[] args)
		{
			return Run(() => Fuse.LauncherImpl.InterAppLauncher.LaunchApp(ParseLaunchAppOptions(args)));
		}

		/**
			@scriptmethod launchPackage(applicationId, options)
			@param applicationId (String) The Android package id to launch.
			@param options (Object) Optional launch options.

			Launches an Android app by package id. Unlike `launchApp`, the argument
			is never treated as a URI. This rejects on iOS, which has no API for
			launching an app by bundle identifier.

			Options:
			- `appStoreUri` – A store URI to open when the app cannot be launched.
			- `androidFlags` – An array of Android intent flag names.
			- `androidExtras` – An object of string extras added to the Android intent.

			@return (Promise) Resolves to an object with `status` (`"opened"`).
			Rejects with a user-facing message when the app cannot be launched.

			## Example
			```javascript
				InterApp.launchPackage("com.example.app", {
					appStoreUri: "https://play.google.com/store/apps/details?id=com.example.app"
				}).then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<InterAppLaunchStatus> LaunchPackage(Scripting.Context context, object[] args)
		{
			return Run(() =>
			{
				var applicationId = RequireString(args, 0, "applicationId");
				var config = args != null && args.Length > 1 ? args[1] as Scripting.Object : null;
				if (args != null && args.Length > 1 && args[1] != null && config == null)
					throw new Exception("The second argument must be an options object.");

				return Fuse.LauncherImpl.InterAppLauncher.LaunchPackage(
					applicationId, ParseLaunchOptions(config));
			});
		}

		/**
			@scriptmethod openSettings()

			Opens the operating system's settings page for this application.

			This is useful after a permission has been denied, because the user can
			grant it from the app settings page.

			@return (Promise) Resolves to an object with `status` (`"opened"`).
			Rejects with a user-facing message when the page cannot be opened.
		*/
		static Future<InterAppLaunchStatus> OpenSettings(Scripting.Context context, object[] args)
		{
			return Run(() => Fuse.LauncherImpl.InterAppLauncher.OpenSettings());
		}

		/**
			@scriptmethod openStore(options)

			Opens the store page for an application.

			Options:
			- `androidPackage` – The Android package whose Play Store page should be opened.
			- `appStoreId` – The iOS App Store id, with or without the `id` prefix.
			- `storeUri` – An explicit store URI that overrides the platform defaults.

			When the native store cannot be opened, the call falls back to the
			corresponding web store page.

			@return (Promise) Resolves to an object with `status` (`"opened"`).
			Rejects with a user-facing message when the store page cannot be opened.

			## Example
			```javascript
				InterApp.openStore({
					androidPackage: "com.example.app",
					appStoreId: "123456789"
				}).then(function(result) {
					console.log(result.status);
				});
			```
		*/
		static Future<InterAppLaunchStatus> OpenStore(Scripting.Context context, object[] args)
		{
			return Run(() => Fuse.LauncherImpl.InterAppLauncher.OpenStore(ParseStoreOptions(args)));
		}

		static Future<InterAppLaunchStatus> Run(LaunchOperation operation)
		{
			var promise = new Promise<InterAppLaunchStatus>();

			try
			{
				operation().Then(
					status => promise.Resolve(status),
					error => promise.Reject(error));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		static InterAppStoreOptions ParseStoreOptions(object[] args)
		{
			var config = args != null && args.Length > 0 ? args[0] as Scripting.Object : null;
			if (config == null)
				throw new Exception("openStore requires an options object.");

			return new InterAppStoreOptions
			{
				AndroidPackage = GetString(config, "androidPackage"),
				AppStoreId = GetString(config, "appStoreId"),
				StoreUri = GetString(config, "storeUri")
			};
		}

		static InterAppLaunchOptions ParseLaunchUriOptions(string uri, object[] args)
		{
			var config = args != null && args.Length > 1 ? args[1] as Scripting.Object : null;
			if (args != null && args.Length > 1 && args[1] != null && config == null)
				throw new Exception("The second argument must be an options object.");

			var options = ParseLaunchOptions(config);
			options.Uri = uri;
			return options;
		}

		static InterAppLaunchOptions ParseLaunchAppOptions(object[] args)
		{
			var uri = RequireString(args, 0, "uri");

			if (args == null || args.Length < 2 || args[1] == null)
			{
				var defaults = new InterAppLaunchOptions { Uri = uri };
				ApplyLegacyAndroidStoreFallback(defaults);
				return defaults;
			}

			var config = args[1] as Scripting.Object;
			if (config != null)
			{
				var options = ParseLaunchOptions(config);
				options.Uri = uri;
				return options;
			}

			// Backwards compatibility: launchApp(uri, appStoreUri)
			var appStoreUri = args[1] as string;
			if (appStoreUri == null)
				throw new Exception("The second argument must be an options object or a store URI string.");

			var legacy = new InterAppLaunchOptions { Uri = uri, AppStoreUri = appStoreUri };
			ApplyLegacyAndroidStoreFallback(legacy);
			return legacy;
		}

		static InterAppLaunchOptions ParseLaunchOptions(Scripting.Object config)
		{
			var options = new InterAppLaunchOptions();
			if (config == null)
				return options;

			options.AndroidPackage = GetString(config, "androidPackage");
			options.AndroidClassName = GetString(config, "androidClassName");
			options.AppStoreUri = GetString(config, "appStoreUri");
			options.MimeType = GetString(config, "mimeType");
			options.UniversalLinksOnly = GetBool(config, "universalLinksOnly");
			options.AndroidFlags = GetStringArray(config, "androidFlags");
			options.AndroidExtras = GetStringDictionary(config, "androidExtras");
			return options;
		}

		static void ApplyLegacyAndroidStoreFallback(InterAppLaunchOptions options)
		{
			// Preserve the legacy behavior for the positional call forms:
			// an Android package id falls back to the Play Store.
			if defined(Android)
			{
				if (string.IsNullOrEmpty(options.AppStoreUri) && InterAppUriHelper.IsApplicationId(options.Uri))
					options.AppStoreUri = InterAppUriHelper.AndroidStoreWebUri(options.Uri);
			}
		}

		static Scripting.Object ConvertResult(Context context, InterAppLaunchStatus status)
		{
			var result = context.NewObject();
			result["status"] = "opened";
			return result;
		}

		static string RequireString(object[] args, int index, string name)
		{
			if (args == null || index >= args.Length || args[index] == null)
				throw new Exception("'" + name + "' is required.");

			var value = args[index] as string;
			if (string.IsNullOrEmpty(value))
				throw new Exception("'" + name + "' must be a non-empty string.");

			return value;
		}

		static string GetString(object[] args, int index)
		{
			if (args == null || index >= args.Length || args[index] == null)
				return null;

			return args[index] as string;
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

		static bool GetBool(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return false;

			return ToBool(options[key]);
		}

		static string[] GetStringArray(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			var value = options[key];
			if (value == null)
				return null;

			var array = value as Scripting.Array;
			if (array != null)
			{
				var result = new string[array.Length];
				for (int i = 0; i < array.Length; i++)
				{
					var item = array[i];
					if (item == null)
						throw new Exception("'" + key + "' must contain only strings.");

					var str = item as string;
					result[i] = str != null ? str : item.ToString();
				}
				return result;
			}

			var single = value as string;
			if (single != null)
				return new[] { single };

			return new[] { value.ToString() };
		}

		static Dictionary<string, string> GetStringDictionary(Scripting.Object options, string key)
		{
			if (options == null || !options.ContainsKey(key))
				return null;

			var value = options[key] as Scripting.Object;
			if (value == null)
				throw new Exception("'" + key + "' must be an object.");

			var result = new Dictionary<string, string>();
			foreach (var name in value.Keys)
			{
				var item = value[name];
				result[name] = item == null ? null : (item as string ?? item.ToString());
			}
			return result;
		}

		static bool ToBool(object value)
		{
			if (value is bool)
				return (bool)value;

			return value != null && value.ToString() == "true";
		}
	}
}
