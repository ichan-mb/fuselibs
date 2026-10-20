#import "FOMediaPickerMetaDataUtil.h"

static const uint8_t kFirstByteJPEG = 0xFF;
static const uint8_t kFirstBytePNG = 0x89;
static const uint8_t kFirstByteGIF = 0x47;

NSString *const kFOImagePickerDefaultSuffix = @".jpg";
const FOImagePickerMIMEType kFOImagePickerMIMETypeDefault = FOImagePickerMIMETypeJPEG;

@implementation FOMediaPickerMetaDataUtil

+ (FOImagePickerMIMEType)getImageMIMETypeFromImageData:(NSData *)imageData {
	if (imageData.length == 0) {
		return FOImagePickerMIMETypeOther;
	}

	uint8_t firstByte = 0;
	[imageData getBytes:&firstByte length:1];
	switch (firstByte) {
		case kFirstByteJPEG:
			return FOImagePickerMIMETypeJPEG;
		case kFirstBytePNG:
			return FOImagePickerMIMETypePNG;
		case kFirstByteGIF:
			return FOImagePickerMIMETypeGIF;
		default:
			return FOImagePickerMIMETypeOther;
	}
}

+ (UIImage *)normalizedImage:(UIImage *)image {
	if (image == nil || image.size.width <= 0 || image.size.height <= 0) {
		return image;
	}

	CGFloat scale = image.scale > 0 ? image.scale : 1.0;
	UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
	[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
	UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return normalized ?: image;
}

+ (NSData *)convertImage:(UIImage *)image usingType:(FOImagePickerMIMEType)type quality:(NSNumber *)quality {
	if (image == nil) {
		return nil;
	}

	if (type == FOImagePickerMIMETypePNG) {
		return UIImagePNGRepresentation(image);
	}

	return UIImageJPEGRepresentation(image, quality ? quality.floatValue : 1);
}

@end
