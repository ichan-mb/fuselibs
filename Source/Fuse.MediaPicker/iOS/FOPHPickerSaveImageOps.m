#import "FOPHPickerSaveImageOps.h"

API_AVAILABLE(ios(14))
@interface FOPHPickerSaveImageOps ()

@property(strong, nonatomic) PHPickerResult *result;
@property(strong, nonatomic) NSNumber *maxHeight;
@property(strong, nonatomic) NSNumber *maxWidth;
@property(strong, nonatomic) NSNumber *desiredImageQuality;

@end

typedef void (^GetSavedPath)(NSString *);

@implementation FOPHPickerSaveImageOps {
	BOOL executing;
	BOOL finished;
	GetSavedPath getSavedPath;
}

- (instancetype)initWithResult:(PHPickerResult *)result
												 maxHeight:(NSNumber *)maxHeight
													maxWidth:(NSNumber *)maxWidth
										 desiredImageQuality:(NSNumber *)desiredImageQuality
												savedPathBlock:(GetSavedPath)savedPathBlock API_AVAILABLE(ios(14)) {
	if (!result) {
		return nil;
	}
	if (self = [super init]) {
		self.result = result;
		self.maxHeight = maxHeight;
		self.maxWidth = maxWidth;
		self.desiredImageQuality = desiredImageQuality;
		getSavedPath = savedPathBlock;
	}
	return self;
}

- (BOOL)isConcurrent {
	return YES;
}

- (BOOL)isExecuting {
	return executing;
}

- (BOOL)isFinished {
	return finished;
}

- (void)setFinished:(BOOL)isFinished {
	[self willChangeValueForKey:@"isFinished"];
	finished = isFinished;
	[self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)isExecuting {
	[self willChangeValueForKey:@"isExecuting"];
	executing = isExecuting;
	[self didChangeValueForKey:@"isExecuting"];
}

- (void)completeOperationWithPath:(NSString *)savedPath {
	if (finished) {
		return;
	}

	// Deliver the result before marking the operation finished, so callers
	// waiting on the operation queue always see a populated path list.
	if (getSavedPath) {
		getSavedPath(savedPath);
	}

	[self setExecuting:NO];
	[self setFinished:YES];
}

- (void)start {
	if ([self isCancelled]) {
		[self setFinished:YES];
		return;
	}

	if (@available(iOS 14, *)) {
		[self setExecuting:YES];
		[self.result.itemProvider
				loadObjectOfClass:[UIImage class]
				completionHandler:^(__kindof id<NSItemProviderReading> _Nullable image,
														NSError *_Nullable error) {
					if (![image isKindOfClass:[UIImage class]]) {
						// Make sure the operation always finishes, otherwise the
						// queue waiting for it would block forever.
						[self completeOperationWithPath:nil];
						return;
					}

					__block UIImage *localImage = (UIImage *)image;
					PHAsset *originalAsset =
							[FOMediaPickerPhotoAssetUtil getAssetFromPHPickerResult:self.result];

					// UIKit image scaling/encoding is not thread-safe. Doing it on a
					// background queue can produce a valid but blank white image.
					dispatch_async(dispatch_get_main_queue(), ^{
						BOOL hasMaxWidth = [self.maxWidth isKindOfClass:[NSNumber class]] && [self.maxWidth doubleValue] > 0;
						BOOL hasMaxHeight = [self.maxHeight isKindOfClass:[NSNumber class]] && [self.maxHeight doubleValue] > 0;
						if (hasMaxWidth || hasMaxHeight) {
							localImage = [FOMediaPickerImageUtil scaledImage:localImage maxWidth:self.maxWidth maxHeight:self.maxHeight isMetadataAvailable:originalAsset != nil];
						}

						if (!originalAsset) {
							// Image picked without an original asset (e.g. User pick image without permission)
							NSString *savedPath =
									[FOMediaPickerPhotoAssetUtil saveImageWithOriginalImageData:nil image:localImage imageQuality:self.desiredImageQuality];
							[self completeOperationWithPath:savedPath];
						} else {
							PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
							options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
							options.resizeMode = PHImageRequestOptionsResizeModeNone;
							options.networkAccessAllowed = YES;

							[[PHImageManager defaultManager]
									requestImageDataForAsset:originalAsset options:options
										resultHandler:^(
											NSData *_Nullable imageData, NSString *_Nullable dataUTI,
											UIImageOrientation orientation, NSDictionary *_Nullable info) {
												dispatch_async(dispatch_get_main_queue(), ^{
													NSString *savedPath = [FOMediaPickerPhotoAssetUtil saveImageWithOriginalImageData:imageData image:localImage imageQuality:self.desiredImageQuality];
													[self completeOperationWithPath:savedPath];
												});
											}];
						}
					});
				}];
	} else {
		[self setFinished:YES];
	}
}

@end
