#include "CameraViewImpl.h"

#include "CameraDelegates.h"

namespace fcv {

	static NSArray<NSString*>* FCVMetadataObjectTypesForFormats(NSArray* formats) {
		NSMutableArray<NSString*>* types = [[NSMutableArray alloc] init];

		for (NSString* format in formats) {
			if (![format isKindOfClass:[NSString class]])
				continue;

			NSString* name = [format uppercaseString];
			NSString* type = nil;

			if ([name isEqualToString:@"QR_CODE"])
				type = AVMetadataObjectTypeQRCode;
			else if ([name isEqualToString:@"EAN_13"] || [name isEqualToString:@"UPC_A"])
				type = AVMetadataObjectTypeEAN13Code;
			else if ([name isEqualToString:@"EAN_8"])
				type = AVMetadataObjectTypeEAN8Code;
			else if ([name isEqualToString:@"UPC_E"])
				type = AVMetadataObjectTypeUPCECode;
			else if ([name isEqualToString:@"CODE_39"])
				type = AVMetadataObjectTypeCode39Code;
			else if ([name isEqualToString:@"CODE_93"])
				type = AVMetadataObjectTypeCode93Code;
			else if ([name isEqualToString:@"CODE_128"])
				type = AVMetadataObjectTypeCode128Code;
			else if ([name isEqualToString:@"ITF"])
				type = AVMetadataObjectTypeITF14Code;
			else if ([name isEqualToString:@"DATA_MATRIX"])
				type = AVMetadataObjectTypeDataMatrixCode;
			else if ([name isEqualToString:@"PDF417"])
				type = AVMetadataObjectTypePDF417Code;
			else if ([name isEqualToString:@"AZTEC"])
				type = AVMetadataObjectTypeAztecCode;
			else if ([name isEqualToString:@"CODABAR"]) {
				if (@available(iOS 15.4, *))
					type = AVMetadataObjectTypeCodabarCode;
			}

			if (type != nil && ![types containsObject:type])
				[types addObject:type];
		}

		return types;
	}

	// Must be called on the session queue. Returns nil when scanning started,
	// or an error message describing why it could not start.
	static NSString* EnsureMetadataOutput(CameraView* cameraView) {
		AVState* avState = cameraView->avState;

		if (avState->metadataOutput)
			return nil;

		AVCaptureMetadataOutput* output = [[AVCaptureMetadataOutput alloc] init];

		[avState->session beginConfiguration];
		if (![avState->session canAddOutput:output]) {
			[avState->session commitConfiguration];
			return @"Cannot add AVCaptureMetadataOutput to the session";
		}

		[avState->session addOutput:output];
		[avState->session commitConfiguration];

		FCVFrameAnalysisDelegate* delegate = [[FCVFrameAnalysisDelegate alloc] init];
		avState->metadataOutput = output;
		avState->metadataDelegate = delegate;
		[output setMetadataObjectsDelegate:delegate queue:avState->queue];

		return nil;
	}

	static void UpdateMetadataObjectTypes(AVState* avState) {
		AVCaptureMetadataOutput* output = avState->metadataOutput;
		if (!output)
			return;

		FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		if (!delegate)
			return;

		NSArray* types = delegate.metadataObjectTypes;
		if (types.count > 0)
			output.metadataObjectTypes = types;
	}

	// Removes the metadata output when no detector is using it.
	static bool ReleaseMetadataOutputIfIdle(AVState* avState) {
		FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		if (delegate && delegate.hasActiveConsumer)
			return false;

		if (!avState->metadataOutput)
			return false;

		AVCaptureMetadataOutput* toRemove = avState->metadataOutput;
		avState->metadataOutput = nil;
		avState->metadataDelegate = nil;

		[avState->session beginConfiguration];
		if (toRemove)
			[avState->session removeOutput:toRemove];
		[avState->session commitConfiguration];

		return true;
	}

	static void StopBarcodeDetector(AVState* avState) {
		FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		if (!delegate)
			return;

		FCVBarcodeScanDelegate* barcodeDelegate = (FCVBarcodeScanDelegate*)[delegate consumerOfClass:[FCVBarcodeScanDelegate class]];
		if (!barcodeDelegate)
			return;

		[delegate removeConsumer:barcodeDelegate];
		[barcodeDelegate cancelWithMessage:@"Barcode scanning stopped"];
		UpdateMetadataObjectTypes(avState);
		ReleaseMetadataOutputIfIdle(avState);
	}

	static void StopFaceDetector(AVState* avState) {
		FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		if (!delegate)
			return;

		FCVFaceDetectionDelegate* faceDelegate = (FCVFaceDetectionDelegate*)[delegate consumerOfClass:[FCVFaceDetectionDelegate class]];
		if (!faceDelegate)
			return;

		[delegate removeConsumer:faceDelegate];
		[faceDelegate cancelWithMessage:@"Face detection stopped"];
		UpdateMetadataObjectTypes(avState);
		ReleaseMetadataOutputIfIdle(avState);
	}

	static NSString* BeginBarcodeScanning(CameraView* cameraView, NSArray* formats, BOOL continuous, void(^onResult)(NSString*, NSString*), void(^onDetected)(NSString*, NSString*), void(^onCancel)(NSString*)) {
		AVState* avState = cameraView->avState;

		if (cameraView->captureState != CAPTURE_STATE_IDLE)
			return @"Cannot scan a barcode while capturing a photo or recording video";

		FCVFrameAnalysisDelegate* existing = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		if (existing && [existing consumerOfClass:[FCVBarcodeScanDelegate class]])
			return @"A barcode scan is already in progress";

		NSArray* requestedTypes = nil;
		if (formats != nil && formats.count > 0) {
			requestedTypes = FCVMetadataObjectTypesForFormats(formats);
			if (requestedTypes.count == 0)
				return @"Unsupported barcode format";
		}

		NSString* error = EnsureMetadataOutput(cameraView);
		if (error)
			return error;

		AVCaptureMetadataOutput* output = avState->metadataOutput;
		if (!output)
			return @"Cannot add AVCaptureMetadataOutput to the session";

		NSMutableArray* wantedTypes;
		if (requestedTypes != nil) {
			wantedTypes = [NSMutableArray arrayWithArray:requestedTypes];
		} else {
			wantedTypes = [NSMutableArray arrayWithArray:@[
				AVMetadataObjectTypeQRCode,
				AVMetadataObjectTypeEAN13Code,
				AVMetadataObjectTypeEAN8Code,
				AVMetadataObjectTypeUPCECode,
				AVMetadataObjectTypeCode39Code,
				AVMetadataObjectTypeCode39Mod43Code,
				AVMetadataObjectTypeCode93Code,
				AVMetadataObjectTypeCode128Code,
				AVMetadataObjectTypePDF417Code,
				AVMetadataObjectTypeAztecCode,
				AVMetadataObjectTypeDataMatrixCode,
				AVMetadataObjectTypeITF14Code,
				AVMetadataObjectTypeInterleaved2of5Code
			]];
			if (@available(iOS 15.4, *))
				[wantedTypes addObject:AVMetadataObjectTypeCodabarCode];
		}

		NSMutableArray* objectTypes = [[NSMutableArray alloc] init];
		NSArray* availableTypes = output.availableMetadataObjectTypes;
		for (NSString* type in wantedTypes) {
			if (availableTypes.count == 0 || [availableTypes containsObject:type])
				[objectTypes addObject:type];
		}

		if (objectTypes.count == 0) {
			ReleaseMetadataOutputIfIdle(avState);
			return @"No supported barcode formats are available on this device";
		}

		FCVBarcodeScanDelegate* barcodeDelegate = [[FCVBarcodeScanDelegate alloc] init];
		barcodeDelegate.continuous = continuous;
		barcodeDelegate.onCancel = onCancel;
		barcodeDelegate.objectTypes = objectTypes;

		if (continuous) {
			barcodeDelegate.onDetected = onDetected;
		} else {
			barcodeDelegate.onResult = ^(NSString* value, NSString* format) {
				StopBarcodeDetector(avState);
				onResult(value, format);
			};
		}

		FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
		[delegate addConsumer:barcodeDelegate];
		UpdateMetadataObjectTypes(avState);

		return nil;
	}

	void scanBarcode(CameraView* cameraView, NSArray* formats, void(^onResolve)(NSString*, NSString*), void(^onReject)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			NSString* error = BeginBarcodeScanning(cameraView, formats, NO, onResolve, nil, onReject);
			if (error != nil)
				onReject(error);
		});
	}

	void startBarcodeScanning(CameraView* cameraView, NSArray* formats, void(^onDetected)(NSString*, NSString*), void(^onStarted)(NSString* error)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			NSString* error = BeginBarcodeScanning(cameraView, formats, YES, nil, onDetected, nil);
			onStarted(error);
		});
	}

	void stopBarcodeScanning(CameraView* cameraView, void(^onStopped)(bool wasScanning)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
			bool wasScanning = delegate != nil && [delegate consumerOfClass:[FCVBarcodeScanDelegate class]] != nil;

			if (wasScanning)
				StopBarcodeDetector(avState);

			onStopped(wasScanning);
		});
	}

	void stopFaceDetection(CameraView* cameraView, void(^onStopped)(bool)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
			bool wasDetecting = delegate != nil && [delegate consumerOfClass:[FCVFaceDetectionDelegate class]] != nil;

			if (wasDetecting)
				StopFaceDetector(avState);

			onStopped(wasDetecting);
		});
	}

	void startFaceDetection(CameraView* cameraView, void(^onFace)(int, float, float, float, float, float, float), void(^onFrame)(void), void(^onStarted)(NSString*)) {
		AVState* avState = cameraView->avState;
		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onStarted(@"Cannot start face detection while capturing a photo or recording video");
				return;
			}

			FCVFrameAnalysisDelegate* existing = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
			if (existing && [existing consumerOfClass:[FCVFaceDetectionDelegate class]]) {
				onStarted(@"Face detection is already running");
				return;
			}

			NSString* error = EnsureMetadataOutput(cameraView);
			if (error) {
				onStarted(error);
				return;
			}

			AVCaptureMetadataOutput* output = avState->metadataOutput;
			if (![output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeFace]) {
				ReleaseMetadataOutputIfIdle(avState);
				onStarted(@"Face detection is not supported by this camera");
				return;
			}

			FCVFaceDetectionDelegate* faceDelegate = [[FCVFaceDetectionDelegate alloc] init];
			faceDelegate.preview = avState->preview;
			faceDelegate.onFace = onFace;
			faceDelegate.onFrame = onFrame;

			FCVFrameAnalysisDelegate* delegate = (FCVFrameAnalysisDelegate*)avState->metadataDelegate;
			[delegate addConsumer:faceDelegate];
			UpdateMetadataObjectTypes(avState);

			onStarted(nil);
		});
	}


} // namespace fcv
