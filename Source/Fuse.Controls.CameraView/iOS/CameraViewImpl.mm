#import <Foundation/Foundation.h>

#include "CameraViewImpl.h"

#include "CameraDelegates.h"

#include <stdlib.h>
#include <ImageIO/ImageIO.h>


@interface FCVPhotoCaptureDelegate : NSObject <AVCapturePhotoCaptureDelegate>
@property (nonatomic, copy) void (^onResolve)(id, int);
@property (nonatomic, copy) void (^onReject)(NSString*);
@property (nonatomic, assign) void* state;
@property (nonatomic, assign) void* cameraView;
@property (nonatomic, assign) BOOL resolved;
- (instancetype)initWithResolve:(void(^)(id,int))resolve reject:(void(^)(NSString*))reject state:(void*)state cameraView:(void*)cameraView;
@end

namespace fcv {

	static AVCaptureVideoOrientation VideoOrientationFromInterfaceOrientation(UIInterfaceOrientation orientation) {
		switch (orientation) {
			case UIInterfaceOrientationPortrait: return AVCaptureVideoOrientationPortrait;
			case UIInterfaceOrientationPortraitUpsideDown: return AVCaptureVideoOrientationPortraitUpsideDown;
			case UIInterfaceOrientationLandscapeLeft: return AVCaptureVideoOrientationLandscapeRight;
			case UIInterfaceOrientationLandscapeRight: return AVCaptureVideoOrientationLandscapeLeft;
			default: return AVCaptureVideoOrientationPortrait;
		}
	}

	static UIInterfaceOrientation CurrentInterfaceOrientation() {
		UIWindow* keyWindow = [UIApplication sharedApplication].keyWindow;
		if (@available(iOS 13.0, *)) {
			UIWindowScene* windowScene = keyWindow.windowScene;
			if (windowScene)
				return windowScene.interfaceOrientation;
		}
		return [UIApplication sharedApplication].statusBarOrientation;
	}

	static NSArray<NSNumber*>* SupportedFlashModesForDevice(AVCaptureDevice* device) {
		NSMutableArray* supportedFlashModes = [[NSMutableArray alloc] init];
		if ([device isFlashModeSupported:AVCaptureFlashModeAuto])
			[supportedFlashModes addObject:[NSNumber numberWithInt:AVCaptureFlashModeAuto]];

		if ([device isFlashModeSupported:AVCaptureFlashModeOn])
			[supportedFlashModes addObject:[NSNumber numberWithInt:AVCaptureFlashModeOn]];

		if ([device isFlashModeSupported:AVCaptureFlashModeOff])
			[supportedFlashModes addObject:[NSNumber numberWithInt:AVCaptureFlashModeOff]];

		return supportedFlashModes;
	}

	static NSArray<NSValue*>* PhotoResolutionsForDevice(AVCaptureDevice* device) {
		NSMutableArray* photoResolutions = [[NSMutableArray alloc] init];
		if (!device.activeFormat)
			return photoResolutions;

		if (@available(iOS 16.0, *)) {
			for (NSValue* value in device.activeFormat.supportedMaxPhotoDimensions) {
				CMVideoDimensions dimensions;
				[value getValue:&dimensions];
				if (dimensions.width > 0 && dimensions.height > 0)
					[photoResolutions addObject:[NSValue valueWithCGSize:CGSizeMake(dimensions.width, dimensions.height)]];
			}
		}

		// Before iOS 16 there is no way to pick the capture resolution, so only
		// the active format's high resolution dimensions are reported.
		if (photoResolutions.count == 0) {
			CMVideoDimensions dimensions = device.activeFormat.highResolutionStillImageDimensions;
			if (dimensions.width <= 0 || dimensions.height <= 0)
				dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription);

			if (dimensions.width > 0 && dimensions.height > 0)
				[photoResolutions addObject:[NSValue valueWithCGSize:CGSizeMake(dimensions.width, dimensions.height)]];
		}

		return photoResolutions;
	}

	static NSArray<NSNumber*>* SupportedFacings() {
		NSMutableArray* facings = [[NSMutableArray alloc] init];
		BOOL hasBack = NO;
		BOOL hasFront = NO;
		for (AVCaptureDevice* device in [AVCaptureDevice devices]) {
			if (![device hasMediaType:AVMediaTypeVideo])
				continue;

			if (device.position == AVCaptureDevicePositionBack)
				hasBack = YES;
			else if (device.position == AVCaptureDevicePositionFront)
				hasFront = YES;
		}

		if (hasBack)
			[facings addObject:[NSNumber numberWithInt:CAMERA_FACING_BACK]];
		if (hasFront)
			[facings addObject:[NSNumber numberWithInt:CAMERA_FACING_FRONT]];

		return facings;
	}

	void dispose(AVState* avState) {
		if (avState->metadataDelegate) {
			id delegate = (id)avState->metadataDelegate;
			if ([delegate respondsToSelector:@selector(cancelWithMessage:)])
				[delegate cancelWithMessage:@"Camera has been disposed"];
			avState->metadataDelegate = nil;
		}
		avState->metadataOutput = NULL;

		avState->videoDataOutput = nil;
		avState->videoDataDelegate = nil;
		avState->presetBeforeVideoData = nil;

		NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
		if (avState->sessionRuntimeErrorObserver) {
			[center removeObserver:avState->sessionRuntimeErrorObserver];
			avState->sessionRuntimeErrorObserver = nil;
		}
		if (avState->sessionInterruptedObserver) {
			[center removeObserver:avState->sessionInterruptedObserver];
			avState->sessionInterruptedObserver = nil;
		}
		if (avState->sessionInterruptionEndedObserver) {
			[center removeObserver:avState->sessionInterruptionEndedObserver];
			avState->sessionInterruptionEndedObserver = nil;
		}

		avState->preview = NULL;
		if (avState->session) {
			if (avState->session.running)
				[avState->session stopRunning];
			avState->session = NULL;
		}
		avState->deviceInput = NULL;
		avState->audioDeviceInput = NULL;
		avState->photoOutput = NULL;
		avState->movieFileOutput = NULL;
		avState->metadataOutput = NULL;
		avState->metadataDelegate = nil;
		avState->pendingPhotoDelegates = nil;
		avState->whiteBalanceMode = nil;
		avState->focusMode = nil;
		avState->mirrorMode = nil;
		avState->errorCallback = nil;
		avState->recordingSession = NULL;
		avState->queue = NULL;
		free(avState);
	}

	static NSString* SessionPresetForVideoOptions(VideoOptions options) {
		if (options.height <= 0)
			return AVCaptureSessionPresetHigh;
		if (options.height <= 480)
			return AVCaptureSessionPreset640x480;
		if (options.height <= 720)
			return AVCaptureSessionPreset1280x720;
		if (options.height <= 1080)
			return AVCaptureSessionPreset1920x1080;
		return AVCaptureSessionPreset3840x2160;
	}

	static void ApplyVideoOptionsLocked(CameraView* cameraView) {
		AVState* avState = cameraView->avState;
		NSString* preset = SessionPresetForVideoOptions(cameraView->videoOptions);
		if ([avState->session canSetSessionPreset:preset])
			avState->session.sessionPreset = preset;
		else if ([avState->session canSetSessionPreset:AVCaptureSessionPresetHigh])
			avState->session.sessionPreset = AVCaptureSessionPresetHigh;

		if (cameraView->videoOptions.audioEnabled) {
			if (!avState->audioDeviceInput) {
				NSError* error = nil;
				AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
				AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
				if (input && [avState->session canAddInput:input]) {
					[avState->session addInput:input];
					avState->audioDeviceInput = input;
				} else {
					NSLog(@"Could not add audio device input: %@", error);
				}
			}
		} else if (avState->audioDeviceInput) {
			[avState->session removeInput:avState->audioDeviceInput];
			avState->audioDeviceInput = nil;
		}
	}

	static void ApplyMirroringToConnection(AVCaptureConnection* connection, BOOL mirror) {
		if (!connection || !connection.supportsVideoMirroring)
			return;

		if (connection.automaticallyAdjustsVideoMirroring)
			connection.automaticallyAdjustsVideoMirroring = NO;

		connection.videoMirrored = mirror;
	}

	// Must be called on the session queue. The preview layer part is moved to
	// the main queue since it is a UIView.
	static void ApplyMirroring(CameraView* cameraView) {
		AVState* avState = cameraView->avState;
		if (!avState)
			return;

		NSString* mode = avState->mirrorMode ?: @"auto";
		BOOL isFront = cameraView->cameraFacing == CAMERA_FACING_FRONT;
		BOOL mirrorPreview = [mode isEqualToString:@"on"] || ([mode isEqualToString:@"auto"] && isFront);
		BOOL mirrorCapture = [mode isEqualToString:@"on"];

		ApplyMirroringToConnection([avState->photoOutput connectionWithMediaType:AVMediaTypeVideo], mirrorCapture);

		if (avState->movieFileOutput)
			ApplyMirroringToConnection([avState->movieFileOutput connectionWithMediaType:AVMediaTypeVideo], mirrorCapture);

		CameraPreview* preview = avState->preview;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (preview)
				ApplyMirroringToConnection(preview.videoPreviewLayer.connection, mirrorPreview);
		});
	}

	static NSString* RuntimeErrorReason(NSError* error) {
		if (!error)
			return @"unknown";

		switch (error.code) {
			case AVErrorMediaServicesWereReset: return @"media-services-reset";
			case AVErrorDeviceWasDisconnected: return @"disconnected";
			case AVErrorSessionWasInterrupted: return @"interrupted";
			case AVErrorMaximumStillImageCaptureRequestsExceeded: return @"too-many-captures";
			default: return @"unknown";
		}
	}

	static NSString* InterruptionReason(NSNumber* value) {
		if (!value)
			return @"unknown";

		switch (value.integerValue) {
			case AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient: return @"in-use";
			case AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient: return @"in-use";
			case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps: return @"in-use";
			case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground: return @"background";
			case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableDueToSystemPressure: return @"system-pressure";
			default: return @"unknown";
		}
	}

	static void ReportCameraEvent(AVState* avState, NSString* type, NSString* reason, NSString* message) {
		id callback = avState->errorCallback;
		if (callback)
			((void (^)(NSString*, NSString*, NSString*))callback)(type, reason, message);
	}

	disposable_t loadCameraView(CameraPreview* cameraPreview, void(^onResolve)(void*), void(^onReject)(NSString*)) {

		AVState* avState = (AVState*)malloc(sizeof(AVState));
		memset(avState, 0, sizeof(AVState));
		avState->preview = cameraPreview;
		avState->session = [[AVCaptureSession alloc] init];
		avState->preview.session = avState->session;
		avState->queue = dispatch_queue_create("com.fuse.cameraview.session", DISPATCH_QUEUE_SERIAL);
		avState->pendingPhotoDelegates = [[NSMutableArray alloc] init];
		avState->whiteBalanceMode = @"auto";
		avState->focusMode = @"continuous";
		avState->mirrorMode = @"auto";

		NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
		avState->sessionRuntimeErrorObserver = [center addObserverForName:AVCaptureSessionRuntimeErrorNotification object:avState->session queue:nil usingBlock:^(NSNotification* note) {
			NSError* error = note.userInfo[AVCaptureSessionErrorKey];
			NSLog(@"Camera session runtime error: %@", error);
			ReportCameraEvent(avState, @"error", RuntimeErrorReason(error), error.localizedDescription ?: @"The camera session reported an error");
		}];
		avState->sessionInterruptedObserver = [center addObserverForName:AVCaptureSessionWasInterruptedNotification object:avState->session queue:nil usingBlock:^(NSNotification* note) {
			NSNumber* reason = note.userInfo[AVCaptureSessionInterruptionReasonKey];
			NSLog(@"Camera session interrupted: %@", reason);
			ReportCameraEvent(avState, @"interrupted", InterruptionReason(reason), @"The camera session was interrupted");
		}];
		avState->sessionInterruptionEndedObserver = [center addObserverForName:AVCaptureSessionInterruptionEndedNotification object:avState->session queue:nil usingBlock:^(NSNotification* note) {
			NSLog(@"Camera session interruption ended");
			ReportCameraEvent(avState, @"resumed", @"", @"The camera session is available again");
		}];

		CameraView* cameraView = (CameraView*)malloc(sizeof(CameraView));
		memset(cameraView, 0, sizeof(CameraView));
		cameraView->avState = avState;
		cameraView->captureMode = CAPTURE_MODE_PHOTO;
		cameraView->captureState = CAPTURE_STATE_IDLE;
		cameraView->videoOptions.audioEnabled = true;
		cameraView->videoOptions.stabilizationEnabled = true;

		auto configureSession = ^{
			[avState->session beginConfiguration];
			avState->session.sessionPreset = AVCaptureSessionPresetPhoto;

			CameraFacing cameraFacing = CAMERA_FACING_BACK;

			AVCaptureDevice* backDevice = NULL;
			AVCaptureDevice* frontDevice = NULL;
			for (AVCaptureDevice* device in [AVCaptureDevice devices]) {
				if ([device hasMediaType:AVMediaTypeVideo]) {
					if (device.position == AVCaptureDevicePositionFront) {
						frontDevice = device;
					} else if (device.position == AVCaptureDevicePositionBack) {
						backDevice = device;
					}
				}
			}

			AVCaptureDevice* device;
			if (backDevice) {
				device = backDevice;
			} else if (frontDevice) {
				device = frontDevice;
				cameraFacing = CAMERA_FACING_FRONT;
			} else {
				[avState->session commitConfiguration];
				onReject(@"Failed to find a usable AVCaptureDevice");
				return;
			}

			NSError* error = NULL;
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
			if (!input) {;
				[avState->session commitConfiguration];
				onReject([NSString stringWithFormat:@"Could not create video device input: %@", error]);
				dispose(avState);
				return;
			}

			if ([avState->session canAddInput:input] ) {
				[avState->session addInput:input];
				avState->deviceInput = input;

				CameraPreview* preview = avState->preview;
				dispatch_async(dispatch_get_main_queue(), ^{
					UIInterfaceOrientation interfaceOrientation = CurrentInterfaceOrientation();
					preview.videoPreviewLayer.connection.videoOrientation = VideoOrientationFromInterfaceOrientation(interfaceOrientation);
				});
			} else {
				[avState->session commitConfiguration];
				onReject(@"Could not add video device input to the session");
				dispose(avState);
				return;
			}

			avState->photoOutput = [[AVCapturePhotoOutput alloc] init];
			if ([avState->session canAddOutput:avState->photoOutput]) {
				[avState->session addOutput:avState->photoOutput];
				if (@available(iOS 13.0, *))
					avState->photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;

				if (@available(iOS 16.0, *)) {
					CMVideoDimensions best = { 0, 0 };
					for (NSValue* value in device.activeFormat.supportedMaxPhotoDimensions) {
						CMVideoDimensions dimensions;
						[value getValue:&dimensions];
						if ((int64_t)dimensions.width * dimensions.height > (int64_t)best.width * best.height)
							best = dimensions;
					}
					if (best.width > 0 && best.height > 0)
						avState->photoOutput.maxPhotoDimensions = best;
				} else {
					avState->photoOutput.highResolutionCaptureEnabled = YES;
				}
			} else {
				[avState->session commitConfiguration];
				onReject(@"Could not add still image output to the session");
				dispose(avState);
				return;
			}

			[avState->session commitConfiguration];
			[avState->session startRunning];

			cameraView->cameraFacing = cameraFacing;

			ApplyMirroring(cameraView);

			onResolve(cameraView);
		};

		switch([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])
		{
			case AVAuthorizationStatusAuthorized:
				dispatch_async(avState->queue, configureSession);
				break;

			case AVAuthorizationStatusNotDetermined: {
				dispatch_queue_t queue = avState->queue;
				dispatch_suspend(queue);
				bool* isPermissionGranted = (bool*)malloc(sizeof(bool));
				*isPermissionGranted = false;
				dispatch_async(queue, ^{
					if (*isPermissionGranted) {
						configureSession();
					} else {
						onReject(@"Permission to camera denied");
					}
					free(isPermissionGranted);
				});
				[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL permissionGranted) {
					*isPermissionGranted = permissionGranted;
					dispatch_resume(queue);
				}];
				break;
			}
			default:
				// Permission already denied
				onReject(@"Permission to camera denied");
				break;
		}

		return cameraView;
	}


	void setCaptureMode(CameraView* cameraView, int captureMode, void(^onResolve)(int), void(^onReject)(NSString*)) {
		if (captureMode == CAPTURE_MODE_VIDEO && cameraView->videoOptions.audioEnabled) {
			switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
				case AVAuthorizationStatusAuthorized:
					break;
				case AVAuthorizationStatusNotDetermined: {
					[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
						if (granted)
							setCaptureMode(cameraView, captureMode, onResolve, onReject);
						else
							onReject(@"Permission to microphone denied");
					}];
					return;
				}
				default:
					onReject(@"Permission to microphone denied");
					return;
			}
		}

		dispatch_async(cameraView->avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set CaptureMode while recording video or capturing photo");
				return;
			}

			if (cameraView->captureMode == captureMode) {
				onResolve(captureMode);
				return;
			}

			AVState* avState = cameraView->avState;
			[avState->session beginConfiguration];

			if (captureMode == CAPTURE_MODE_VIDEO) {
				AVCaptureMovieFileOutput* movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
				if ([avState->session canAddOutput:movieFileOutput]) {
					[avState->session addOutput:movieFileOutput];
					ApplyVideoOptionsLocked(cameraView);

					AVCaptureConnection* connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
					if (connection.isVideoStabilizationSupported) {
						connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
					}
					avState->movieFileOutput = movieFileOutput;
				} else {
					[avState->session commitConfiguration];
					onReject(@"Cannot add AVCaptureMovieFileOutput as an output");
					return;
				}
			} else if (captureMode == CAPTURE_MODE_PHOTO) {
				if (avState->movieFileOutput) {
					[avState->session removeOutput:avState->movieFileOutput];
					avState->movieFileOutput = NULL;
				}
				if (avState->audioDeviceInput) {
					[avState->session removeInput:avState->audioDeviceInput];
					avState->audioDeviceInput = NULL;
				}
				avState->session.sessionPreset = AVCaptureSessionPresetPhoto;
			}
			[avState->session commitConfiguration];
			cameraView->captureMode = (CaptureMode)captureMode;
			ApplyMirroring(cameraView);
			onResolve(captureMode);
		});
	}

	void setVideoOptions(CameraView* cameraView, VideoOptions options, void(^onResolve)(bool), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set VideoOptions while capturing photo or video");
				return;
			}

			cameraView->videoOptions = options;

			if (cameraView->captureMode == CAPTURE_MODE_VIDEO) {
				[avState->session beginConfiguration];
				ApplyVideoOptionsLocked(cameraView);
				[avState->session commitConfiguration];
			}

			if (options.frameRate > 0 || options.bitRate > 0)
				NSLog(@"CameraView: frameRate/bitRate video options are not supported on iOS");

			onResolve(YES);
		});
	}

	static int64_t AreaDistance(int64_t width, int64_t height, int64_t otherWidth, int64_t otherHeight) {
		int64_t area = width * height;
		int64_t otherArea = otherWidth * otherHeight;
		return area > otherArea ? area - otherArea : otherArea - area;
	}

	void setPhotoResolution(CameraView* cameraView, int width, int height, void(^onResolve)(void), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (@available(iOS 16.0, *)) {
				AVCaptureDevice* device = avState->deviceInput.device;
				AVCapturePhotoOutput* photoOutput = avState->photoOutput;
				if (!device || !photoOutput) {
					onReject(@"Camera is not ready");
					return;
				}

				if (width <= 0 || height <= 0) {
					onReject(@"Invalid photo resolution");
					return;
				}

				CMVideoDimensions best = { 0, 0 };
				int64_t bestDistance = 0;

				for (NSValue* value in device.activeFormat.supportedMaxPhotoDimensions) {
					CMVideoDimensions dimensions;
					[value getValue:&dimensions];
					if (dimensions.width <= 0 || dimensions.height <= 0)
						continue;

					// Pick the supported resolution closest to the requested one.
					int64_t distance = AreaDistance(width, height, dimensions.width, dimensions.height);
					if (best.width <= 0 || distance < bestDistance) {
						best = dimensions;
						bestDistance = distance;
					}
				}

				if (best.width <= 0) {
					onReject(@"No photo resolutions are available for this camera");
					return;
				}

				photoOutput.maxPhotoDimensions = best;
				onResolve();
			} else {
				onReject(@"Photo resolution is not supported before iOS 16");
			}
		});
	}

	void capturePhoto(CameraView* cameraView, void(^onResolve)(id,int), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		AVCaptureVideoOrientation orientation = avState->preview.videoPreviewLayer.connection.videoOrientation;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot capture photo while capturing photo or recording video");
				return;
			}
			if (cameraView->captureMode != CAPTURE_MODE_PHOTO) {
				onReject(@"Cannot capture photo, CaptureMode not set to Photo");
				return;
			}

			cameraView->captureState = CAPTURE_STATE_CAPTURING_PHOTO;

			AVCapturePhotoOutput* photoOutput = avState->photoOutput;
			if (!photoOutput) {
				cameraView->captureState = CAPTURE_STATE_IDLE;
				onReject(@"Still image output is not available");
				return;
			}

			AVCaptureConnection* videoConnection = [photoOutput connectionWithMediaType:AVMediaTypeVideo];
			if (videoConnection && videoConnection.supportsVideoOrientation)
				videoConnection.videoOrientation = orientation;

			AVCapturePhotoSettings* settings = [AVCapturePhotoSettings photoSettings];
			AVCaptureDevice* device = avState->deviceInput.device;
			AVCaptureFlashMode flashMode = device ? device.flashMode : AVCaptureFlashModeOff;
			if ([photoOutput.supportedFlashModes containsObject:[NSNumber numberWithInt:flashMode]])
				settings.flashMode = flashMode;
			else
				settings.flashMode = AVCaptureFlashModeOff;

			if (@available(iOS 13.0, *)) {
				AVCapturePhotoQualityPrioritization prioritization = AVCapturePhotoQualityPrioritizationQuality;
				if (prioritization > photoOutput.maxPhotoQualityPrioritization)
					prioritization = photoOutput.maxPhotoQualityPrioritization;
				settings.photoQualityPrioritization = prioritization;
			}

			if (@available(iOS 16.0, *)) {
				// High resolution dimensions are configured on the photo output.
				settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions;
			} else {
				settings.highResolutionPhotoEnabled = YES;
			}

			FCVPhotoCaptureDelegate* delegate = [[FCVPhotoCaptureDelegate alloc] initWithResolve:onResolve reject:onReject state:avState cameraView:cameraView];
			[avState->pendingPhotoDelegates addObject:delegate];

			@try {
				[photoOutput capturePhotoWithSettings:settings delegate:delegate];
			} @catch (NSException* exception) {
				cameraView->captureState = CAPTURE_STATE_IDLE;
				[avState->pendingPhotoDelegates removeObject:delegate];
				onReject(exception.reason ?: @"Failed to capture photo");
			}
		});
	}

	void startRecording(CameraView* cameraView, void(^onResolve)(RecordingSession*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		AVCaptureVideoOrientation orientation = avState->preview.videoPreviewLayer.connection.videoOrientation;

		void (^startBlock)(void) = ^{
			dispatch_async(avState->queue, ^{
				if (cameraView->captureState != CAPTURE_STATE_IDLE) {
					onReject(@"Cannot start video recording while capturing photo or recording video");
					return;
				}

				if (cameraView->captureMode != CAPTURE_MODE_VIDEO) {
					onReject(@"Cannot start recording video, CaptureMode not set to Video");
					return;
				}

				cameraView->captureState = CAPTURE_STATE_RECORDING_VIDEO;

				UIBackgroundTaskIdentifier currentBackgroundTaskId = UIBackgroundTaskInvalid;
				if ([UIDevice currentDevice].isMultitaskingSupported) {
					currentBackgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
				}

				AVCaptureConnection* movieFileOutputConnection = [avState->movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
				movieFileOutputConnection.videoOrientation = orientation;
				if (movieFileOutputConnection.isVideoStabilizationSupported) {
					movieFileOutputConnection.preferredVideoStabilizationMode = cameraView->videoOptions.stabilizationEnabled
						? AVCaptureVideoStabilizationModeAuto
						: AVCaptureVideoStabilizationModeOff;
				}

				NSError* audioSessionError = nil;
				AVAudioSession* audioSession = [AVAudioSession sharedInstance];
				[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
					withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
					error:&audioSessionError];
				if (audioSessionError)
					NSLog(@"Failed to configure audio session category: %@", audioSessionError);

				audioSessionError = nil;
				[audioSession setActive:YES error:&audioSessionError];
				if (audioSessionError)
					NSLog(@"Failed to activate audio session: %@", audioSessionError);

				NSString* outputFileName = [NSUUID UUID].UUIDString;
				NSString* documentsDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
				NSString* outputFilePath = [documentsDirectory stringByAppendingPathComponent:[outputFileName stringByAppendingPathExtension:@"mov"]];

				RecordingSession* session = [[RecordingSession alloc] initWithMovieFileOutput:avState->movieFileOutput withOutputFilePath:outputFilePath withCleanupHandler:^{
					if (currentBackgroundTaskId != UIBackgroundTaskInvalid) {
						[[UIApplication sharedApplication] endBackgroundTask:currentBackgroundTaskId];
					}
					[[AVAudioSession sharedInstance] setActive:NO
						withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
						error:NULL];
					avState->recordingSession = NULL;
					cameraView->captureState = CAPTURE_STATE_IDLE;
				} withDispatchQueue:avState->queue];

				avState->recordingSession = session;
				[session startRecording];
				onResolve(session);
			});
		};

		switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
			case AVAuthorizationStatusAuthorized:
				startBlock();
				break;
			case AVAuthorizationStatusNotDetermined: {
				[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
					if (granted)
						startBlock();
					else
						onReject(@"Permission to microphone denied");
				}];
				break;
			}
			default:
				onReject(@"Permission to microphone denied");
				break;
		}
	}

	void setCameraFacing(CameraView* cameraView, int cameraFacing, void(^onResolve)(int), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set CameraFacing while capturing photo or video");
				return;
			}

			if (cameraView->cameraFacing == cameraFacing) {
				onResolve(cameraFacing);
				return;
			}

			AVCaptureDevice* currentDevice = avState->deviceInput.device;
			AVCaptureDevicePosition currentPosition = currentDevice.position;

			AVCaptureDevicePosition preferredPosition;

			switch (cameraFacing) {
				case CAMERA_FACING_FRONT:
					preferredPosition = AVCaptureDevicePositionFront;
					break;
				case CAMERA_FACING_BACK:
					preferredPosition = AVCaptureDevicePositionBack;
					break;
			}

			NSArray<AVCaptureDevice*>* devices = [AVCaptureDevice devices];
			AVCaptureDevice* newDevice = nil;

			for (AVCaptureDevice* device in devices) {
				if (device.position == preferredPosition) {
					newDevice = device;
					break;
				}
			}

			if (!newDevice) {
				onReject(@"Could not set camerafacing, facing not supported or not present");
				return;
			}

			AVCaptureDeviceInput* deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newDevice error:NULL];

			[avState->session beginConfiguration];
			[avState->session removeInput:avState->deviceInput];
			if ([avState->session canAddInput:deviceInput]) {
				[avState->session addInput:deviceInput];
				avState->deviceInput = deviceInput;
			} else {
				[avState->session addInput:avState->deviceInput];
				[avState->session commitConfiguration];
				onReject(@"Could not set cameraFacing, cannot add new facing as session input");
				return;
			}

			if (avState->movieFileOutput) {
				AVCaptureConnection* movieFileOutputConnection = [avState->movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
				if (movieFileOutputConnection.isVideoStabilizationSupported) {
					movieFileOutputConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
				}
			}
			[avState->session commitConfiguration];
			cameraView->cameraFacing = (CameraFacing)cameraFacing;
			ApplyMirroring(cameraView);
			onResolve(cameraView->cameraFacing);
		});
	}


	void setCameraFocusPoint(CameraView* cameraView,
		double x, double y, int cameraWidth, int cameraHeight,
		int isFocusLocked,
		void(^onResolve)(id), void(^onReject)(NSString*)) {

		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* currentDevice = avState->deviceInput.device;
			if (!currentDevice) {
				onReject(@"No camera device available for focus");
				return;
			}

			if (cameraWidth <= 0 || cameraHeight <= 0) {
				onReject(@"Invalid camera dimensions for focus");
				return;
			}

			if (![currentDevice isFocusPointOfInterestSupported] ||
				![currentDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
				onReject(@"Focus point of interest is not supported by this camera");
				return;
			}

			NSError* error = nil;
			if (![currentDevice lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for configuration: %@", error]);
				return;
			}

			float focus_x = (float)(x / cameraWidth);
			float focus_y = (float)(y / cameraHeight);

			CGPoint focusPoint;
			switch ([[UIDevice currentDevice] orientation]) {
				case UIDeviceOrientationPortrait:
					focusPoint = CGPointMake(focus_y, 1.f - focus_x);
					break;
				case UIDeviceOrientationPortraitUpsideDown:
					focusPoint = CGPointMake(1.f - focus_y, focus_x);
					break;
				case UIDeviceOrientationLandscapeLeft:
					focusPoint = CGPointMake(focus_y, 1.f - focus_x);
					break;
				case UIDeviceOrientationLandscapeRight:
					focusPoint = CGPointMake(1.f - focus_x, focus_y);
					break;
				default:
					focusPoint = CGPointMake(focus_y, 1.f - focus_x);
					break;
			}

			if ([currentDevice isFocusPointOfInterestSupported])
				[currentDevice setFocusPointOfInterest:focusPoint];

			if ([currentDevice isExposurePointOfInterestSupported])
				[currentDevice setExposurePointOfInterest:focusPoint];

			// Respect the configured focus mode: tapping does not move locked focus.
			if (![avState->focusMode isEqualToString:@"locked"]) {
				AVCaptureFocusMode desiredFocusMode = [avState->focusMode isEqualToString:@"auto"]
					? AVCaptureFocusModeAutoFocus
					: AVCaptureFocusModeContinuousAutoFocus;
				if ([currentDevice isFocusModeSupported:desiredFocusMode])
					[currentDevice setFocusMode:desiredFocusMode];
			}

			// Only reset exposure and white balance when they are not manually
			// controlled, so tapping the preview does not discard those settings.
			if (currentDevice.exposureMode != AVCaptureExposureModeCustom &&
				[currentDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
				[currentDevice setExposureMode:AVCaptureExposureModeContinuousAutoExposure];

			if ([avState->whiteBalanceMode isEqualToString:@"auto"] &&
				[currentDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance])
				[currentDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];

			if (isFocusLocked == 1) {
				if ([currentDevice isFocusModeSupported:AVCaptureFocusModeLocked])
					[currentDevice setFocusMode:AVCaptureFocusModeLocked];

				if ([currentDevice isExposureModeSupported:AVCaptureExposureModeLocked])
					[currentDevice setExposureMode:AVCaptureExposureModeLocked];

				if ([currentDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked])
					[currentDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
			}

			[currentDevice unlockForConfiguration];
			onResolve(NULL);
		});
	}

	void setFlashMode(CameraView* cameraView, int flashMode, void(^onResolve)(int), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set FlashMode while capturing photo or video");
				return;
			}

			AVCaptureDevice* device = avState->deviceInput.device;
			NSError* error = NULL;
			if ([device lockForConfiguration:&error]) {
				if ([device isFlashModeSupported:(AVCaptureFlashMode)flashMode]) {
					[device setFlashMode:(AVCaptureFlashMode)flashMode];
					onResolve(flashMode);
				} else {
					onReject(@"FlashMode not supported");
				}
			} else {
				onReject([NSString stringWithFormat:@"Failed to set flash mode: %@", error]);
			}
		});
	}

	void getCameraInfo(CameraView* cameraView, void(^callback)(CameraInfo)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			CameraInfo cameraInfo = {};
			memset(&cameraInfo, 0, sizeof(CameraInfo));

			AVCaptureDevice* device = avState->deviceInput.device;
			cameraInfo.captureMode = cameraView->captureMode;
			cameraInfo.flashMode = device ? (FlashMode)device.flashMode : FLASH_MODE_OFF;
			cameraInfo.cameraFacing = cameraView->cameraFacing;
			cameraInfo.supportedFlashModes = SupportedFlashModesForDevice(device);
			cameraInfo.photoResolutions = PhotoResolutionsForDevice(device);
			cameraInfo.zoom = device ? device.videoZoomFactor : 1.0f;
			cameraInfo.torchOn = device && device.torchMode == AVCaptureTorchModeOn;
			cameraInfo.exposureCompensation = device ? device.exposureTargetBias : 0.0f;
			cameraInfo.lensId = device ? device.uniqueID : @"";
			cameraInfo.whiteBalance = avState->whiteBalanceMode ?: @"auto";
			cameraInfo.focusMode = avState->focusMode ?: @"continuous";
			cameraInfo.mirrorMode = avState->mirrorMode ?: @"auto";

			callback(cameraInfo);
		});
	}

	void getCameraCapabilities(CameraView* cameraView, void(^callback)(CameraCapabilities)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			CameraCapabilities caps = {};
			memset(&caps, 0, sizeof(CameraCapabilities));

			AVCaptureDevice* device = avState->deviceInput.device;
			if (device) {
				caps.zoomSupported = device.maxAvailableVideoZoomFactor > 1.0f;
				caps.minZoom = device.minAvailableVideoZoomFactor;
				caps.maxZoom = device.maxAvailableVideoZoomFactor;
				caps.torchSupported = device.hasTorch && device.isTorchAvailable;
				caps.supportedFlashModes = SupportedFlashModesForDevice(device);
				caps.photoResolutions = PhotoResolutionsForDevice(device);
				caps.manualExposureSupported = [device isExposureModeSupported:AVCaptureExposureModeCustom];
				caps.minIso = device.activeFormat.minISO;
				caps.maxIso = device.activeFormat.maxISO;
				caps.minShutterSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration);
				caps.maxShutterSeconds = CMTimeGetSeconds(device.activeFormat.maxExposureDuration);
			} else {
				caps.minZoom = 1.0f;
				caps.maxZoom = 1.0f;
				caps.supportedFlashModes = [NSArray array];
				caps.photoResolutions = [NSArray array];
			}
			caps.supportedFacings = SupportedFacings();
			caps.manualWhiteBalanceSupported = device && device.lockingWhiteBalanceWithCustomDeviceGainsSupported;

			callback(caps);
		});
	}

	void setZoom(CameraView* cameraView, float zoom, void(^onResolve)(float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for zoom: %@", error]);
				return;
			}

			float minZoom = device.minAvailableVideoZoomFactor;
			float maxZoom = device.maxAvailableVideoZoomFactor;
			float applied = MIN(MAX(zoom, minZoom), maxZoom);
			[device setVideoZoomFactor:applied];
			[device unlockForConfiguration];

			onResolve(device.videoZoomFactor);
		});
	}

	void getZoom(CameraView* cameraView, void(^onResolve)(float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}
			onResolve(device.videoZoomFactor);
		});
	}

	void setTorchMode(CameraView* cameraView, bool on, void(^onResolve)(bool), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set TorchMode while capturing photo or video");
				return;
			}

			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device || !device.hasTorch || !device.isTorchAvailable) {
				onReject(@"Torch is not supported");
				return;
			}

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for torch: %@", error]);
				return;
			}

			[device setTorchMode:on ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
			[device unlockForConfiguration];
			onResolve(device.torchMode == AVCaptureTorchModeOn);
		});
	}

	void isTorchOn(CameraView* cameraView, void(^onResolve)(bool), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			onResolve(device && device.torchMode == AVCaptureTorchModeOn);
		});
	}

	void setExposureCompensation(CameraView* cameraView, float value, void(^onResolve)(float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			float applied = MAX(device.minExposureTargetBias, MIN(device.maxExposureTargetBias, value));
			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for exposure: %@", error]);
				return;
			}

			__weak AVCaptureDevice* weakDevice = device;
			[device setExposureTargetBias:applied completionHandler:^(CMTime syncTime) {
				AVCaptureDevice* strongDevice = weakDevice;
				[strongDevice unlockForConfiguration];
				onResolve(strongDevice ? strongDevice.exposureTargetBias : applied);
			}];
		});
	}

	void getExposureCompensation(CameraView* cameraView, void(^onResolve)(float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}
			onResolve(device.exposureTargetBias);
		});
	}

	void getAvailableLenses(CameraView* cameraView, void(^callback)(NSArray<NSString*>*, NSArray<NSNumber*>*, NSArray<NSString*>*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			NSMutableArray<NSString*>* ids = [NSMutableArray array];
			NSMutableArray<NSNumber*>* facings = [NSMutableArray array];
			NSMutableArray<NSString*>* names = [NSMutableArray array];

			AVCaptureDeviceDiscoverySession* discovery =
				[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
					AVCaptureDeviceTypeBuiltInWideAngleCamera,
					AVCaptureDeviceTypeBuiltInUltraWideCamera,
					AVCaptureDeviceTypeBuiltInTelephotoCamera,
					AVCaptureDeviceTypeBuiltInDualCamera,
					AVCaptureDeviceTypeBuiltInDualWideCamera,
					AVCaptureDeviceTypeBuiltInTripleCamera,
					AVCaptureDeviceTypeBuiltInTrueDepthCamera
				]
				mediaType:AVMediaTypeVideo
				position:AVCaptureDevicePositionUnspecified];

			for (AVCaptureDevice* device in discovery.devices) {
				[ids addObject:device.uniqueID];
				[facings addObject:[NSNumber numberWithInt:(device.position == AVCaptureDevicePositionFront ? 1 : 0)]];
				[names addObject:(device.localizedName ?: device.uniqueID)];
			}

			callback(ids, facings, names);
		});
	}

	void setCameraLens(CameraView* cameraView, NSString* lensId, void(^onResolve)(NSString*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onReject(@"Cannot set CameraLens while capturing photo or video");
				return;
			}

			AVCaptureDeviceDiscoverySession* discovery =
				[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[
					AVCaptureDeviceTypeBuiltInWideAngleCamera,
					AVCaptureDeviceTypeBuiltInUltraWideCamera,
					AVCaptureDeviceTypeBuiltInTelephotoCamera,
					AVCaptureDeviceTypeBuiltInDualCamera,
					AVCaptureDeviceTypeBuiltInDualWideCamera,
					AVCaptureDeviceTypeBuiltInTripleCamera,
					AVCaptureDeviceTypeBuiltInTrueDepthCamera
				]
				mediaType:AVMediaTypeVideo
				position:AVCaptureDevicePositionUnspecified];

			AVCaptureDevice* device = nil;
			for (AVCaptureDevice* candidate in discovery.devices) {
				if ([candidate.uniqueID isEqualToString:lensId]) {
					device = candidate;
					break;
				}
			}

			if (!device) {
				onReject(@"Unknown camera lens");
				return;
			}

			NSError* error = nil;
			AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
			if (!input) {
				onReject([NSString stringWithFormat:@"Could not create camera input: %@", error]);
				return;
			}

			[avState->session beginConfiguration];
			[avState->session removeInput:avState->deviceInput];

			if ([avState->session canAddInput:input]) {
				[avState->session addInput:input];
				avState->deviceInput = input;
				cameraView->cameraFacing = (device.position == AVCaptureDevicePositionFront)
					? CAMERA_FACING_FRONT
					: CAMERA_FACING_BACK;

				if (avState->movieFileOutput) {
					AVCaptureConnection* connection = [avState->movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
					if (connection.isVideoStabilizationSupported)
						connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
				}

				[avState->session commitConfiguration];
				onResolve(device.uniqueID);
			} else {
				[avState->session addInput:avState->deviceInput];
				[avState->session commitConfiguration];
				onReject(@"Could not switch camera lens");
			}
		});
	}

	void setManualExposure(CameraView* cameraView, float iso, double shutterSeconds, void(^onResolve)(bool,float,float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			if (![device isExposureModeSupported:AVCaptureExposureModeCustom]) {
				onReject(@"Manual exposure is not supported");
				return;
			}

			AVCaptureDeviceFormat* format = device.activeFormat;
			float clampedIso = MAX(format.minISO, MIN(format.maxISO, iso));
			CMTime duration = CMTimeMakeWithSeconds(shutterSeconds, 1000000000);
			if (CMTimeCompare(duration, format.minExposureDuration) < 0)
				duration = format.minExposureDuration;
			if (CMTimeCompare(duration, format.maxExposureDuration) > 0)
				duration = format.maxExposureDuration;

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for manual exposure: %@", error]);
				return;
			}

			__weak AVCaptureDevice* weakDevice = device;
			[device setExposureModeCustomWithDuration:duration ISO:clampedIso completionHandler:^(CMTime syncTime) {
				AVCaptureDevice* strongDevice = weakDevice;
				[strongDevice unlockForConfiguration];
				onResolve(YES,
					strongDevice ? strongDevice.ISO : clampedIso,
					strongDevice ? CMTimeGetSeconds(strongDevice.exposureDuration) : CMTimeGetSeconds(duration));
			}];
		});
	}

	void setAutoExposure(CameraView* cameraView, void(^onResolve)(bool,float,float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for auto exposure: %@", error]);
				return;
			}

			[device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
			[device unlockForConfiguration];
			onResolve(NO, device.ISO, CMTimeGetSeconds(device.exposureDuration));
		});
	}

	void getManualExposure(CameraView* cameraView, void(^onResolve)(bool,float,float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			onResolve(device.exposureMode == AVCaptureExposureModeCustom,
				device.ISO,
				CMTimeGetSeconds(device.exposureDuration));
		});
	}

	static AVCaptureWhiteBalanceTemperatureAndTintValues TemperatureAndTintForWhiteBalance(NSString* mode) {
		AVCaptureWhiteBalanceTemperatureAndTintValues values = { 5500.0f, 0.0f };

		if ([mode isEqualToString:@"incandescent"]) {
			values.temperature = 2850.0f;
		} else if ([mode isEqualToString:@"fluorescent"]) {
			values.temperature = 4000.0f;
			values.tint = 15.0f;
		} else if ([mode isEqualToString:@"warm-fluorescent"]) {
			values.temperature = 3500.0f;
			values.tint = 10.0f;
		} else if ([mode isEqualToString:@"daylight"]) {
			values.temperature = 5500.0f;
		} else if ([mode isEqualToString:@"cloudy"]) {
			values.temperature = 6500.0f;
		} else if ([mode isEqualToString:@"twilight"]) {
			values.temperature = 4500.0f;
			values.tint = 10.0f;
		} else if ([mode isEqualToString:@"shade"]) {
			values.temperature = 7500.0f;
		}

		return values;
	}

	void setWhiteBalance(CameraView* cameraView, NSString* mode, void(^onResolve)(NSString*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			if ([mode isEqualToString:@"auto"]) {
				if (![device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
					onReject(@"White balance mode not supported: auto");
					return;
				}

				NSError* error = nil;
				if (![device lockForConfiguration:&error]) {
					onReject([NSString stringWithFormat:@"Could not lock camera for white balance: %@", error]);
					return;
				}

				device.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
				[device unlockForConfiguration];

				avState->whiteBalanceMode = @"auto";
				avState->whiteBalanceKelvin = 0.0f;
				avState->whiteBalanceTint = 0.0f;
				onResolve(@"auto");
				return;
			}

			if (!device.lockingWhiteBalanceWithCustomDeviceGainsSupported) {
				onReject(@"Custom white balance gains are not supported by this camera");
				return;
			}

			AVCaptureWhiteBalanceTemperatureAndTintValues values = TemperatureAndTintForWhiteBalance(mode);
			AVCaptureWhiteBalanceGains gains = [device deviceWhiteBalanceGainsForTemperatureAndTintValues:values];

			// Gains outside the supported range are rejected by the device.
			float maxGain = device.maxWhiteBalanceGain;
			gains.redGain = MAX(1.0f, MIN(maxGain, gains.redGain));
			gains.greenGain = MAX(1.0f, MIN(maxGain, gains.greenGain));
			gains.blueGain = MAX(1.0f, MIN(maxGain, gains.blueGain));

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for white balance: %@", error]);
				return;
			}

			[device setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:^(CMTime syncTime) {
				avState->whiteBalanceMode = mode;
				avState->whiteBalanceKelvin = 0.0f;
				avState->whiteBalanceTint = 0.0f;
				onResolve(mode);
			}];

			[device unlockForConfiguration];
		});
	}

	void getWhiteBalance(CameraView* cameraView, void(^onResolve)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			onResolve(avState->whiteBalanceMode ?: @"auto");
		});
	}

	void setWhiteBalanceTemperature(CameraView* cameraView, float kelvin, float tint, void(^onResolve)(bool, float, float), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			if (!device.lockingWhiteBalanceWithCustomDeviceGainsSupported) {
				onReject(@"Manual white balance is not supported by this camera");
				return;
			}

			float appliedKelvin = MAX(1000.0f, MIN(15000.0f, kelvin));
			float appliedTint = MAX(-150.0f, MIN(150.0f, tint));

			AVCaptureWhiteBalanceTemperatureAndTintValues values = { appliedKelvin, appliedTint };
			AVCaptureWhiteBalanceGains gains = [device deviceWhiteBalanceGainsForTemperatureAndTintValues:values];

			float maxGain = device.maxWhiteBalanceGain;
			gains.redGain = MAX(1.0f, MIN(maxGain, gains.redGain));
			gains.greenGain = MAX(1.0f, MIN(maxGain, gains.greenGain));
			gains.blueGain = MAX(1.0f, MIN(maxGain, gains.blueGain));

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for white balance: %@", error]);
				return;
			}

			[device setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains:gains completionHandler:^(CMTime syncTime) {
				avState->whiteBalanceMode = @"manual";
				avState->whiteBalanceKelvin = appliedKelvin;
				avState->whiteBalanceTint = appliedTint;
				onResolve(YES, appliedKelvin, appliedTint);
			}];

			[device unlockForConfiguration];
		});
	}

	void getWhiteBalanceTemperature(CameraView* cameraView, void(^onResolve)(bool, float, float)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			BOOL isManual = [avState->whiteBalanceMode isEqualToString:@"manual"];
			onResolve(isManual, avState->whiteBalanceKelvin, avState->whiteBalanceTint);
		});
	}

	void getFocusMode(CameraView* cameraView, void(^onResolve)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			onResolve(avState->focusMode ?: @"continuous");
		});
	}

	void setFocusMode(CameraView* cameraView, NSString* mode, void(^onResolve)(NSString*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			AVCaptureDevice* device = avState->deviceInput.device;
			if (!device) {
				onReject(@"No camera device available");
				return;
			}

			AVCaptureFocusMode focusMode;
			if ([mode isEqualToString:@"auto"])
				focusMode = AVCaptureFocusModeAutoFocus;
			else if ([mode isEqualToString:@"locked"])
				focusMode = AVCaptureFocusModeLocked;
			else
				focusMode = AVCaptureFocusModeContinuousAutoFocus;

			if (![device isFocusModeSupported:focusMode]) {
				onReject([NSString stringWithFormat:@"Focus mode not supported: %@", mode]);
				return;
			}

			NSError* error = nil;
			if (![device lockForConfiguration:&error]) {
				onReject([NSString stringWithFormat:@"Could not lock camera for focus: %@", error]);
				return;
			}

			device.focusMode = focusMode;
			[device unlockForConfiguration];

			avState->focusMode = mode;
			onResolve(mode);
		});
	}

	void getMirrorMode(CameraView* cameraView, void(^onResolve)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			onResolve(avState->mirrorMode ?: @"auto");
		});
	}

	void setMirrorMode(CameraView* cameraView, NSString* mode, void(^onResolve)(NSString*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (!avState->deviceInput.device) {
				onReject(@"No camera device available");
				return;
			}

			if (![mode isEqualToString:@"auto"] && ![mode isEqualToString:@"on"] && ![mode isEqualToString:@"off"]) {
				onReject([NSString stringWithFormat:@"Unknown mirror mode: %@", mode]);
				return;
			}

			avState->mirrorMode = mode;
			ApplyMirroring(cameraView);
			onResolve(mode);
		});
	}

	void stopErrorMonitoring(CameraView* cameraView, void(^onStopped)(bool)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			bool wasMonitoring = avState->errorCallback != nil;
			avState->errorCallback = nil;
			onStopped(wasMonitoring);
		});
	}

	void startErrorMonitoring(CameraView* cameraView, void(^onEvent)(NSString*, NSString*, NSString*), void(^onStarted)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (avState->errorCallback != nil) {
				onStarted(@"Error monitoring is already active");
				return;
			}

			avState->errorCallback = [onEvent copy];
			onStarted(nil);
		});
	}

	void dispose(disposable_t disposable) {
		CameraView* cameraView = (CameraView*)disposable;
		dispatch_queue_t queue = cameraView->avState->queue;
		dispatch_async(queue, ^{
			dispose(cameraView->avState);
			cameraView->avState = NULL;
			free(cameraView);
		});
	}
}

@implementation FCVPhotoCaptureDelegate

- (instancetype)initWithResolve:(void(^)(id,int))resolve reject:(void(^)(NSString*))reject state:(void*)state cameraView:(void*)cameraView {
	if (self = [super init]) {
		self.onResolve = resolve;
		self.onReject = reject;
		self.state = state;
		self.cameraView = cameraView;
	}
	return self;
}

- (void)captureOutput:(AVCapturePhotoOutput*)output didFinishProcessingPhoto:(AVCapturePhoto*)photo error:(NSError*)error {
	fcv::CameraView* cameraView = (fcv::CameraView*)self.cameraView;
	if (cameraView)
		cameraView->captureState = fcv::CAPTURE_STATE_IDLE;

	self.resolved = YES;

	if (error) {
		self.onReject([NSString stringWithFormat:@"Failed to capture photo: %@", error]);
		return;
	}

	NSData* data = [photo fileDataRepresentation];
	if (!data) {
		self.onReject(@"Failed to get photo data");
		return;
	}

	int orientation = kCGImagePropertyOrientationUp;
	id orientationValue = photo.metadata[(NSString*)kCGImagePropertyOrientation];
	if ([orientationValue isKindOfClass:[NSNumber class]])
		orientation = [orientationValue intValue];

	self.onResolve(data, orientation);
}

- (void)captureOutput:(AVCapturePhotoOutput*)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings*)resolvedSettings error:(NSError*)error {
	if (!self.resolved) {
		self.resolved = YES;
		fcv::CameraView* cameraView = (fcv::CameraView*)self.cameraView;
		if (cameraView)
			cameraView->captureState = fcv::CAPTURE_STATE_IDLE;

		if (error)
			self.onReject([NSString stringWithFormat:@"Failed to capture photo: %@", error]);
		else
			self.onReject(@"Failed to capture photo");
	}

	fcv::AVState* state = (fcv::AVState*)self.state;
	if (state)
		[state->pendingPhotoDelegates removeObject:self];
}

@end
