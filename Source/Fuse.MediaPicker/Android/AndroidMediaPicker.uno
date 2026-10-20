using Uno.Threading;
using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.MediaPicker
{
	[ForeignInclude(Language.Java, "com.fuse.mediapicker.MediaPicker")]
	[Require("gradle.dependency.implementation", "androidx.exifinterface:exifinterface:1.3.2")]
	public extern(Android) class AndroidMediaPicker
	{
		internal static void PickImage(Promise<string> p, Java.Object args)
		{
			var cb = new StringPromiseCallback(p);
			PickImageInternal(args, cb.Resolve, cb.Reject);
		}

		internal static void PickVideo(Promise<string> p, Java.Object args)
		{
			var cb = new StringPromiseCallback(p);
			PickVideoInternal(args, cb.Resolve, cb.Reject);
		}

		internal static void PickVideos(Promise<string> p, Java.Object args)
		{
			var cb = new StringPromiseCallback(p);
			PickVideosInternal(args, cb.Resolve, cb.Reject);
		}

		[Foreign(Language.Java)]
		static void PickImageInternal(Java.Object args, Action<string> onComplete, Action<string> onFail)
		@{
			java.util.Map<String, Object> arguments = (java.util.HashMap<String, Object>)args;
			new MediaPicker().pickImage(arguments, onComplete, onFail);
		@}

		[Foreign(Language.Java)]
		static void PickVideoInternal(Java.Object args, Action<string> onComplete, Action<string> onFail)
		@{
			java.util.Map<String, Object> arguments = (java.util.HashMap<String, Object>)args;
			MediaPicker mediaPicker = new MediaPicker();
			mediaPicker.pickVideo(arguments, onComplete, onFail);
		@}

		[Foreign(Language.Java)]
		static void PickVideosInternal(Java.Object args, Action<string> onComplete, Action<string> onFail)
		@{
			java.util.Map<String, Object> arguments = (java.util.HashMap<String, Object>)args;
			MediaPicker mediaPicker = new MediaPicker();
			mediaPicker.pickVideos(arguments, onComplete, onFail);
		@}

	}
}
