#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
	FOImagePickerMIMETypePNG,
	FOImagePickerMIMETypeJPEG,
	FOImagePickerMIMETypeGIF,
	FOImagePickerMIMETypeOther,
} FOImagePickerMIMEType;

extern NSString *const kFOImagePickerDefaultSuffix;
extern const FOImagePickerMIMEType kFOImagePickerMIMETypeDefault;

@interface FOMediaPickerMetaDataUtil : NSObject

+ (FOImagePickerMIMEType)getImageMIMETypeFromImageData:(NSData *)imageData;

// Converts the image to the requested type; quality applies to JPEG only.
+ (nullable NSData *)convertImage:(nonnull UIImage *)image
									usingType:(FOImagePickerMIMEType)type
									quality:(nullable NSNumber *)quality;

// Redraws the image upright as standard RGBA, avoiding HDR/wide-gamut formats.
+ (nullable UIImage *)normalizedImage:(nullable UIImage *)image;

@end

NS_ASSUME_NONNULL_END
