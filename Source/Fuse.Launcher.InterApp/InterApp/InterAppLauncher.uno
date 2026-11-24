using Uno;
using Uno.Threading;

namespace Fuse.LauncherImpl
{
	public static class InterAppLauncher
	{
		enum LaunchKind
		{
			Uri,
			App,
			Package
		}

		delegate void PlatformLaunch(Action onOpened, Action<string> onError);

		/**
			Whether the platform can open the given URI.

			On Android this is subject to Android 11 package visibility. See
			`Android.Queries.Schemes` and `Android.Queries.Packages`.

			On iOS schemes must be declared in `LSApplicationQueriesSchemes`.
		*/
		public static bool CanOpenUri(string uri)
		{
			if (string.IsNullOrEmpty(uri))
				return false;

			if defined(Android)
				return InterAppPlatformAndroid.CanOpenUri(uri);
			else if defined(iOS)
				return InterAppPlatformIOS.CanOpenUri(uri);
			else
				return false;
		}

		/**
			Whether the platform can launch the given application.

			On Android `applicationId` is a package name, for example
			`"com.example.app"`. On iOS it is a URI scheme, for example
			`"myapp://"`, because iOS has no API for querying an application by
			bundle identifier.
		*/
		public static bool CanLaunchApp(string applicationId)
		{
			if (string.IsNullOrEmpty(applicationId))
				return false;

			if defined(Android)
				return InterAppPlatformAndroid.CanLaunchApp(applicationId);
			else if defined(iOS)
				return InterAppPlatformIOS.CanOpenUri(applicationId);
			else
				return false;
		}

		/**
			Open a URI.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchUri(string uri)
		{
			return LaunchUri(new InterAppLaunchOptions { Uri = uri });
		}

		/**
			Open a URI with explicit launch options.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchUri(InterAppLaunchOptions options)
		{
			if (options == null)
				return Rejected(new ArgumentNullException(nameof(options)));

			if (string.IsNullOrEmpty(options.Uri))
				return Rejected(new Exception("A URI is required."));

			return Launch(options, LaunchKind.Uri);
		}

		/**
			Launch an app by URI, or on Android by package id.

			The returned future resolves to `InterAppLaunchStatus.Opened` once
			the platform hands the request to another application, and rejects
			with a user-facing message when it cannot.
		*/
		public static Future<InterAppLaunchStatus> LaunchApp(InterAppLaunchOptions options)
		{
			if (options == null)
				return Rejected(new ArgumentNullException(nameof(options)));

			if (string.IsNullOrEmpty(options.Uri))
				return Rejected(new Exception("A URI or application id is required."));

			return Launch(options, LaunchKind.App);
		}

		/**
			Launch an Android application by package id.

			Unlike `LaunchApp`, this never treats the argument as a URI.
			iOS has no API for launching an application by bundle identifier, so
			this rejects on iOS.
		*/
		public static Future<InterAppLaunchStatus> LaunchPackage(
			string applicationId, InterAppLaunchOptions options = null)
		{
			if (string.IsNullOrEmpty(applicationId))
				return Rejected(new Exception("An application id is required."));

			var launchOptions = options != null ? options.Clone() : new InterAppLaunchOptions();
			launchOptions.Uri = applicationId;

			return Launch(launchOptions, LaunchKind.Package);
		}

		/**
			Open the operating system's settings page for this application.

			The returned future resolves to `InterAppLaunchStatus.Opened` once the
			settings page is shown, and rejects with a user-facing message when it
			cannot be opened.
		*/
		public static Future<InterAppLaunchStatus> OpenSettings()
		{
			if defined(Android)
				return Run(InterAppPlatformAndroid.OpenSettings);
			else if defined(iOS)
				return Run(InterAppPlatformIOS.OpenSettings);
			else
				return Rejected(new Exception("App settings are not supported on this platform."));
		}

		static Future<InterAppLaunchStatus> Run(PlatformLaunch launch)
		{
			var promise = new Promise<InterAppLaunchStatus>();

			try
			{
				launch(
					() => promise.Resolve(InterAppLaunchStatus.Opened),
					error => promise.Reject(new Exception(error)));
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		/**
			Open the store page for this application.

			Set `StoreUri` to open an explicit store URL. Otherwise provide
			`AndroidPackage` on Android or `AppStoreId` on iOS. When a package or
			App Store id is used and the native store cannot be opened, the future
			falls back to the corresponding web store page.

			The returned future resolves to `InterAppLaunchStatus.Opened` once the
			store page is shown, and rejects with a user-facing message when it
			cannot be opened.
		*/
		public static Future<InterAppLaunchStatus> OpenStore(InterAppStoreOptions options)
		{
			if (options == null)
				return Rejected(new ArgumentNullException(nameof(options)));

			string primary = null;
			string fallback = null;

			if defined(Android)
			{
				if (!string.IsNullOrEmpty(options.StoreUri))
				{
					primary = options.StoreUri;
				}
				else
				{
					primary = InterAppUriHelper.AndroidStoreUri(options.AndroidPackage);
					if (!string.IsNullOrEmpty(options.AndroidPackage))
						fallback = InterAppUriHelper.AndroidStoreWebUri(options.AndroidPackage);
				}
			}
			else if defined(iOS)
			{
				if (!string.IsNullOrEmpty(options.StoreUri))
				{
					primary = options.StoreUri;
				}
				else
				{
					primary = InterAppUriHelper.AppleStoreUri(options.AppStoreId);
					if (!string.IsNullOrEmpty(options.AppStoreId))
						fallback = InterAppUriHelper.AppleStoreWebUri(options.AppStoreId);
				}
			}
			else
			{
				return Rejected(new Exception("App stores are not supported on this platform."));
			}

			if (string.IsNullOrEmpty(primary))
				return Rejected(new Exception("A store URI, Android package or App Store id is required."));

			if (fallback == primary)
				fallback = null;

			return Launch(new InterAppLaunchOptions { Uri = primary, AppStoreUri = fallback }, LaunchKind.Uri);
		}

		static Future<InterAppLaunchStatus> Launch(
			InterAppLaunchOptions options, LaunchKind kind)
		{
			var promise = new Promise<InterAppLaunchStatus>();

			if (options == null)
			{
				promise.Reject(new ArgumentNullException(nameof(options)));
				return promise;
			}

			try
			{
				options = options.Clone();

				if defined(Android)
				{
					options.AndroidFlags = InterAppUriHelper.NormalizeAndroidFlags(options.AndroidFlags);

					var isPackage = kind == LaunchKind.Package ||
						(kind == LaunchKind.App && InterAppUriHelper.IsApplicationId(options.Uri));

					if (isPackage)
					{
						InterAppPlatformAndroid.LaunchApp(options.Uri, options,
							() => promise.Resolve(InterAppLaunchStatus.Opened),
							error => OpenStoreOrReject(options, error, promise));
					}
					else
					{
						if (!string.IsNullOrEmpty(options.AndroidClassName) &&
							string.IsNullOrEmpty(options.AndroidPackage))
						{
							promise.Reject(new Exception("AndroidClassName requires AndroidPackage."));
							return promise;
						}

						InterAppPlatformAndroid.LaunchUri(options.Uri, options,
							() => promise.Resolve(InterAppLaunchStatus.Opened),
							error => OpenStoreOrReject(options, error, promise));
					}
				}
				else if defined(iOS)
				{
					if (kind == LaunchKind.Package)
					{
						promise.Reject(new Exception("Launching by application id is not supported on iOS."));
					}
					else
					{
						InterAppPlatformIOS.LaunchUri(options.Uri, options.UniversalLinksOnly,
							() => promise.Resolve(InterAppLaunchStatus.Opened),
							error => OpenStoreOrReject(options, error, promise));
					}
				}
				else
				{
					promise.Reject(new Exception("Inter-app launching is not supported on this platform."));
				}
			}
			catch (Exception e)
			{
				promise.Reject(e);
			}

			return promise;
		}

		static void OpenStoreOrReject(
			InterAppLaunchOptions options, string error, Promise<InterAppLaunchStatus> promise)
		{
			if (string.IsNullOrEmpty(options.AppStoreUri) || options.AppStoreUri == options.Uri)
			{
				promise.Reject(new Exception(error));
				return;
			}

			try
			{
				if defined(Android)
					InterAppPlatformAndroid.LaunchUri(options.AppStoreUri,
						new InterAppLaunchOptions(),
						() => promise.Resolve(InterAppLaunchStatus.Opened),
						storeError => promise.Reject(new Exception(error)));
				else if defined(iOS)
					InterAppPlatformIOS.LaunchUri(options.AppStoreUri, false,
						() => promise.Resolve(InterAppLaunchStatus.Opened),
						storeError => promise.Reject(new Exception(error)));
				else
					promise.Reject(new Exception(error));
			}
			catch (Exception e)
			{
				promise.Reject(new Exception(error));
			}
		}

		static Future<InterAppLaunchStatus> Rejected(Exception error)
		{
			var promise = new Promise<InterAppLaunchStatus>();
			promise.Reject(error);
			return promise;
		}

		/**
			Legacy fire-and-forget overload.

			Use `LaunchUri(string)` to observe whether the URI was opened.
		*/
		public static void LaunchUri(Uno.Net.Http.Uri uri)
		{
			if (uri == null)
			{
				debug_log("InterApp.LaunchUri - No URI supplied");
				return;
			}

			LaunchUri(uri.AbsoluteUri).Catch(e => { debug_log("InterApp.LaunchUri - " + e.Message); });
		}

		/**
			Legacy fire-and-forget overload.

			Use `LaunchApp(InterAppLaunchOptions)` to observe whether the app was
			launched.
		*/
		public static void LaunchApp(string uri, string appStoreUri = null)
		{
			var options = new InterAppLaunchOptions { Uri = uri, AppStoreUri = appStoreUri };

			// Preserve the legacy behavior: an Android package id falls back to
			// the Play Store when no explicit store URI is supplied.
			if defined(Android)
			{
				if (string.IsNullOrEmpty(options.AppStoreUri) && InterAppUriHelper.IsApplicationId(options.Uri))
					options.AppStoreUri = InterAppUriHelper.AndroidStoreWebUri(options.Uri);
			}

			LaunchApp(options).Catch(e => { debug_log("InterApp.LaunchApp - " + e.Message); });
		}
	}
}
