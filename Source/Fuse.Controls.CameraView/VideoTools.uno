using Uno.Threading;
using Uno;
using Uno.UX;
using Fuse.Scripting;
using Fuse.Scripting.JSObjectUtils;
using Uno.Compiler.ExportTargetInterop;

namespace Fuse.VideoTools
{
	/**
		@scriptmodule FuseJS/VideoTools

		Utility methods for video files manipulation. Currently only supports moving a video file to the camera roll.

		> To use this module, add `Fuse.Controls.CameraView` to your package references in your `.unoproj`.


		## Example
		```xml
			<JavaScript>
				var VideoTools = require("FuseJS/VideoTools");

				VideoTools.copyVideoToCameraRoll(somePath);
			</JavaScript>
		```
	*/
	[UXGlobalModule]
	public class VideoTools : NativeModule
	{

		static readonly VideoTools _instance;

		public VideoTools()
		{
			if(_instance != null) return;
			Resource.SetGlobalKey(_instance = this, "FuseJS/VideoTools");
			AddMember(new NativeFunction("copyVideoToCameraRoll", CopyVideoToCameraRoll));
		}

		/**
			Copy a video to the camera roll.

			@scriptmethod copyVideoToCameraRoll(videoPath)
		*/
		object CopyVideoToCameraRoll(Context c, object[] args)
		{
			if(args.Length < 1) return false;

			if defined(iOS)
			{
				return iOSVideoTools.SaveVideo(args[0].ToString());
			}
			else if defined (Android)
			{
				return AndroidVideoTools.SaveVideo(args[0].ToString());
			}
			else
			{
				return false;
			}
		}

		extern (iOS) internal class iOSVideoTools
		{
			[Require("xcode.framework", "Photos")]
			[Require("source.include", "Photos/PHPhotoLibrary.h")]
			[Require("source.include", "Photos/PHAssetChangeRequest.h")]
			[Foreign(Language.ObjC)]
			extern (iOS) public static bool SaveVideo(string outputFileURL)
			@{
				NSURL *url = [NSURL fileURLWithPath:outputFileURL];
				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
						PHAssetChangeRequest *changeRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
						NSLog(@"%@", changeRequest.description);
				} completionHandler:^(BOOL success, NSError *error) {
					if (success) {
						NSLog(@"saved down");
					} else {
						NSLog(@"something wrong %@", error.localizedDescription);
					}
				}];
				return true;
			@}
		}

		[ForeignInclude(Language.Java,
			"com.fuse.controls.cameraview.CameraStorage"
		)]
		extern (Android) internal class AndroidVideoTools
		{
			[Foreign(Language.Java)]
			public static bool SaveVideo(string outputFileURL)
			@{
				return CameraStorage.saveVideoToGallery(outputFileURL);
			@}
		}
	}
}
