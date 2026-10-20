using Uno;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;

namespace Fuse.Share
{
	[ForeignInclude(Language.ObjC, "iOS/ShareUI.h")]
	internal extern(iOS) class iOSShareImpl
	{
		public static void Share(ShareRequest request, Promise<ShareResult> promise)
		{
			var callback = new ShareResultCallback(promise);
			ShareNative(
				request.Text,
				request.Url,
				request.Files,
				request.Subject,
				request.HasOrigin,
				request.Origin.X,
				request.Origin.Y,
				callback.OnChosen,
				callback.OnCancelled,
				callback.OnError);
		}

		[Foreign(Language.ObjC)]
		static void ShareNative(string text, string url, string[] files, string subject,
			bool hasOrigin, float originX, float originY,
			Action<string> onChosen, Action onCancelled, Action<string> onError)
		@{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSString* error = nil;
				NSArray* activityItems = FuseShareCreateActivityItems(
					text, url, [files copyArray], subject, &error);

				if (activityItems == nil)
				{
					onError(error != nil ? error : @"No content to share.");
					return;
				}

				UIActivityViewController* activityVC = [[UIActivityViewController alloc]
					initWithActivityItems:activityItems
					applicationActivities:nil];

				UIViewController* presenter = FuseShareTopViewController();
				if (!presenter || !presenter.view.window)
				{
					onError(@"No view controller available to present the share dialog.");
					return;
				}

				BOOL isPad = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
				BOOL isRegularWidth = presenter.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
				BOOL usePopover = isPad && isRegularWidth && CGRectGetWidth(presenter.view.bounds) >= 768.0;

				FuseSharePresentActivity(
					activityVC,
					presenter,
					usePopover,
					hasOrigin,
					originX,
					originY,
					^(UIActivityType activityType, BOOL completed) {
						if (completed)
							onChosen(activityType != nil ? activityType : @"");
						else
							onCancelled();
					});
			});
		@}
	}
}
