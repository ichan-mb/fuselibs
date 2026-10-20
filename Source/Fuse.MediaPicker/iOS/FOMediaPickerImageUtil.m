#import "FOMediaPickerImageUtil.h"

@implementation FOMediaPickerImageUtil

+ (UIImage *)scaledImage:(UIImage *)image
								maxWidth:(NSNumber *)maxWidth
							 maxHeight:(NSNumber *)maxHeight
					isMetadataAvailable:(BOOL)isMetadataAvailable {
	if (image == nil || image.size.width <= 0 || image.size.height <= 0) {
		return image;
	}

	double originalWidth = image.size.width;
	double originalHeight = image.size.height;
	double scale = 1.0;
	if ([maxWidth isKindOfClass:[NSNumber class]] && [maxWidth doubleValue] > 0) {
		scale = MIN(scale, [maxWidth doubleValue] / originalWidth);
	}
	if ([maxHeight isKindOfClass:[NSNumber class]] && [maxHeight doubleValue] > 0) {
		scale = MIN(scale, [maxHeight doubleValue] / originalHeight);
	}

	double width = MAX(1.0, floor(originalWidth * scale));
	double height = MAX(1.0, floor(originalHeight * scale));

	UIImage *imageToScale;
	if (isMetadataAvailable) {
		imageToScale = [UIImage imageWithCGImage:image.CGImage scale:1 orientation:UIImageOrientationUp];

		UIImageOrientation orientation = image.imageOrientation;
		if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight ||
				orientation == UIImageOrientationLeftMirrored || orientation == UIImageOrientationRightMirrored) {
			double temp = width;
			width = height;
			height = temp;
		}
	} else {
		imageToScale = [UIImage imageWithCGImage:image.CGImage scale:1 orientation:image.imageOrientation];
	}

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
	[imageToScale drawInRect:CGRectMake(0, 0, width, height)];
	UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return scaledImage;
}

@end
