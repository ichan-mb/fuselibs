using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.LauncherImpl
{
	[ForeignInclude(Language.ObjC, "UIKit/UIKit.h")]
	internal extern(iOS) static class InterAppPlatformIOS
	{
		public static bool CanOpenUri(string uri)
		{
			return CanOpenUriNative(uri);
		}

		public static void LaunchUri(string uri, bool universalLinksOnly,
			Action onOpened, Action<string> onError)
		{
			LaunchUriNative(uri, universalLinksOnly, onOpened, onError);
		}

		public static void OpenSettings(Action onOpened, Action<string> onError)
		{
			OpenSettingsNative(onOpened, onError);
		}

		[Foreign(Language.ObjC)]
		static bool CanOpenUriNative(string uri)
		@{
			if (uri == nil || uri.length == 0)
				return NO;

			__block BOOL available = NO;
			void (^check)(void) = ^{
				NSURL* url = [NSURL URLWithString:uri];
				available = url != nil && url.scheme.length > 0 &&
					[[UIApplication sharedApplication] canOpenURL:url];
			};

			if ([NSThread isMainThread])
				check();
			else
				dispatch_sync(dispatch_get_main_queue(), check);

			return available;
		@}

		[Foreign(Language.ObjC)]
		static void LaunchUriNative(string uri, bool universalLinksOnly,
			Action onOpened, Action<string> onError)
		@{
			if (uri == nil || uri.length == 0)
			{
				onError(@"A URI is required.");
				return;
			}

			void (^open)(void) = ^{
				NSURL* url = [NSURL URLWithString:uri];
				if (url == nil || url.scheme.length == 0)
				{
					onError(@"Invalid URL. A URI scheme is required.");
					return;
				}

				if (@available(iOS 10.0, *))
				{
					NSMutableDictionary* options = [NSMutableDictionary dictionary];
					if (universalLinksOnly)
						options[UIApplicationOpenURLOptionUniversalLinksOnly] = @YES;

					[[UIApplication sharedApplication] openURL:url options:options completionHandler:^(BOOL success) {
						if (success)
							onOpened();
						else
							onError(@"No app is available to handle this request.");
					}];
				}
				else
				{
					#pragma clang diagnostic push
					#pragma clang diagnostic ignored "-Wdeprecated-declarations"
					BOOL success = [[UIApplication sharedApplication] openURL:url];
					#pragma clang diagnostic pop

					if (success)
						onOpened();
					else
						onError(@"No app is available to handle this request.");
				}
			};

			if ([NSThread isMainThread])
				open();
			else
				dispatch_async(dispatch_get_main_queue(), open);
		@}

		[Foreign(Language.ObjC)]
		static void OpenSettingsNative(Action onOpened, Action<string> onError)
		@{
			void (^open)(void) = ^{
				NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
				if (url == nil)
				{
					onError(@"Could not create the settings URL.");
					return;
				}

				if (@available(iOS 10.0, *))
				{
					[[UIApplication sharedApplication] openURL:url options:[NSDictionary dictionary] completionHandler:^(BOOL success) {
						if (success)
							onOpened();
						else
							onError(@"Could not open app settings.");
					}];
				}
				else
				{
					#pragma clang diagnostic push
					#pragma clang diagnostic ignored "-Wdeprecated-declarations"
					BOOL success = [[UIApplication sharedApplication] openURL:url];
					#pragma clang diagnostic pop

					if (success)
						onOpened();
					else
						onError(@"Could not open app settings.");
				}
			};

			if ([NSThread isMainThread])
				open();
			else
				dispatch_async(dispatch_get_main_queue(), open);
		@}
	}
}
