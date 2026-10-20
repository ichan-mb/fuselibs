#import "FOMediaPicker.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import <UIKit/UIKit.h>

#import "FOMediaPickerImageUtil.h"
#import "FOMediaPickerPhotoAssetUtil.h"
#import "FOPHPickerSaveImageOps.h"
#import "Uno-iOS/AppDelegate.h"


@interface FOMediaPicker () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate>

@property(copy, nonatomic) StringAction result;

@property(copy, nonatomic) StringAction error;

@property(copy, nonatomic) NSDictionary *arguments;

@property(strong, nonatomic) PHPickerViewController *pickerViewController API_AVAILABLE(ios(14));

// Set when the PHPicker/UIImagePicker is used to select videos.
@property(assign, nonatomic) BOOL pickingVideos;

// Set when the caller expects an array of video paths (pickVideos).
@property(assign, nonatomic) BOOL returningVideoList;

@end

static const int SOURCE_CAMERA = 0;
static const int SOURCE_GALLERY = 1;


@implementation FOMediaPicker
{
	UIImagePickerController *_imagePickerController;
}

static FOMediaPicker* _instance;

+(FOMediaPicker*) instance
{
	if(_instance == nil) _instance = [[FOMediaPicker alloc] init];
	return _instance;
}

- (void)clearState
{
	self.result = nil;
	self.error = nil;
	self.arguments = nil;
}

- (void)finishWithError:(NSString *)message
{
	StringAction error = self.error;
	[self clearState];
	if (error != nil) {
		error(message);
	}
}

- (UIImagePickerControllerCameraDevice)getCameraDeviceFromArguments:(NSDictionary *)arguments
{
	NSInteger cameraDevice = [[arguments objectForKey:@"cameraDevice"] intValue];
	return (cameraDevice == 1) ? UIImagePickerControllerCameraDeviceFront : UIImagePickerControllerCameraDeviceRear;
}

#pragma mark - PHPicker

- (void)pickImagesWithPHPicker:(int)maxImages API_AVAILABLE(ios(14))
{
	self.pickingVideos = NO;

	// PHPicker does not require photo library authorization, so it is presented
	// directly without asking the user for full library access.
	PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
	config.selectionLimit = (maxImages > 0) ? maxImages : 0; // 0 means unlimited
	config.filter = [PHPickerFilter imagesFilter];

	[self presentPHPicker:config];
}

- (void)pickVideosWithPHPicker:(int)maxVideos API_AVAILABLE(ios(14))
{
	self.pickingVideos = YES;

	PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
	config.selectionLimit = (maxVideos > 0) ? maxVideos : 0; // 0 means unlimited
	config.filter = [PHPickerFilter videosFilter];

	[self presentPHPicker:config];
}

- (void)presentPHPicker:(PHPickerConfiguration *)config API_AVAILABLE(ios(14))
{
	_pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
	_pickerViewController.delegate = self;
	_pickerViewController.presentationController.delegate = self;

	dispatch_async(dispatch_get_main_queue(), ^{
		[(uAppDelegate*)[[UIApplication sharedApplication] delegate]
				presentViewController:self->_pickerViewController animated:YES completion:^{
					self->_pickerViewController.presentationController.delegate = self;
				}];
	});
}

#pragma mark - UIImagePicker

- (void)pickImageWithUIImagePicker
{
	self.pickingVideos = NO;

	_imagePickerController = [[UIImagePickerController alloc] init];
	_imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
	_imagePickerController.delegate = self;
	_imagePickerController.mediaTypes = @[ (NSString *)kUTTypeImage ];

	int imageSource = [[self.arguments objectForKey:@"source"] intValue];

	switch (imageSource) {
		case SOURCE_CAMERA:
			[self checkCameraAuthorization];
			break;
		case SOURCE_GALLERY:
			[self checkPhotoAuthorization];
			break;
		default:
			[self finishWithError:[NSString stringWithFormat:@"Invalid image source: %d", imageSource]];
			break;
	}
}

- (void)pickVideoWithUIImagePicker
{
	self.pickingVideos = YES;

	_imagePickerController = [[UIImagePickerController alloc] init];
	_imagePickerController.modalPresentationStyle = UIModalPresentationCurrentContext;
	_imagePickerController.delegate = self;
	_imagePickerController.mediaTypes = @[
		(NSString *)kUTTypeMovie, (NSString *)kUTTypeAVIMovie, (NSString *)kUTTypeVideo,
		(NSString *)kUTTypeMPEG4
	];
	_imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;

	int imageSource = [[self.arguments objectForKey:@"source"] intValue];
	if ([[self.arguments objectForKey:@"maxDuration"] isKindOfClass:[NSNumber class]]) {
		NSTimeInterval max = [[self.arguments objectForKey:@"maxDuration"] doubleValue];
		if (max > 0.0) {
			_imagePickerController.videoMaximumDuration = max;
		}
	}

	switch (imageSource) {
		case SOURCE_CAMERA:
			[self checkCameraAuthorization];
			break;
		case SOURCE_GALLERY:
			[self checkPhotoAuthorization];
			break;
		default:
			[self finishWithError:[NSString stringWithFormat:@"Invalid video source: %d", imageSource]];
			break;
	}
}

#pragma mark - Public API

- (void)pickSingleImageWithArgs:(NSDictionary *)argument withResult:(StringAction)result error:(StringAction)error
{
	self.arguments = argument;
	self.result = result;
	self.error = error;

	int imageSource = [[self.arguments objectForKey:@"source"] intValue];
	if (imageSource == SOURCE_GALLERY) { // Capture is not possible with PHPicker
		if (@available(iOS 14, *)) {
			[self pickImagesWithPHPicker:1];
		} else {
			[self pickImageWithUIImagePicker];
		}
	} else {
		[self pickImageWithUIImagePicker];
	}
}

- (void)pickMultiImageWithArgs:(NSDictionary *)argument withResult:(StringAction)result error:(StringAction)error
{
	self.result = result;
	self.error = error;
	self.arguments = argument;

	if (@available(iOS 14, *)) {
		int maxImages = [[self.arguments objectForKey:@"maxImages"] intValue];
		[self pickImagesWithPHPicker:maxImages];
	} else {
		[self pickImageWithUIImagePicker];
	}
}

- (void)pickVideoWithArgs:(NSDictionary *)argument withResult:(StringAction)result error:(StringAction)error
{
	self.result = result;
	self.error = error;
	self.arguments = argument;
	self.returningVideoList = NO;

	int imageSource = [[self.arguments objectForKey:@"source"] intValue];
	if (imageSource == SOURCE_GALLERY) {
		if (@available(iOS 14, *)) {
			[self pickVideosWithPHPicker:1];
			return;
		}
	}

	[self pickVideoWithUIImagePicker];
}

- (void)pickVideosWithArgs:(NSDictionary *)argument withResult:(StringAction)result error:(StringAction)error
{
	self.result = result;
	self.error = error;

	// Multiple video recording is not supported, so this always uses the gallery.
	NSMutableDictionary *galleryArguments = [argument mutableCopy] ?: [NSMutableDictionary dictionary];
	galleryArguments[@"source"] = [NSNumber numberWithInt:SOURCE_GALLERY];
	self.arguments = galleryArguments;
	self.returningVideoList = YES;

	if (@available(iOS 14, *)) {
		int maxVideos = [[self.arguments objectForKey:@"maxVideos"] intValue];
		[self pickVideosWithPHPicker:maxVideos];
	} else {
		// Older versions can only select a single video, which is returned as a list.
		[self pickVideoWithUIImagePicker];
	}
}

#pragma mark - Authorization

- (void)showCamera
{
	@synchronized(self) {
		if (_imagePickerController.beingPresented) {
			return;
		}
	}
	UIImagePickerControllerCameraDevice device = [self getCameraDeviceFromArguments:self.arguments];
	// Camera is not available on simulators
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] &&
			[UIImagePickerController isCameraDeviceAvailable:device]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self->_imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
			self->_imagePickerController.cameraDevice = device;
			[(uAppDelegate*)[[UIApplication sharedApplication] delegate] presentViewController:self->_imagePickerController animated:YES completion:nil];
		});
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIAlertController *cameraErrorAlert = [UIAlertController
				alertControllerWithTitle:@"Camera Unavailable" message:@"Camera not available."
									preferredStyle:UIAlertControllerStyleAlert];
			[cameraErrorAlert
				addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){}]];
			[(uAppDelegate*)[[UIApplication sharedApplication] delegate]
					presentViewController:cameraErrorAlert animated:YES completion:nil];
		});
		[self finishWithError:@"Camera not available."];
	}
}

- (void)checkCameraAuthorization
{
	AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

	switch (status) {
		case AVAuthorizationStatusAuthorized:
			[self showCamera];
			break;
		case AVAuthorizationStatusNotDetermined: {
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
																completionHandler:^(BOOL granted) {
																	dispatch_async(dispatch_get_main_queue(), ^{
																		if (granted) {
																			[self showCamera];
																		} else {
																			[self errorNoCameraAccess:AVAuthorizationStatusDenied];
																		}
																	});
																}];
			break;
		}
		case AVAuthorizationStatusDenied:
		case AVAuthorizationStatusRestricted:
		default:
			[self errorNoCameraAccess:status];
			break;
	}
}

- (void)checkPhotoAuthorization
{
	PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
	switch (status) {
		case PHAuthorizationStatusNotDetermined: {
			[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited) {
						[self showPhotoLibrary];
					} else {
						[self errorNoPhotoAccess:status];
					}
				});
			}];
			break;
		}
		case PHAuthorizationStatusAuthorized:
		case PHAuthorizationStatusLimited:
			[self showPhotoLibrary];
			break;
		case PHAuthorizationStatusDenied:
		case PHAuthorizationStatusRestricted:
		default:
			[self errorNoPhotoAccess:status];
			break;
	}
}

- (void)errorNoCameraAccess:(AVAuthorizationStatus)status
{
	switch (status) {
		case AVAuthorizationStatusRestricted:
			[self finishWithError:@"The user is not allowed to use the camera."];
			break;
		case AVAuthorizationStatusDenied:
		default:
			[self finishWithError:@"The user did not allow camera access."];
			break;
	}
}

- (void)errorNoPhotoAccess:(PHAuthorizationStatus)status
{
	switch (status) {
		case PHAuthorizationStatusRestricted:
			[self finishWithError:@"The user is not allowed to use the photo library."];
			break;
		case PHAuthorizationStatusDenied:
		default:
			[self finishWithError:@"The user did not allow photo access."];
			break;
	}
}

- (void)showPhotoLibrary
{
	_imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	dispatch_async(dispatch_get_main_queue(), ^{
		[(uAppDelegate*)[[UIApplication sharedApplication] delegate]
				presentViewController:self->_imagePickerController animated:YES completion:nil];
	});
}

#pragma mark - Image quality

- (NSNumber *)getDesiredImageQuality:(NSNumber *)imageQuality
{
	if (![imageQuality isKindOfClass:[NSNumber class]]) {
		return @1;
	}

	int quality = [imageQuality intValue];
	if (quality <= 0 || quality > 100) {
		return @1;
	}

	return [NSNumber numberWithFloat:[imageQuality floatValue] / 100.0f];
}

#pragma mark - PHPicker delegate

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
	if (self.result != nil) {
		[self finishWithError:@"User cancelled picking media."];
	}
}

- (void)picker:(PHPickerViewController *)picker
		didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14))
{
	[picker dismissViewControllerAnimated:YES completion:nil];
	if (self.result == nil) {
		return;
	}
	if (results.count == 0) {
		[self finishWithError:@"User cancelled picking media."];
		return;
	}

	if (self.pickingVideos) {
		[self loadVideosFromResults:results];
	} else {
		[self loadImagesFromResults:results];
	}
}

- (void)loadImagesFromResults:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14))
{
	NSDictionary *arguments = self.arguments;
	NSNumber *maxWidth = [arguments objectForKey:@"maxWidth"];
	NSNumber *maxHeight = [arguments objectForKey:@"maxHeight"];
	NSNumber *imageQuality = [arguments objectForKey:@"imageQuality"];
	NSNumber *desiredImageQuality = [self getDesiredImageQuality:imageQuality];

	NSMutableArray *pathList = [self createNSMutableArrayWithSize:results.count];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		NSOperationQueue *operationQueue = [NSOperationQueue new];
		for (NSUInteger i = 0; i < results.count; i++) {
			PHPickerResult *result = results[i];
			FOPHPickerSaveImageOps *operation =
					[[FOPHPickerSaveImageOps alloc] initWithResult:result
																			maxHeight:maxHeight
																			 maxWidth:maxWidth
																 desiredImageQuality:desiredImageQuality
																	  savedPathBlock:^(NSString *savedPath) {
																		  @synchronized (pathList) {
																			  pathList[i] = savedPath ?: [NSNull null];
																		  }
																	  }];
			if (operation != nil) {
				[operationQueue addOperation:operation];
			} else {
				@synchronized (pathList) {
					pathList[i] = [NSNull null];
				}
			}
		}

		[operationQueue waitUntilAllOperationsAreFinished];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self handleSavedImagePaths:pathList];
		});
	});
}

- (void)loadVideosFromResults:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14))
{
	NSMutableArray *pathList = [self createNSMutableArrayWithSize:results.count];
	dispatch_group_t group = dispatch_group_create();
	NSString *typeIdentifier = (NSString *)kUTTypeMovie;

	for (NSUInteger i = 0; i < results.count; i++) {
		PHPickerResult *result = results[i];
		NSItemProvider *provider = result.itemProvider;

		if (![provider hasItemConformingToTypeIdentifier:typeIdentifier]) {
			@synchronized (pathList) {
				pathList[i] = [NSNull null];
			}
			continue;
		}

		dispatch_group_enter(group);
		[provider loadFileRepresentationForTypeIdentifier:typeIdentifier
				completionHandler:^(NSURL *url, NSError *error) {
					NSString *savedPath = nil;
					if (url != nil && error == nil) {
						NSString *extension = (url.pathExtension.length > 0) ? url.pathExtension : @"mp4";
						NSString *filename =
								[[[NSProcessInfo processInfo] globallyUniqueString] stringByAppendingPathExtension:extension];
						NSString *destinationPath =
								[NSTemporaryDirectory() stringByAppendingPathComponent:filename];
						NSError *copyError = nil;
						if ([[NSFileManager defaultManager] copyItemAtURL:url
																												toURL:[NSURL fileURLWithPath:destinationPath]
																											 error:&copyError]) {
							savedPath = destinationPath;
						}
					}

					@synchronized (pathList) {
						pathList[i] = savedPath ?: [NSNull null];
					}
					dispatch_group_leave(group);
				}];
	}

	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		[self handleSavedVideoPaths:pathList];
	});
}

- (NSMutableArray *)createNSMutableArrayWithSize:(NSUInteger)size
{
	NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithCapacity:size];
	for (NSUInteger i = 0; i < size; i++) {
		[mutableArray addObject:[NSNull null]];
	}
	return mutableArray;
}

#pragma mark - UIImagePicker delegate

- (void)imagePickerController:(UIImagePickerController *)picker
		didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
{
	NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
	[_imagePickerController dismissViewControllerAnimated:YES completion:nil];
	if (self.result == nil) {
		return;
	}

	if (videoURL != nil) {
		if (@available(iOS 13.0, *)) {
			NSString *fileName = [videoURL lastPathComponent];
			NSURL *destination = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]];

			if ([[NSFileManager defaultManager] isReadableFileAtPath:[videoURL path]]) {
				NSError *error;
				if (![[videoURL path] isEqualToString:[destination path]]) {
					[[NSFileManager defaultManager] copyItemAtURL:videoURL toURL:destination error:&error];

					if (error) {
						[self finishWithError:@"Could not cache the video file."];
						return;
					}
				}
				videoURL = destination;
			}
		}

		if (self.returningVideoList) {
			[self handleSavedVideoPaths:@[ videoURL.path ?: [NSNull null] ]];
		} else {
			[self handleSavedVideoPath:videoURL.path];
		}
		return;
	}

	UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (image == nil) {
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	}
	if (image == nil) {
		[self finishWithError:@"Could not read the selected image."];
		return;
	}

	NSDictionary *arguments = self.arguments;
	NSNumber *maxWidth = [arguments objectForKey:@"maxWidth"];
	NSNumber *maxHeight = [arguments objectForKey:@"maxHeight"];
	NSNumber *imageQuality = [arguments objectForKey:@"imageQuality"];
	NSNumber *desiredImageQuality = [self getDesiredImageQuality:imageQuality];

	PHAsset *originalAsset = [FOMediaPickerPhotoAssetUtil getAssetFromImagePickerInfo:info];

	BOOL hasMaxWidth = [maxWidth isKindOfClass:[NSNumber class]] && [maxWidth doubleValue] > 0;
	BOOL hasMaxHeight = [maxHeight isKindOfClass:[NSNumber class]] && [maxHeight doubleValue] > 0;
	if (hasMaxWidth || hasMaxHeight) {
		image = [FOMediaPickerImageUtil scaledImage:image maxWidth:maxWidth maxHeight:maxHeight isMetadataAvailable:YES];
	}

	if (!originalAsset) {
		[self saveImageData:nil image:image imageQuality:desiredImageQuality];
	} else {
		PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
		options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
		options.resizeMode = PHImageRequestOptionsResizeModeNone;
		options.networkAccessAllowed = YES;

		[[PHImageManager defaultManager]
				requestImageDataForAsset:originalAsset options:options
										resultHandler:^(NSData *_Nullable imageData, NSString *_Nullable dataUTI, UIImageOrientation orientation, NSDictionary *_Nullable info) {
											dispatch_async(dispatch_get_main_queue(), ^{
												[self saveImageData:imageData image:image imageQuality:desiredImageQuality];
											});
										}];
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[_imagePickerController dismissViewControllerAnimated:YES completion:nil];
	if (self.result == nil) {
		return;
	}
	[self finishWithError:@"User cancelled picking media."];
}

#pragma mark - Saving

- (void)saveImageData:(NSData *)data image:(UIImage *)image imageQuality:(NSNumber *)imageQuality
{
	NSString *savedPath = [FOMediaPickerPhotoAssetUtil saveImageWithOriginalImageData:data image:image imageQuality:imageQuality];
	[self handleSavedImagePaths:@[ savedPath ?: [NSNull null] ]];
}

- (NSString *)jsonStringFromArray:(NSArray *)array
{
	NSError *jsonError = nil;
	NSData *data = [NSJSONSerialization dataWithJSONObject:array options:0 error:&jsonError];
	if (data == nil) {
		return nil;
	}
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSArray *)validPathsFromList:(NSArray *)pathList
{
	NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:pathList.count];
	for (id item in pathList) {
		if ([item isKindOfClass:[NSString class]] && ((NSString *)item).length > 0) {
			[paths addObject:item];
		}
	}
	return paths;
}

- (void)handleSavedImagePaths:(NSArray *)pathList
{
	if (self.result == nil) {
		return;
	}

	NSArray *paths = [self validPathsFromList:pathList];
	if (paths.count == 0) {
		[self finishWithError:@"Could not save the selected image(s)."];
		return;
	}
	if (paths.count != pathList.count) {
		[self finishWithError:@"Some of the selected images could not be saved."];
		return;
	}

	NSString *json = [self jsonStringFromArray:paths];
	if (json == nil) {
		[self finishWithError:@"Could not serialize the selected image paths."];
		return;
	}

	StringAction callback = self.result;
	[self clearState];
	callback(json);
}

- (void)handleSavedVideoPath:(NSString *)path
{
	if (self.result == nil) {
		return;
	}
	if (![path isKindOfClass:[NSString class]] || path.length == 0) {
		[self finishWithError:@"Could not save the selected video."];
		return;
	}

	StringAction callback = self.result;
	[self clearState];
	callback(path);
}

- (void)handleSavedVideoPaths:(NSArray *)pathList
{
	if (self.result == nil) {
		return;
	}

	NSArray *paths = [self validPathsFromList:pathList];
	if (paths.count == 0) {
		[self finishWithError:@"Could not save the selected video(s)."];
		return;
	}
	if (paths.count != pathList.count) {
		[self finishWithError:@"Some of the selected videos could not be saved."];
		return;
	}

	if (!self.returningVideoList) {
		[self handleSavedVideoPath:paths.firstObject];
		return;
	}

	NSString *json = [self jsonStringFromArray:paths];
	if (json == nil) {
		[self finishWithError:@"Could not serialize the selected video paths."];
		return;
	}

	StringAction callback = self.result;
	[self clearState];
	callback(json);
}

@end
