#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

NS_ASSUME_NONNULL_BEGIN

@interface FOMediaPickerPhotoAssetUtil : NSObject

+ (nullable PHAsset *)getAssetFromImagePickerInfo:(NSDictionary *)info;

+ (nullable PHAsset *)getAssetFromPHPickerResult:(PHPickerResult *)result API_AVAILABLE(ios(14));

// Re-encodes the image to a baseline JPEG/PNG so Fuse's texture loader can
// display it. Pass nil originalImageData when no original asset is available.
+ (nullable NSString *)saveImageWithOriginalImageData:(nullable NSData *)originalImageData
                                                image:(nullable UIImage *)image
                                         imageQuality:(nullable NSNumber *)imageQuality;

@end

NS_ASSUME_NONNULL_END
