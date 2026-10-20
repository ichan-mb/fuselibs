#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FOMediaPickerImageUtil : NSObject

+ (nullable UIImage *)scaledImage:(UIImage *)image
                       maxWidth:(nullable NSNumber *)maxWidth
                      maxHeight:(nullable NSNumber *)maxHeight
            isMetadataAvailable:(BOOL)isMetadataAvailable;

@end

NS_ASSUME_NONNULL_END
