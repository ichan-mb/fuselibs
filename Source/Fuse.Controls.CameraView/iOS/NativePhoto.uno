using Uno;
using OpenGL;
using Uno.Graphics;
using Uno.UX;
using Uno.Compiler.ExportTargetInterop;
using Uno.Threading;
using Uno.Collections;

using Fuse;
using Fuse.Controls;
using Fuse.Controls.Native;
using Fuse.Controls.CameraView;
using Fuse.Resources.Exif;

namespace Fuse.Controls.iOS
{
	extern(iOS) class NativePhoto : Photo, IDisposable
	{
		ObjC.Object _imageData;
		int _orientation;

		public NativePhoto(ObjC.Object imageData, int orientation)
		{
			_imageData = imageData;
			_orientation = orientation;
		}

		public override Future<string> Save()
		{
			return new SavePromise(_imageData);
		}

		public override Future<string> SaveThumbnail(ThumbnailSizeHint thumbnailSizeHint = null)
		{
			return new SaveThumbnailPromise(_imageData, thumbnailSizeHint);
		}

		public override Future<bool> SaveToCameraRoll()
		{
			return new SaveToCameraRollPromise(this);
		}

		class SaveToCameraRollPromise : CameraPromise<bool>
		{
			NativePhoto _photo;

			public SaveToCameraRollPromise(NativePhoto photo)
			{
				_photo = photo;
				_photo.Save().Then(OnSaved, OnReject);
			}

			public void OnSaved(string filePath) { NativePhoto.SaveToCameraRoll(filePath, OnResolve, OnForeignReject); }
			public void OnResolve(bool success) { Resolve(success); }
			public void OnReject(Exception e) { Reject(e); }
			void OnForeignReject(string msg) { Reject(new Exception(msg)); }
		}

		[Require("xcode.framework", "Photos")]
		[Require("source.include", "Photos/PHPhotoLibrary.h")]
		[Require("source.include", "Photos/PHAssetChangeRequest.h")]
		[Foreign(Language.ObjC)]
		static void SaveToCameraRoll(string filePath, Action<bool> onResolve, Action<string> onReject)
		@{
			[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
				BOOL authorized = status == PHAuthorizationStatusAuthorized;
				if (@available(iOS 14.0, *))
					authorized = authorized || status == PHAuthorizationStatusLimited;

				if (!authorized) {
					onReject(@"Photo library permission denied");
					return;
				}

				NSURL* url = [NSURL fileURLWithPath:filePath];
				[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
					[PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
				} completionHandler:^(BOOL success, NSError* error) {
					if (success) {
						[[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
						onResolve(YES);
					} else {
						onReject(error.localizedDescription ?: @"Failed to save photo to camera roll");
					}
				}];
			}];
		@}

		public override Future<PhotoMetadata> GetMetadata()
		{
			var p = new MetadataPromise();
			GetMetadata(_imageData, p.OnResolve, p.OnReject);
			return p;
		}

		class MetadataPromise : CameraPromise<PhotoMetadata>
		{
			public void OnResolve(int width, int height, int orientation, int iso, double timestamp, float exposureTime, float fNumber, float focalLength)
			{
				Resolve(PhotoMetadata.FromExif(width, height, orientation, iso, timestamp, exposureTime, fNumber, focalLength));
			}

			public void OnReject(string message) { Reject(new Exception(message)); }
		}

		[Require("source.include", "ImageIO/ImageIO.h")]
		[Foreign(Language.ObjC)]
		static void GetMetadata(ObjC.Object imageData, Action<int,int,int,int,double,float,float,float> onResolve, Action<string> onReject)
		@{
			NSData* data = (NSData*)imageData;
			int width = 0;
			int height = 0;
			int orientation = 1;
			int iso = 0;
			double timestamp = 0.0;
			float exposureTime = 0.0f;
			float fNumber = 0.0f;
			float focalLength = 0.0f;

			CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
			if (source) {
				CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
				if (properties) {
					NSDictionary* props = (__bridge NSDictionary*)properties;

					width = [props[(NSString*)kCGImagePropertyPixelWidth] intValue];
					height = [props[(NSString*)kCGImagePropertyPixelHeight] intValue];

					NSDictionary* tiff = props[(NSString*)kCGImagePropertyTIFFDictionary];
					if ([tiff isKindOfClass:[NSDictionary class]] && tiff[(NSString*)kCGImagePropertyTIFFOrientation])
						orientation = [tiff[(NSString*)kCGImagePropertyTIFFOrientation] intValue];

					NSDictionary* exif = props[(NSString*)kCGImagePropertyExifDictionary];
					if ([exif isKindOfClass:[NSDictionary class]]) {
						NSArray* isoValues = exif[(NSString*)kCGImagePropertyExifISOSpeedRatings];
						if ([isoValues isKindOfClass:[NSArray class]] && isoValues.count > 0)
							iso = [isoValues[0] intValue];

						if (exif[(NSString*)kCGImagePropertyExifExposureTime])
							exposureTime = [exif[(NSString*)kCGImagePropertyExifExposureTime] floatValue];

						if (exif[(NSString*)kCGImagePropertyExifFNumber])
							fNumber = [exif[(NSString*)kCGImagePropertyExifFNumber] floatValue];

						if (exif[(NSString*)kCGImagePropertyExifFocalLength])
							focalLength = [exif[(NSString*)kCGImagePropertyExifFocalLength] floatValue];

						NSString* dateString = exif[(NSString*)kCGImagePropertyExifDateTimeOriginal];
						if ([dateString isKindOfClass:[NSString class]]) {
							NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
							formatter.dateFormat = @"yyyy:MM:dd HH:mm:ss";
							formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
							formatter.timeZone = [NSTimeZone localTimeZone];
							NSDate* date = [formatter dateFromString:dateString];
							if (date)
								timestamp = [date timeIntervalSince1970] * 1000.0;
						}
					}

					CFRelease(properties);
				}
				CFRelease(source);
			}

			onResolve(width, height, orientation, iso, timestamp, exposureTime, fNumber, focalLength);
		@}

		internal override Future<PhotoTexture> GetTexture()
		{
			return new UploadTexturePromise(_imageData);
		}

		internal override Future<PhotoHandle> GetPhotoHandle()
		{
			return new PhotoHandlePromise(_imageData);
		}

		public override void Release()
		{
			Dispose();
		}

		bool _isDisposed = false;
		public void Dispose()
		{
			if (!_isDisposed)
			{
				_isDisposed = true;
				_imageData = null;
			}
		}
	}

	extern(iOS) class NativePhotoHandle : PhotoHandle
	{
		public readonly ObjC.Object UIImage;

		public NativePhotoHandle(ObjC.Object uiImage)
		{
			UIImage = uiImage;
		}
	}

	extern(iOS) class PhotoHandlePromise : CameraPromise<PhotoHandle>
	{
		ObjC.Object _imageData;

		public PhotoHandlePromise(ObjC.Object imageData)
		{
			_imageData = imageData;
			Load(imageData, OnResolve, OnReject);
		}

		[Require("source.include", "UIKit/UIKit.h")]
		[Foreign(Language.ObjC)]
		static void Load(ObjC.Object imageData, Action<ObjC.Object> onResolve, Action<string> onReject)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSData* data = (NSData*)imageData;
				UIImage* image = [UIImage imageWithData:data];
				if (!image) {
					onReject(@"Failed to decode captured photo");
					return;
				}
				onResolve(image);
			});
		@}

		void OnResolve(ObjC.Object uiImage) { Resolve(new NativePhotoHandle(uiImage)); }
		void OnReject(string msg) { Reject(new Exception(msg)); }
	}

	extern(iOS) class UploadTexturePromise : CameraPromise<PhotoTexture>
	{
		class NativePhotoTexture : PhotoTexture
		{
			texture2D _texture;

			public NativePhotoTexture(texture2D texture)
			{
				_texture = texture;
			}

			public override ImageOrientation Orientation { get { return ImageOrientation.Identity; } }
			public override texture2D Texture { get { return _texture; } }

			public override void Dispose()
			{
				if (_texture != null)
				{
					_texture.Dispose();
					_texture = null;
				}
			}
		}

		ObjC.Object _imageData;

		public UploadTexturePromise(ObjC.Object imageData)
		{
			_imageData = imageData;
			GraphicsWorker.Dispatch(Upload);
		}

		void Upload()
		{
			UploadTexture(_imageData, OnResolve, OnReject);
		}

		void OnResolve(int textureName, int width, int height)
		{
			var texture = new texture2D((GLTextureHandle)textureName, int2(width, height), 1, Format.RGBA8888);
			Resolve(new NativePhotoTexture(texture));
		}

		void OnReject(string msg) { Reject(new Exception(msg)); }

		[Require("source.include", "UIKit/UIKit.h")]
		[Require("source.include", "OpenGLES/ES2/gl.h")]
		[Foreign(Language.ObjC)]
		static void UploadTexture(ObjC.Object imageData, Action<int,int,int> onResolve, Action<string> onReject)
		@{
			NSData* data = (NSData*)imageData;
			UIImage* image = [UIImage imageWithData:data];
			if (!image) {
				onReject(@"Failed to decode captured photo");
				return;
			}

			CGImageRef cgImage = image.CGImage;
			size_t width = CGImageGetWidth(cgImage);
			size_t height = CGImageGetHeight(cgImage);
			if (width == 0 || height == 0) {
				onReject(@"Captured photo has invalid dimensions");
				return;
			}

			UIImageOrientation imageOrientation = image.imageOrientation;
			BOOL swapsDimensions =
				imageOrientation == UIImageOrientationLeft ||
				imageOrientation == UIImageOrientationRight ||
				imageOrientation == UIImageOrientationLeftMirrored ||
				imageOrientation == UIImageOrientationRightMirrored;

			size_t orientedWidth = swapsDimensions ? height : width;
			size_t orientedHeight = swapsDimensions ? width : height;
			size_t bytesPerRow = orientedWidth * 4;
			uint8_t* buffer = (uint8_t*)calloc(orientedHeight, bytesPerRow);
			if (!buffer) {
				onReject(@"Failed to allocate photo buffer");
				return;
			}

			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef context = CGBitmapContextCreate(
				buffer, orientedWidth, orientedHeight, 8, bytesPerRow, colorSpace,
				kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
			CGColorSpaceRelease(colorSpace);

			if (!context) {
				free(buffer);
				onReject(@"Failed to create photo bitmap context");
				return;
			}

			UIGraphicsPushContext(context);
			[image drawInRect:CGRectMake(0, 0, orientedWidth, orientedHeight)];
			UIGraphicsPopContext();
			CGContextRelease(context);

			GLuint textureName = 0;
			glGenTextures(1, &textureName);
			glBindTexture(GL_TEXTURE_2D, textureName);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)orientedWidth, (GLsizei)orientedHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
			glBindTexture(GL_TEXTURE_2D, 0);

			free(buffer);
			onResolve((int)textureName, (int)orientedWidth, (int)orientedHeight);
		@}
	}

	extern(iOS) class SavePromise : CameraPromise<string>
	{
		public SavePromise(ObjC.Object imageData)
		{
			Save(imageData, OnResolve, OnReject);
		}

		[Foreign(Language.ObjC)]
		static void Save(ObjC.Object imageData, Action<string> resolve, Action<string> reject)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSData* data = (NSData*)imageData;
				if (!data) {
					reject(@"Photo has been disposed");
					return;
				}

				NSString* dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
				NSString* path = [NSString stringWithFormat:@"%@/IMG_%@.jpg", dir, [[NSUUID UUID] UUIDString]];

				NSError* error = nil;
				if (![data writeToFile:path options:NSDataWritingWithoutOverwriting error:&error])
					reject([NSString stringWithFormat:@"Failed to save image: %@", error]);
				else
					resolve(path);
			});
		@}

		void OnResolve(string filePath) { Resolve(filePath); }
		void OnReject(string msg) { Reject(new Exception(msg)); }
	}

	extern(iOS) class SaveThumbnailPromise : CameraPromise<string>
	{
		public SaveThumbnailPromise(ObjC.Object imageData, ThumbnailSizeHint thumbnailSizeHint)
		{
			var widthHint = 0.0f;
			var heightHint = 0.0f;
			var useSizeHint = false;
			if (thumbnailSizeHint != null)
			{
				var pixelsPerPoint = Fuse.App.Current.RootViewport.PixelsPerPoint;
				widthHint = Math.Max(thumbnailSizeHint.Width, 8) * pixelsPerPoint;
				heightHint = Math.Max(thumbnailSizeHint.Height, 8) * pixelsPerPoint;
				useSizeHint = true;
			}
			SaveThumbnail(imageData, Resolve, OnReject, useSizeHint, widthHint, heightHint);
		}

		void OnReject(string msg) { Reject(new Exception(msg)); }

		[Require("source.include", "UIKit/UIKit.h")]
		[Foreign(Language.ObjC)]
		static void SaveThumbnail(
			ObjC.Object imageData,
			Action<string> resolve,
			Action<string> reject,
			bool useSizeHint,
			float widthHint,
			float heightHint)
		@{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSData* data = (NSData*)imageData;
				UIImage* image = [UIImage imageWithData:data];
				if (!image) {
					reject(@"Failed to decode captured photo");
					return;
				}

				CGSize sourceSize = image.size;
				if (sourceSize.width <= 0 || sourceSize.height <= 0) {
					reject(@"Captured photo has invalid dimensions");
					return;
				}

				UIImageOrientation imageOrientation = image.imageOrientation;
				BOOL swapsDimensions =
					imageOrientation == UIImageOrientationLeft ||
					imageOrientation == UIImageOrientationRight ||
					imageOrientation == UIImageOrientationLeftMirrored ||
					imageOrientation == UIImageOrientationRightMirrored;

				if (swapsDimensions)
					sourceSize = CGSizeMake(sourceSize.height, sourceSize.width);

				CGFloat targetWidth;
				CGFloat targetHeight;
				if (useSizeHint) {
					targetWidth = MIN(widthHint, sourceSize.width);
					targetHeight = MIN(heightHint, sourceSize.height);
				} else {
					CGRect screenBounds = [[UIScreen mainScreen] bounds];
					CGFloat screenScale = [[UIScreen mainScreen] scale];
					targetWidth = (screenBounds.size.width * screenScale) / 2;
					targetHeight = (screenBounds.size.height * screenScale) / 2;
				}

				CGFloat scale = MIN(targetWidth / sourceSize.width, targetHeight / sourceSize.height);
				CGSize targetSize = CGSizeMake(ceil(sourceSize.width * scale), ceil(sourceSize.height * scale));
				if (targetSize.width < 1 || targetSize.height < 1) {
					reject(@"Captured photo thumbnail has invalid dimensions");
					return;
				}

				UIGraphicsImageRendererFormat* format = [UIGraphicsImageRendererFormat defaultFormat];
				format.scale = 1.0;
				UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
				UIImage* thumbnail = [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
					[image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
				}];

				NSData* thumbnailData = UIImageJPEGRepresentation(thumbnail, 1.0f);
				if (!thumbnailData) {
					reject(@"Failed to encode photo thumbnail");
					return;
				}

				NSString* dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
				NSString* path = [NSString stringWithFormat:@"%@/IMG_%@.jpg", dir, [[NSUUID UUID] UUIDString]];

				NSError* error = nil;
				if (![thumbnailData writeToFile:path options:NSDataWritingWithoutOverwriting error:&error])
					reject([NSString stringWithFormat:@"Failed to save thumbnail: %@", error]);
				else
					resolve(path);
			});
		@}
	}
}
