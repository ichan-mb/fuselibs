#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "Actions.h"

@interface ImageHelper : NSObject
+(NSArray*)getImageSize:(NSString*)path;
+(NSString*) applicationDocumentsDirectory;
+(NSString*) applicationTempDirectory;
+(UIImage*) correctImageOrientation:(UIImage*)image;
+(UIImage*) imageFromDictionary:(NSDictionary*)dictionary;

+(NSString*) getMimeType:(NSString*)path;
+(long long) getFileSize:(NSString*)path;
+(int) getOrientation:(NSString*)path;
+(int) getFrameCount:(NSString*)path;
+(BOOL) hasAlpha:(NSString*)path;
+(NSString*) getExif:(NSString*)path;
+(void) clearCache;

+(void)imageFromData:(NSData*)data
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail;

+(NSString*)imageFromDataSync:(NSData*)data;

+(void)resizeImage:(NSString*)path
		width:(float)desiredWidth
		height:(float)desiredHeight
		mode:(int)mode
		quality:(int)quality
		format:(NSString*)format
		background:(int)background
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)cropImage:(NSString*)path
		desiredRect:(CGRect)rect
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)rotateImage:(NSString*)path
		degrees:(double)degrees
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)flipImage:(NSString*)path
		horizontal:(BOOL)horizontal
		vertical:(BOOL)vertical
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)autoOrientImage:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)thumbnailImage:(NSString*)path
		maxWidth:(int)maxWidth
		maxHeight:(int)maxHeight
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail;

+(void)convertImage:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)saveImageAtPath:(NSString*)path
		directory:(NSString*)directory
		name:(NSString*)name
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail;

+(void)compositeImage:(NSString*)path
		overlay:(NSString*)overlayPath
		x:(int)x
		y:(int)y
		opacity:(float)opacity
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

+(void)filterImage:(NSString*)path
		type:(NSString*)type
		amount:(float)amount
		radius:(int)radius
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)onComplete
		onFail:(StringAction)onFail
		performInPlace:(BOOL)inPlace;

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
		performInPlace:(BOOL)inPlace;

+(NSData*) rgbaDataFromImageAtPath:(NSString*)path;
+(NSString*) localPathFromUri:(NSString*)uri;

+(void)saveImage:(UIImage*)image
		path:(NSString*)path;

+(void) imageFromBase64String:(NSString*)b64
		onComplete:(StringAction)a
		onFail:(StringAction)b;

+(void) base64FromImageAtPath:(NSString*)path
		quality:(int)quality
		format:(NSString*)format
		onComplete:(StringAction)a
		onFail:(StringAction)b;

+(void) base64FromImageAtPath:(NSString*)path
		onComplete:(StringAction)a
		onFail:(StringAction)b;

+(NSString*) createImagePathWithExtension:(NSString*)extension
		temp:(BOOL)temp;

+(NSString*) localPathFromPHImageFileURL:(NSURL*)url
		temp:(BOOL)temp;
@end
