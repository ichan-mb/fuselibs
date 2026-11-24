#import "ImageHelper.h"

@interface ImageHelper ()
+(NSString*) createImagePath:(BOOL)temp;
+(NSString*) normalizedFormat:(NSString*)format path:(NSString*)path;
+(NSString*) targetPathForImage:(NSString*)path format:(NSString*)format inPlace:(BOOL)inPlace;
+(BOOL) saveImage:(UIImage*)image path:(NSString*)path quality:(int)quality;
+(UIImage*) renderImage:(UIImage*)image size:(CGSize)size;
@end
