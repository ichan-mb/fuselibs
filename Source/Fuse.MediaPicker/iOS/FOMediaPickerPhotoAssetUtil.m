#import "FOMediaPickerPhotoAssetUtil.h"
#import "FOMediaPickerMetaDataUtil.h"

@implementation FOMediaPickerPhotoAssetUtil

+ (PHAsset *)getAssetFromImagePickerInfo:(NSDictionary *)info {
	if (@available(iOS 11, *)) {
		return [info objectForKey:UIImagePickerControllerPHAsset];
	}
	NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];
	if (!referenceURL) {
		return nil;
	}
	PHFetchResult<PHAsset *> *result = [PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil];
	return result.firstObject;
}

+ (PHAsset *)getAssetFromPHPickerResult:(PHPickerResult *)result API_AVAILABLE(ios(14)) {
	if (result.assetIdentifier == nil) {
		return nil;
	}
	PHFetchResult *fetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[ result.assetIdentifier ] options:nil];
	return fetchResult.firstObject;
}

+ (NSString *)saveImageWithOriginalImageData:(NSData *)originalImageData
                                       image:(UIImage *)image
                                imageQuality:(NSNumber *)imageQuality {
	if (image == nil) {
		return nil;
	}

	FOImagePickerMIMEType type = originalImageData
			? [FOMediaPickerMetaDataUtil getImageMIMETypeFromImageData:originalImageData]
			: kFOImagePickerMIMETypeDefault;

	// GIF and unknown types are encoded as JPEG, so only PNG gets a .png suffix.
	NSString *suffix = (type == FOImagePickerMIMETypePNG) ? @".png" : kFOImagePickerDefaultSuffix;

	NSData *data = [FOMediaPickerMetaDataUtil convertImage:[FOMediaPickerMetaDataUtil normalizedImage:image]
																							 usingType:type
																									quality:imageQuality];
	if (data.length == 0) {
		NSLog(@"media_picker: image encoding produced no data");
		return nil;
	}

	NSString *path = [self temporaryFilePath:suffix];
	if (![[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil]) {
		NSLog(@"media_picker: failed to create file at %@", path);
		return nil;
	}

	return path;
}

+ (NSString *)temporaryFilePath:(NSString *)suffix {
	NSString *filenameFormat = [@"media_picker_%@" stringByAppendingString:suffix];
	NSString *filename = [NSString stringWithFormat:filenameFormat, [[NSProcessInfo processInfo] globallyUniqueString]];
	return [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
}

@end
