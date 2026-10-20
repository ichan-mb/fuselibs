using Uno;
using Uno.Threading;
using Uno.Compiler.ExportTargetInterop;
using Android;

namespace Fuse.Share
{
	[TargetSpecificImplementation]
	[ForeignInclude(Language.Java,
					"android.app.Activity",
					"com.fuse.share.AndroidShareHelper")]
	internal extern(Android) class AndroidShareImpl
	{
		public static void Share(ShareRequest request, Promise<ShareResult> promise)
		{
			var callback = new ShareResultCallback(promise);
			var requestCode = ActivityUtils.AllocateRequestCode();

			ShareNative(
				request.Text,
				request.Url,
				request.Files,
				request.MimeType,
				request.Subject,
				request.ChooserTitle,
				requestCode,
				callback.OnChosen,
				callback.OnCancelled,
				callback.OnError);
		}

		[Foreign(Language.Java)]
		static void ShareNative(string text, string url, string[] files, string mimeType, string subject, string chooserTitle,
			int requestCode, Action<string> onChosen, Action onCancelled, Action<string> onError)
		@{
			android.app.Activity activity = com.fuse.Activity.getRootActivity();
			if (activity == null || activity.isFinishing() || activity.isDestroyed())
			{
				onError.run("No active Android activity to show the share dialog.");
				return;
			}

			try
			{
				String[] filePaths = files != null ? files.copyArray() : null;
				com.fuse.share.AndroidShareHelper.share(
					activity,
					text,
					url,
					filePaths,
					mimeType,
					subject,
					chooserTitle,
					requestCode,
					onChosen,
					onCancelled,
					onError);
			}
			catch (Exception e)
			{
				onError.run(e.getMessage() != null ? e.getMessage() : "Could not share the specified content.");
			}
		@}
	}
}
