#import "ImageHelper.h"
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import <math.h>
#import "ImageHelper+Private.h"

// Transform methods are implemented in ImageHelper+Transform.m.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation ImageHelper

+(UIImage*) imageFromDictionary:(NSDictionary*)dictionary {
	return dictionary[@"UIImagePickerControllerOriginalImage"];
}

+(NSString *)contentTypeForImageData:(NSData *)data {
	if (data == nil || data.length < 3)
		return nil;

	const uint8_t* b = (const uint8_t*)data.bytes;

	if (b[0] == 0xFF && b[1] == 0xD8)
		return @"jpg";
	if (b[0] == 0x89 && b[1] == 'P' && b[2] == 'N')
		return @"png";
	if (b[0] == 'G' && b[1] == 'I' && b[2] == 'F')
		return @"gif";

	if (data.length >= 12) {
		if (b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' &&
				b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P')
			return @"webp";

		if (b[4] == 'f' && b[5] == 't' && b[6] == 'y' && b[7] == 'p')
			return @"heic";
	}

	return nil;
}

+(NSString*) getMimeType:(NSString*)path {
	NSData* data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
	NSString* extension = [self contentTypeForImageData:data];

	if ([extension isEqualToString:@"jpg"])
		return @"image/jpeg";
	if ([extension isEqualToString:@"png"])
		return @"image/png";
	if ([extension isEqualToString:@"gif"])
		return @"image/gif";
	if ([extension isEqualToString:@"webp"])
		return @"image/webp";
	if ([extension isEqualToString:@"heic"])
		return @"image/heic";

	return @"";
}

+(long long) getFileSize:(NSString*)path {
	NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
	return attributes != nil ? [[attributes objectForKey:NSFileSize] longLongValue] : 0;
}

+(int) getOrientation:(NSString*)path {
	NSURL* url = [NSURL fileURLWithPath:path];
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
	if (source == nil)
		return 1;

	int orientation = 1;
	CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil);
	if (properties != nil) {
		CFNumberRef value = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
		if (value != nil)
			CFNumberGetValue(value, kCFNumberIntType, &orientation);
		CFRelease(properties);
	}
	CFRelease(source);
	return orientation;
}

+(int) getFrameCount:(NSString*)path {
	NSURL* url = [NSURL fileURLWithPath:path];
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
	if (source == nil)
		return 1;

	size_t count = CGImageSourceGetCount(source);
	CFRelease(source);

	return (int)MAX(1, count);
}

+(BOOL) hasAlpha:(NSString*)path {
	NSURL* url = [NSURL fileURLWithPath:path];
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
	if (source == nil)
		return NO;

	CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, nil);
	CFRelease(source);
	if (image == NULL)
		return NO;

	CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image);
	CGImageRelease(image);

	return alpha != kCGImageAlphaNone &&
		alpha != kCGImageAlphaNoneSkipLast &&
		alpha != kCGImageAlphaNoneSkipFirst;
}

+(NSString*) getExif:(NSString*)path {
	NSURL* url = [NSURL fileURLWithPath:path];
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nil);
	if (source == nil)
		return @"";

	NSDictionary* properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, nil));
	CFRelease(source);
	if (properties == nil)
		return @"";

	NSDictionary* exif = properties[(__bridge NSString*)kCGImagePropertyExifDictionary];
	NSDictionary* tiff = properties[(__bridge NSString*)kCGImagePropertyTIFFDictionary];
	NSDictionary* gps = properties[(__bridge NSString*)kCGImagePropertyGPSDictionary];

	NSMutableString* result = [NSMutableString string];

	id value = exif[@"DateTimeOriginal"];
	if (value == nil) value = exif[@"DateTimeDigitized"];
	if (value != nil) [result appendFormat:@"dateTime\t%@\n", value];

	value = tiff[@"Make"];
	if (value != nil) [result appendFormat:@"make\t%@\n", value];

	value = tiff[@"Model"];
	if (value != nil) [result appendFormat:@"model\t%@\n", value];

	value = exif[@"ISOSpeedRatings"];
	if ([value isKindOfClass:[NSArray class]])
		value = [value firstObject];
	if (value != nil) [result appendFormat:@"iso\t%@\n", value];

	value = exif[@"FNumber"];
	if (value != nil) [result appendFormat:@"fNumber\t%@\n", value];

	value = exif[@"ExposureTime"];
	if (value != nil) [result appendFormat:@"exposureTime\t%@\n", value];

	value = exif[@"FocalLength"];
	if (value != nil) [result appendFormat:@"focalLength\t%@\n", value];

	value = exif[@"Flash"];
	if (value != nil) [result appendFormat:@"flash\t%@\n", value];

	value = gps[@"Latitude"];
	if (value != nil) [result appendFormat:@"gpsLatitude\t%@\n", value];

	value = gps[@"Longitude"];
	if (value != nil) [result appendFormat:@"gpsLongitude\t%@\n", value];

	value = gps[@"Altitude"];
	if (value != nil) [result appendFormat:@"gpsAltitude\t%@\n", value];

	return result;
}

+(void) clearCache {
	NSString* directory = [self createImagePath:YES];
	NSFileManager* manager = [NSFileManager defaultManager];
	NSArray* files = [manager contentsOfDirectoryAtPath:directory error:nil];

	for (NSString* file in files)
		if ([file hasPrefix:@"IMG_"])
			[manager removeItemAtPath:[directory stringByAppendingPathComponent:file] error:nil];
}

+(NSString*) normalizedFormat:(NSString*)format path:(NSString*)path {
	if (format == nil || [format length] == 0) {
		NSString* extension = [[path pathExtension] lowercaseString];
		if ([extension isEqualToString:@"jpeg"])
			return @"jpg";
		if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"png"] || [extension isEqualToString:@"webp"])
			return extension;
		return @"jpg";
	}

	format = [format lowercaseString];
	if ([format isEqualToString:@"jpeg"])
		return @"jpg";
	return format;
}

+(NSString*) targetPathForImage:(NSString*)path format:(NSString*)format inPlace:(BOOL)inPlace {
	BOOL hasFormat = format != nil && [format length] > 0;
	if (inPlace && !hasFormat)
		return path;

	NSString* targetFormat = [self normalizedFormat:format path:path];
	NSString* extension = [[path pathExtension] lowercaseString];
	BOOL match = [targetFormat isEqualToString:@"jpg"]
		? ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"])
		: [extension isEqualToString:targetFormat];

	if (inPlace && match)
		return path;

	return [self createImagePathWithExtension:targetFormat temp:YES];
}

+(UIImage*) renderImage:(UIImage*)image size:(CGSize)size {
	UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
	[image drawInRect:CGRectMake(0, 0, size.width, size.height)];
	UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}

+(BOOL) saveImage:(UIImage*)image path:(NSString*)path quality:(int)quality {
	NSString* extension = [[path pathExtension] lowercaseString];

	NSData* imageData;
	if ([extension isEqualToString:@"png"]) {
		imageData = UIImagePNGRepresentation(image);
	} else if ([extension isEqualToString:@"webp"]) {
		return NO;
	} else {
		float q = MAX(0.0f, MIN(1.0f, quality / 100.0f));
		imageData = UIImageJPEGRepresentation(image, q);
	}

	return imageData != nil && [imageData writeToFile:path atomically:NO];
}

+(NSString*)imageFromDataSync:(NSData*)data {
	@try {
		NSString* extension = [self contentTypeForImageData:data];
		if(extension==nil)
			[NSException raise:@"InvalidImageFormat" format:@"Invalid image format"];

		UIImage* newImage = [UIImage imageWithData:data];
		if (newImage == nil)
			[NSException raise:@"InvalidImageData" format:@"Could not decode image"];

		NSString* path = [self createImagePathWithExtension:extension temp:YES];
		[data writeToFile:path atomically:NO];
		return path;
	}
	@catch (NSException* e) {
		return nil;
	}
}

+(void)imageFromData:(NSData*)data onComplete:(StringAction)onComplete onFail:(StringAction)onFail
{
	@try {
		NSString* extension = [self contentTypeForImageData:data];
		if(extension==nil)
			[NSException raise:@"InvalidImageFormat" format:@"Invalid image format"];

		UIImage* newImage = [UIImage imageWithData:data];
		if (newImage == nil)
			[NSException raise:@"InvalidImageData" format:@"Could not decode image"];

		NSString* path = [self createImagePathWithExtension:extension temp:YES];
		[data writeToFile:path atomically:NO];
		onComplete(path);
	}
	@catch (NSException* e) {
		onFail([NSString stringWithFormat:@"Image load error: %@", e]);
	}
}

+(void)saveImage:(UIImage*)image path:(NSString*)path
{
	[self saveImage:image path:path quality:90];
}

+(NSArray*) getImageSize:(NSString*)path {
	CGFloat width = 0.0f, height = 0.0f;
	NSURL *imageFileURL = [NSURL fileURLWithPath:path];
	CFURLRef url = (__bridge CFURLRef) imageFileURL;
	CGImageSourceRef imageSource = CGImageSourceCreateWithURL(url, nil);
	if (imageSource == nil) {
		return @[ @( 0 ), @( 0 )];
	}

	CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);

	CFRelease(imageSource);

	if (imageProperties != nil) {

		CFNumberRef widthNum  = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
		if (widthNum != nil) {
			CFNumberGetValue(widthNum, kCFNumberCGFloatType, &width);
		}

		CFNumberRef heightNum = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
		if (heightNum != nil) {
			CFNumberGetValue(heightNum, kCFNumberCGFloatType, &height);
		}

		int orientation = 1;
		CFNumberRef orientationNum = CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation);
		if (orientationNum != nil) {
			CFNumberGetValue(orientationNum, kCFNumberIntType, &orientation);
		}

		CFRelease(imageProperties);

		if (orientation >= 5 && orientation <= 8) {
			CGFloat tmp = width;
			width = height;
			height = tmp;
		}
	}

	return @[ @( (int)width ), @( (int)height )]; //Weird spacing here to avoid uxl expansion issues
}

+(UIImage*) correctImageOrientation:(UIImage*)image {
	if (image.imageOrientation == UIImageOrientationUp) return image;
	CGAffineTransform transform = CGAffineTransformIdentity;

	switch (image.imageOrientation) {
		case UIImageOrientationDown:
		case UIImageOrientationDownMirrored:
			transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
			transform = CGAffineTransformRotate(transform, (CGFloat) M_PI);
			break;

		case UIImageOrientationLeft:
		case UIImageOrientationLeftMirrored:
			transform = CGAffineTransformTranslate(transform, image.size.width, 0);
			transform = CGAffineTransformRotate(transform, (CGFloat) M_PI_2);
			break;

		case UIImageOrientationRight:
		case UIImageOrientationRightMirrored:
			transform = CGAffineTransformTranslate(transform, 0, image.size.height);
			transform = CGAffineTransformRotate(transform, (CGFloat) -M_PI_2);
			break;
		case UIImageOrientationUp:
		case UIImageOrientationUpMirrored:
			break;
	}

	switch (image.imageOrientation) {
		case UIImageOrientationUpMirrored:
		case UIImageOrientationDownMirrored:
			transform = CGAffineTransformTranslate(transform, image.size.width, 0);
			transform = CGAffineTransformScale(transform, -1, 1);
			break;

		case UIImageOrientationLeftMirrored:
		case UIImageOrientationRightMirrored:
			transform = CGAffineTransformTranslate(transform, image.size.height, 0);
			transform = CGAffineTransformScale(transform, -1, 1);
			break;
		case UIImageOrientationUp:
		case UIImageOrientationDown:
		case UIImageOrientationLeft:
		case UIImageOrientationRight:
			break;
	}

	CGContextRef ctx = CGBitmapContextCreate(nil, (size_t) image.size.width, (size_t) image.size.height,
			CGImageGetBitsPerComponent(image.CGImage), 0,
			CGImageGetColorSpace(image.CGImage),
			CGImageGetBitmapInfo(image.CGImage));
	CGContextConcatCTM(ctx, transform);
	switch (image.imageOrientation) {
		case UIImageOrientationLeft:
		case UIImageOrientationLeftMirrored:
		case UIImageOrientationRight:
		case UIImageOrientationRightMirrored:
			// Grr...
			CGContextDrawImage(ctx, CGRectMake(0,0,image.size.height,image.size.width), image.CGImage);
			break;

		default:
			CGContextDrawImage(ctx, CGRectMake(0,0,image.size.width,image.size.height), image.CGImage);
			break;
	}

	CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
	UIImage *img = [UIImage imageWithCGImage:cgimg];
	CGContextRelease(ctx);
	CGImageRelease(cgimg);
	return img;
}


+(NSData*) rgbaDataFromImageAtPath:(NSString*)path
{
	UIImage* original = [UIImage imageWithContentsOfFile:path];
	if (original == nil)
		return nil;

	UIImage* image = [self correctImageOrientation:original];
	CGImageRef cgImage = image.CGImage;
	if (cgImage == NULL)
		return nil;

	size_t width = CGImageGetWidth(cgImage);
	size_t height = CGImageGetHeight(cgImage);

	if (height > 0 && width > NSUIntegerMax / 4 / height)
		return nil;

	NSMutableData* data = [NSMutableData dataWithLength:width * height * 4];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(
		data.mutableBytes, width, height, 8, width * 4, colorSpace,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

	if (context == NULL) {
		CGColorSpaceRelease(colorSpace);
		return nil;
	}

	// Store rows top-down so the buffer matches Android and .NET.
	CGContextTranslateCTM(context, 0, height);
	CGContextScaleCTM(context, 1, -1);
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

	CGContextRelease(context);
	CGColorSpaceRelease(colorSpace);

	// Convert premultiplied alpha to straight RGBA so the buffer matches Android and .NET.
	uint8_t* pixels = (uint8_t*)data.mutableBytes;
	size_t count = width * height;

	for (size_t i = 0; i < count; i++) {
		uint8_t alpha = pixels[i * 4 + 3];
		if (alpha > 0 && alpha < 255) {
			pixels[i * 4 + 0] = (uint8_t)MIN(255, (pixels[i * 4 + 0] * 255) / alpha);
			pixels[i * 4 + 1] = (uint8_t)MIN(255, (pixels[i * 4 + 1] * 255) / alpha);
			pixels[i * 4 + 2] = (uint8_t)MIN(255, (pixels[i * 4 + 2] * 255) / alpha);
		}
	}

	return data;
}

+(NSString*) localPathFromUri:(NSString*)uri
{
	if (uri == nil || [uri length] == 0)
		return nil;

	if ([uri hasPrefix:@"file:"]) {
		NSURL* url = [NSURL URLWithString:uri];
		return [url path];
	}

	if ([uri hasPrefix:@"/"])
		return uri;

	return nil;
}

+(void) imageFromBase64String:(NSString*)b64
		onComplete:(StringAction)a
		onFail:(StringAction)b
{
	@try {
		NSString* payload = b64;
		if ([payload hasPrefix:@"data:"]) {
			NSRange comma = [payload rangeOfString:@","];
			if (comma.location != NSNotFound)
				payload = [payload substringFromIndex:comma.location + 1];
		}

		NSData* data = [[NSData alloc] initWithBase64EncodedString:payload options:NSDataBase64DecodingIgnoreUnknownCharacters];
		if (data == nil) {
			b(@"Could not decode image");
			return;
		}

		[self imageFromData:data onComplete:a onFail:b];
	} @catch(NSException* e) {
		b(@"Could not decode image");
	}
}

+(void) base64FromImageAtPath:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)a
		onFail:(StringAction)b
{
	UIImage* image = [UIImage imageWithContentsOfFile:path];
	if (image == nil) {
		b(@"Could not load image");
		return;
	}

	@try {
		NSString* targetFormat = [self normalizedFormat:format path:path];

		NSData* data;
		if ([targetFormat isEqualToString:@"png"]) {
			data = UIImagePNGRepresentation(image);
		} else if ([targetFormat isEqualToString:@"webp"]) {
			b(@"WebP encoding is not supported on iOS");
			return;
		} else {
			float q = MAX(0.0f, MIN(1.0f, quality / 100.0f));
			data = UIImageJPEGRepresentation(image, q);
		}

		if (data == nil) {
			b(@"Could not encode image");
			return;
		}

		a([data base64EncodedStringWithOptions:0]);
	}@catch(NSException* e){
		b(@"Could not encode image");
	}
}

+(void) base64FromImageAtPath:(NSString*)path
		onComplete:(StringAction)a
		onFail:(StringAction)b
{
	[self base64FromImageAtPath:path quality:90 format:nil onComplete:a onFail:b];
}

+(NSString*) createImagePath:(BOOL)temp
{
	NSString* p = [NSString stringWithFormat:@"%@images", temp?[self applicationTempDirectory]:[self applicationDocumentsDirectory]];
	NSError * error = nil;
	[[NSFileManager defaultManager] createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:&error];
	if (error != nil) {
		NSLog(@"error creating directory: %@", error);
	}
	return p;
}

+(NSString*) createImagePathWithExtension:(NSString*)extension
		temp:(BOOL)temp
{
	NSString *uuid = [[NSUUID UUID] UUIDString];
	return [NSString stringWithFormat:@"%@/IMG_%@.%@", [self createImagePath:temp], uuid, extension];
}

+(NSString*) localPathFromPHImageFileURL:(NSURL*)url
		temp:(BOOL)temp
{
	NSString* name = [[url path] lastPathComponent];
	NSString* uuid = [[NSUUID UUID] UUIDString];
	return [NSString stringWithFormat:@"%@/%@%@", [self createImagePath:temp], uuid, name];
}

+(NSString*) applicationDocumentsDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *basePath = paths.firstObject;
	return basePath;
}

+(NSString*) applicationTempDirectory {
	return NSTemporaryDirectory();
}
@end
#pragma clang diagnostic pop
