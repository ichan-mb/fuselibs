#import "ImageHelper.h"
#import "ImageHelper+Private.h"
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import <math.h>

// These methods are declared on ImageHelper but implemented in this category.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation ImageHelper (Transform)
+(void)cropImage:(NSString*)path
		desiredRect:(CGRect)rect
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try
	{
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		CGFloat left = MAX(0, rect.origin.x);
		CGFloat top = MAX(0, rect.origin.y);
		CGFloat width = MIN(rect.size.width, image.size.width - left);
		CGFloat height = MIN(rect.size.height, image.size.height - top);

		if (width <= 0 || height <= 0) {
			onFail(@"Crop rectangle is outside image bounds");
			return;
		}

		CGImageRef cropped = CGImageCreateWithImageInRect(
				image.CGImage, CGRectMake(left, top, width, height));
		UIImage* newImage = [UIImage imageWithCGImage:cropped scale:1.0 orientation:UIImageOrientationUp];
		CGImageRelease(cropped);

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:newImage path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	}
	@catch (NSException* e)
	{
		onFail([NSString stringWithFormat:@"Image crop error: %@", e]);
	}
}


+(void)resizeImage:(NSString*)path
		width:(float)desiredWidth
		height:(float)desiredHeight
		mode:(int)mode
		quality:(int)quality
		format:(NSString*)format
		background:(int)background
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{

	@try {

		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		if (desiredWidth <= 0 || desiredHeight <= 0) {
			onFail(@"desiredWidth and desiredHeight must be larger than 0");
			return;
		}

		BOOL orientationChanged = original.imageOrientation != UIImageOrientationUp;
		BOOL hasFormat = format != nil && [format length] > 0;

		UIImage* image = [self correctImageOrientation:original];
		float width = image.size.width;
		float height = image.size.height;
		float ratio;

		UIImage* newImage = nil;

		switch(mode){
			case 1:
				//Keep aspect
				ratio = 1.0f;
				if (width > desiredWidth)
					ratio = desiredWidth / width;
				if (height * ratio > desiredHeight)
					ratio = desiredHeight / height;

				width = MAX(1, roundf(width * ratio));
				height = MAX(1, roundf(height * ratio));

				if (!orientationChanged && !hasFormat &&
						(int)width == (int)image.size.width && (int)height == (int)image.size.height) {
					onComplete(path);
					return;
				}

				newImage = [self renderImage:image size:CGSizeMake(width, height)];
				break;
			case 2:
			{
				//Scale to cover the target bounds, then crop the center
				ratio = MAX(desiredWidth / width, desiredHeight / height);

				width = MAX(1, roundf(width * ratio));
				height = MAX(1, roundf(height * ratio));

				UIImage* scaled = [self renderImage:image size:CGSizeMake(width, height)];

				CGRect cropRect = CGRectMake(
						MAX(0, (width - desiredWidth) / 2),
						MAX(0, (height - desiredHeight) / 2),
						MIN(desiredWidth, width),
						MIN(desiredHeight, height));

				CGImageRef cgimage = CGImageCreateWithImageInRect(scaled.CGImage, cropRect);
				newImage = [UIImage imageWithCGImage:cgimage scale:1.0 orientation:UIImageOrientationUp];
				CGImageRelease(cgimage);
				break;
			}
			case 3:
			{
				//Fit inside the desired bounds, preserving aspect ratio
				ratio = MIN(desiredWidth / width, desiredHeight / height);
				int w = MAX(1, lroundf(width * ratio));
				int h = MAX(1, lroundf(height * ratio));
				newImage = [self renderImage:image size:CGSizeMake(w, h)];
				break;
			}
			case 4:
			{
				//Fit inside the desired bounds, then center on a filled canvas
				ratio = MIN(desiredWidth / width, desiredHeight / height);
				int w = MAX(1, lroundf(width * ratio));
				int h = MAX(1, lroundf(height * ratio));

				UIImage* scaled = [self renderImage:image size:CGSizeMake(w, h)];

				UIGraphicsBeginImageContextWithOptions(CGSizeMake(desiredWidth, desiredHeight), NO, 1.0);
				CGContextRef ctx = UIGraphicsGetCurrentContext();
				CGFloat a = ((background >> 24) & 0xFF) / 255.0f;
				CGFloat r = ((background >> 16) & 0xFF) / 255.0f;
				CGFloat g = ((background >> 8) & 0xFF) / 255.0f;
				CGFloat b = (background & 0xFF) / 255.0f;
				CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor);
				CGContextFillRect(ctx, CGRectMake(0, 0, desiredWidth, desiredHeight));
				[scaled drawInRect:CGRectMake(
						(desiredWidth - w) / 2.0f,
						(desiredHeight - h) / 2.0f,
						w, h)];
				newImage = UIGraphicsGetImageFromCurrentImageContext();
				UIGraphicsEndImageContext();
				break;
			}
			default:
				//Use width/height as given
				if (!orientationChanged && !hasFormat &&
						(int)image.size.width == (int)desiredWidth && (int)image.size.height == (int)desiredHeight) {
					onComplete(path);
					return;
				}

				newImage = [self renderImage:image size:CGSizeMake(desiredWidth, desiredHeight)];
				break;
		}

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:newImage path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	}@catch (NSException * e){
		onFail([NSString stringWithFormat:@"Image resize error: %@", e]);
	}
}

+(void)rotateImage:(NSString*)path
		degrees:(double)degrees
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		double normalized = fmod(degrees, 360.0);
		if (normalized < 0)
			normalized += 360.0;

		BOOL hasFormat = format != nil && [format length] > 0;

		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		BOOL orientationChanged = original.imageOrientation != UIImageOrientationUp;

		if (normalized == 0 && !hasFormat && !orientationChanged && inPlace) {
			onComplete(path);
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		CGFloat radians = (CGFloat)normalized * (CGFloat)M_PI / 180.0f;
		CGFloat cosine = fabs(cos(radians));
		CGFloat sine = fabs(sin(radians));

		CGFloat width = round(image.size.width * cosine + image.size.height * sine);
		CGFloat height = round(image.size.width * sine + image.size.height * cosine);

		UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		CGContextTranslateCTM(ctx, width / 2, height / 2);
		CGContextRotateCTM(ctx, radians);
		[image drawInRect:CGRectMake(-image.size.width / 2, -image.size.height / 2,
				image.size.width, image.size.height)];
		UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:newImage path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image rotate error: %@", e]);
	}
}

+(void)flipImage:(NSString*)path
		horizontal:(BOOL)horizontal
		vertical:(BOOL)vertical
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0);
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		CGContextTranslateCTM(ctx, horizontal ? image.size.width : 0, vertical ? image.size.height : 0);
		CGContextScaleCTM(ctx, horizontal ? -1 : 1, vertical ? -1 : 1);
		[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
		UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:newImage path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image flip error: %@", e]);
	}
}

+(void)autoOrientImage:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		BOOL hasFormat = format != nil && [format length] > 0;

		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		if (original.imageOrientation == UIImageOrientationUp && !hasFormat && inPlace) {
			onComplete(path);
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:image path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image orient error: %@", e]);
	}
}

+(void)thumbnailImage:(NSString*)path
		maxWidth:(int)maxWidth
		maxHeight:(int)maxHeight
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
{
	@try {
		if (maxWidth <= 0 && maxHeight <= 0) {
			onFail(@"maxWidth and/or maxHeight must be larger than 0");
			return;
		}

		NSArray* size = [self getImageSize:path];
		CGFloat sourceWidth = [size[0] floatValue];
		CGFloat sourceHeight = [size[1] floatValue];

		if (sourceWidth <= 0 || sourceHeight <= 0) {
			onFail(@"Could not load image");
			return;
		}

		float ratio = 1.0f;
		if (maxWidth > 0)
			ratio = MIN(ratio, maxWidth / sourceWidth);
		if (maxHeight > 0)
			ratio = MIN(ratio, maxHeight / sourceHeight);
		ratio = MIN(ratio, 1.0f);

		int width = MAX(1, lroundf(sourceWidth * ratio));
		int height = MAX(1, lroundf(sourceHeight * ratio));

		NSURL* url = [NSURL fileURLWithPath:path];
		CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
		if (source == nil) {
			onFail(@"Could not load image");
			return;
		}

		NSDictionary* options = @{
			(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
			(id)kCGImageSourceCreateThumbnailWithTransform: @YES,
			(id)kCGImageSourceThumbnailMaxPixelSize: @(MAX(width, height))
		};

		CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
		CFRelease(source);

		if (thumbnail == NULL) {
			onFail(@"Could not create thumbnail");
			return;
		}

		UIImage* image = [UIImage imageWithCGImage:thumbnail scale:1.0 orientation:UIImageOrientationUp];
		CGImageRelease(thumbnail);

		NSString* target = [self createImagePathWithExtension:[self normalizedFormat:format path:path] temp:YES];
		if (![self saveImage:image path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image thumbnail error: %@", e]);
	}
}

+(void)convertImage:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];
		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];

		if (![self saveImage:image path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image convert error: %@", e]);
	}
}

+(void)saveImageAtPath:(NSString*)path
		directory:(NSString*)directory
		name:(NSString*)name
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
{
	@try {
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		NSString* selectedFormat = format;
		if ((selectedFormat == nil || [selectedFormat length] == 0) && name != nil && [[name pathExtension] length] > 0)
			selectedFormat = [name pathExtension];

		NSString* extension = [self normalizedFormat:selectedFormat path:path];
		NSString* targetDirectory = [directory isEqualToString:@"temp"]
			? [self createImagePath:YES]
			: [self createImagePath:NO];

		NSString* fileName;
		if (name != nil && [name length] > 0) {
			NSString* base = [name stringByDeletingPathExtension];
			fileName = [NSString stringWithFormat:@"%@.%@", base, extension];
		} else {
			fileName = [NSString stringWithFormat:@"IMG_%@.%@", [[NSUUID UUID] UUIDString], extension];
		}

		NSString* target = [targetDirectory stringByAppendingPathComponent:fileName];
		NSFileManager* manager = [NSFileManager defaultManager];

		if ([manager fileExistsAtPath:target]) {
			NSString* base = [target stringByDeletingPathExtension];
			for (int i = 1; i < 1000; i++) {
				NSString* candidate = [NSString stringWithFormat:@"%@-%d.%@", base, i, extension];
				if (![manager fileExistsAtPath:candidate]) {
					target = candidate;
					break;
				}
			}
		}

		if (![self saveImage:image path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image save error: %@", e]);
	}
}

+(void) compositeImage:(NSString*)path
		overlay:(NSString*)overlayPath
		x:(int)x
		y:(int)y
		opacity:(float)opacity
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		UIImage* baseOriginal = [UIImage imageWithContentsOfFile:path];
		UIImage* overlayOriginal = [UIImage imageWithContentsOfFile:overlayPath];
		if (baseOriginal == nil || overlayOriginal == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* base = [self correctImageOrientation:baseOriginal];
		UIImage* overlay = [self correctImageOrientation:overlayOriginal];

		UIGraphicsBeginImageContextWithOptions(base.size, NO, 1.0);
		[base drawInRect:CGRectMake(0, 0, base.size.width, base.size.height)];
		[overlay drawInRect:CGRectMake(x, y, overlay.size.width, overlay.size.height)
				blendMode:kCGBlendModeNormal
				alpha:MAX(0.0f, MIN(1.0f, opacity))];
		UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:result path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image composite error: %@", e]);
	}
}

+(void) filterImage:(NSString*)path
		type:(NSString*)type
		amount:(float)amount
		radius:(int)radius
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];
		CIImage* input = [CIImage imageWithCGImage:image.CGImage];
		CIFilter* filter = nil;

		if ([type isEqualToString:@"grayscale"]) {
			filter = [CIFilter filterWithName:@"CIColorMonochrome"];
			[filter setValue:input forKey:kCIInputImageKey];
			[filter setValue:[CIColor colorWithRed:1 green:1 blue:1] forKey:@"inputColor"];
			[filter setValue:@1.0 forKey:@"inputIntensity"];
		} else if ([type isEqualToString:@"sepia"]) {
			filter = [CIFilter filterWithName:@"CISepiaTone"];
			[filter setValue:input forKey:kCIInputImageKey];
			[filter setValue:@1.0 forKey:@"inputIntensity"];
		} else if ([type isEqualToString:@"brightness"] || [type isEqualToString:@"contrast"] || [type isEqualToString:@"saturation"]) {
			filter = [CIFilter filterWithName:@"CIColorControls"];
			[filter setValue:input forKey:kCIInputImageKey];

			if ([type isEqualToString:@"brightness"])
				[filter setValue:@(amount) forKey:@"inputBrightness"];
			else if ([type isEqualToString:@"contrast"])
				[filter setValue:@(1.0f + amount) forKey:@"inputContrast"];
			else
				[filter setValue:@(1.0f + amount) forKey:@"inputSaturation"];
		} else if ([type isEqualToString:@"blur"]) {
			filter = [CIFilter filterWithName:@"CIGaussianBlur"];
			[filter setValue:input forKey:kCIInputImageKey];
			[filter setValue:@(MAX(0.1f, (float)radius)) forKey:@"inputRadius"];
		} else {
			onFail(@"Unsupported filter type");
			return;
		}

		CIImage* output = filter.outputImage;
		if (output == nil) {
			onFail(@"Could not apply filter");
			return;
		}

		if ([type isEqualToString:@"blur"])
			output = [output imageByCroppingToRect:input.extent];

		CIContext* context = [CIContext contextWithOptions:nil];
		CGImageRef cgImage = [context createCGImage:output fromRect:output.extent];
		if (cgImage == NULL) {
			onFail(@"Could not render filter");
			return;
		}

		UIImage* result = [UIImage imageWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationUp];
		CGImageRelease(cgImage);

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:result path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image filter error: %@", e]);
	}
}

+(void)drawTextImage:(NSString*)path
		text:(NSString*)text
		x:(int)x
		y:(int)y
		fontSize:(float)fontSize
		font:(NSString*)font
		color:(int)color
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace
{
	@try {
		UIImage* original = [UIImage imageWithContentsOfFile:path];
		if (original == nil) {
			onFail(@"Could not load image");
			return;
		}

		UIImage* image = [self correctImageOrientation:original];

		UIGraphicsBeginImageContextWithOptions(image.size, NO, 1.0);
		[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];

		UIFont* uiFont = nil;
		if (font != nil && [font length] > 0)
			uiFont = [UIFont fontWithName:font size:fontSize];
		if (uiFont == nil)
			uiFont = [UIFont systemFontOfSize:fontSize];

		CGFloat a = ((color >> 24) & 0xFF) / 255.0f;
		CGFloat r = ((color >> 16) & 0xFF) / 255.0f;
		CGFloat g = ((color >> 8) & 0xFF) / 255.0f;
		CGFloat b = (color & 0xFF) / 255.0f;

		NSDictionary* attributes = @{
			NSFontAttributeName: uiFont,
			NSForegroundColorAttributeName: [UIColor colorWithRed:r green:g blue:b alpha:a]
		};

		[text drawAtPoint:CGPointMake(x, y) withAttributes:attributes];

		UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();

		NSString* target = [self targetPathForImage:path format:format inPlace:inPlace];
		if (![self saveImage:result path:target quality:quality]) {
			onFail(@"Could not save image");
			return;
		}

		onComplete(target);
	} @catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image text error: %@", e]);
	}
}
@end
#pragma clang diagnostic pop
