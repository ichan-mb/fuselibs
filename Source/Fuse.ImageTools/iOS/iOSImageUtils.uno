using Uno.Threading;
using Uno;
using Uno.Compiler.ExportTargetInterop;
using Android;
namespace Fuse.ImageTools
{
	[Require("source.include", "iOS/ImageHelper.h")]
	[Require("xcode.framework", "CoreImage.framework")]
	extern (iOS) static internal class iOSImageUtils
	{
		public static int2 GetSize(Image p)
		{
			var size = new int[2] {0, 0};
			GetSizeInternal(p.Path, size);
			return int2(size[0], size[1]);
		}

		[Foreign(Language.ObjC)]
		static void GetSizeInternal(string path, int[] values)
		@{
			NSArray* dims = [ImageHelper getImageSize:path];
			values[0] = dims[0];
			values[1] = dims[1];
		@}

		[Foreign(Language.ObjC)]
		public static string GetMimeType(string path)
		@{
			return [ImageHelper getMimeType:path];
		@}

		[Foreign(Language.ObjC)]
		public static long GetFileSize(string path)
		@{
			return (long long)[ImageHelper getFileSize:path];
		@}

		[Foreign(Language.ObjC)]
		public static int GetOrientation(string path)
		@{
			return [ImageHelper getOrientation:path];
		@}

		[Foreign(Language.ObjC)]
		public static int GetFrameCount(string path)
		@{
			return [ImageHelper getFrameCount:path];
		@}

		[Foreign(Language.ObjC)]
		public static bool HasAlpha(string path)
		@{
			return [ImageHelper hasAlpha:path];
		@}

		[Foreign(Language.ObjC)]
		public static string GetExif(string path)
		@{
			return [ImageHelper getExif:path];
		@}

		[Foreign(Language.ObjC)]
		public static void ClearCache()
		@{
			[ImageHelper clearCache];
		@}

		[Foreign(Language.ObjC)]
		public static void Resize(string path, int width, int height, int mode, string format, int quality, int background, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper resizeImage:path width:width height:height mode:mode quality:quality format:format background:background onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Crop(string path, int x, int y, int width, int height, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			CGRect rect = CGRectMake((float)x, (float)y, (float)width, (float)height);
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper cropImage:path desiredRect:rect quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Rotate(string path, double degrees, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper rotateImage:path degrees:degrees quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Flip(string path, bool horizontal, bool vertical, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper flipImage:path horizontal:horizontal vertical:vertical quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void AutoOrient(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper autoOrientImage:path quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Thumbnail(string path, int maxWidth, int maxHeight, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper thumbnailImage:path maxWidth:maxWidth maxHeight:maxHeight quality:quality format:format onComplete:onSuccess onFail:onFail];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Convert(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper convertImage:path quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Save(string path, string directory, string name, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper saveImageAtPath:path directory:directory name:name quality:quality format:format onComplete:onSuccess onFail:onFail];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Composite(string path, string overlayPath, int x, int y, double opacity, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper compositeImage:path overlay:overlayPath x:x y:y opacity:(float)opacity quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void Filter(string path, string type, double amount, int radius, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper filterImage:path type:type amount:(float)amount radius:radius quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void DrawText(string path, string text, int x, int y, double fontSize, string font, int color, string format, int quality, Action<string> onSuccess, Action<string> onFail, bool inPlace)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper drawTextImage:path text:text x:x y:y fontSize:(float)fontSize font:font color:color quality:quality format:format onComplete:onSuccess onFail:onFail performInPlace:inPlace];
			});
		@}

		[Foreign(Language.ObjC)]
		public static byte[] GetPixelBuffer(string path)
		@{
			NSData* data = [ImageHelper rgbaDataFromImageAtPath:path];
			if (data == nil)
				return NULL;

			uArray* result = @{byte[]:new((int)data.length)};
			[data getBytes:result->Ptr() length:data.length];
			return result;
		@}

		[Foreign(Language.ObjC)]
		public static void GetImageFromUri(string uri, Action<string> onSuccess, Action<string> onFail)
		@{
			NSString* path = [ImageHelper localPathFromUri:uri];
			if (path == nil) {
				onFail(@"Unsupported URI");
				return;
			}

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				if ([[NSFileManager defaultManager] fileExistsAtPath:path])
					onSuccess(path);
				else
					onFail([NSString stringWithFormat:@"File not found: %@", path]);
			});
		@}

		[Foreign(Language.ObjC)]
		public static void GetImageFromBase64(string b64, Action<string> onSuccess, Action<string> onFail)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper imageFromBase64String:b64 onComplete:onSuccess onFail:onFail];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void GetBase64FromImage(string path, string format, int quality, Action<string> onSuccess, Action<string> onFail)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper base64FromImageAtPath:path quality:quality format:format onComplete:onSuccess onFail:onFail];
			});
		@}

		[Foreign(Language.ObjC)]
		public static void GetImageFromBuffer(byte[] byteArray, Action<string> onSuccess, Action<string> onFail)
		@{
			uArray* arr = [byteArray unoArray];
			NSData* data = [NSData dataWithBytes:arr->Ptr() length:[byteArray count]];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[ImageHelper imageFromData:data onComplete:onSuccess onFail:onFail];
			});
		@}

		[Foreign(Language.ObjC)]
		public static string GetImageFromBufferSync(byte[] byteArray)
		@{
			uArray* arr = [byteArray unoArray];
			NSData* data = [NSData dataWithBytes:arr->Ptr() length:[byteArray count]];
			return [ImageHelper imageFromDataSync:data];
		@}
	}
}
