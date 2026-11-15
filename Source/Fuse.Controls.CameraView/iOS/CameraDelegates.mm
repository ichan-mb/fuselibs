#include "CameraDelegates.h"

#include "CameraPreview.h"

static NSString* FCVFormatNameForMetadataObjectType(NSString* type) {
	if ([type isEqualToString:AVMetadataObjectTypeQRCode]) return @"QR_CODE";
	if ([type isEqualToString:AVMetadataObjectTypeEAN13Code]) return @"EAN_13";
	if ([type isEqualToString:AVMetadataObjectTypeEAN8Code]) return @"EAN_8";
	if ([type isEqualToString:AVMetadataObjectTypeUPCECode]) return @"UPC_E";
	if ([type isEqualToString:AVMetadataObjectTypeCode39Code]) return @"CODE_39";
	if ([type isEqualToString:AVMetadataObjectTypeCode39Mod43Code]) return @"CODE_39";
	if ([type isEqualToString:AVMetadataObjectTypeCode93Code]) return @"CODE_93";
	if ([type isEqualToString:AVMetadataObjectTypeCode128Code]) return @"CODE_128";
	if ([type isEqualToString:AVMetadataObjectTypePDF417Code]) return @"PDF417";
	if ([type isEqualToString:AVMetadataObjectTypeAztecCode]) return @"AZTEC";
	if ([type isEqualToString:AVMetadataObjectTypeDataMatrixCode]) return @"DATA_MATRIX";
	if ([type isEqualToString:AVMetadataObjectTypeITF14Code]) return @"ITF";
	if ([type isEqualToString:AVMetadataObjectTypeInterleaved2of5Code]) return @"ITF";
	if (@available(iOS 15.4, *)) {
		if ([type isEqualToString:AVMetadataObjectTypeCodabarCode]) return @"CODABAR";
	}
	return @"UNKNOWN";
}

// Maps a metadata object to preview coordinates, normalized to 0..1 with the
// origin in the top left corner of the preview as displayed. Must run on the
// main thread, since it reads the bounds of the preview layer.
static CGRect FCVNormalizedPreviewRect(CameraPreview* preview, AVMetadataObject* object) {
	if (!preview || !object)
		return CGRectNull;

	AVCaptureVideoPreviewLayer* layer = preview.videoPreviewLayer;
	if (!layer)
		return CGRectNull;

	CGRect bounds = layer.bounds;
	CGFloat width = bounds.size.width;
	CGFloat height = bounds.size.height;

	if (width <= 0 || height <= 0)
		return CGRectNull;

	AVMetadataObject* transformed = [layer transformedMetadataObjectForMetadataObject:object];
	if (!transformed)
		return CGRectNull;

	CGRect rect = transformed.bounds;
	float x = (float)((rect.origin.x - bounds.origin.x) / width);
	float y = (float)((rect.origin.y - bounds.origin.y) / height);
	float w = (float)(rect.size.width / width);
	float h = (float)(rect.size.height / height);

	return CGRectMake(
		MAX(0.0f, MIN(1.0f, x)),
		MAX(0.0f, MIN(1.0f, y)),
		MAX(0.0f, MIN(1.0f, w)),
		MAX(0.0f, MIN(1.0f, h)));
}

@implementation FCVFaceDetectionDelegate

- (NSArray<NSString*>*)metadataObjectTypes {
	return @[AVMetadataObjectTypeFace];
}

- (void)cancelWithMessage:(NSString*)message {
	self.finished = YES;
	self.onFace = nil;
	self.onFrame = nil;
}

- (void)consumeObjects:(NSArray<AVMetadataObject*>*)objects connection:(AVCaptureConnection*)connection {
	if (self.finished)
		return;

	NSArray* received = [objects copy];
	CameraPreview* preview = self.preview;
	void (^onFace)(int, float, float, float, float, float, float) = self.onFace;
	void (^onFrame)(void) = self.onFrame;

	// The preview layer is a UIView, so mapping the face coordinates to it has
	// to happen on the main thread.
	dispatch_async(dispatch_get_main_queue(), ^{
		if (onFace) {
			for (AVMetadataObject* object in received) {
				if (![object isKindOfClass:[AVMetadataFaceObject class]])
					continue;

				CGRect rect = FCVNormalizedPreviewRect(preview, object);
				if (CGRectIsNull(rect))
					continue;

				AVMetadataFaceObject* face = (AVMetadataFaceObject*)object;
				int faceId = (int)face.faceID;
				float roll = face.hasRollAngle ? face.rollAngle : 0.0f;
				float yaw = face.hasYawAngle ? face.yawAngle : 0.0f;

				onFace(faceId,
					(float)rect.origin.x,
					(float)rect.origin.y,
					(float)rect.size.width,
					(float)rect.size.height,
					roll,
					yaw);
			}
		}

		if (onFrame)
			onFrame();
	});
}

@end

@implementation FCVBarcodeScanDelegate

- (NSArray<NSString*>*)metadataObjectTypes {
	return self.objectTypes ? self.objectTypes : @[];
}

- (void)cancelWithMessage:(NSString*)message {
	if (self.finished)
		return;

	self.finished = YES;

	void (^onCancel)(NSString*) = self.onCancel;
	self.onResult = nil;
	self.onDetected = nil;
	self.onCancel = nil;
	if (onCancel)
		onCancel(message);
}

- (void)consumeObjects:(NSArray<AVMetadataObject*>*)objects connection:(AVCaptureConnection*)connection {
	if (self.finished)
		return;

	AVMetadataMachineReadableCodeObject* matched = nil;
	for (AVMetadataObject* object in objects) {
		if (![object isKindOfClass:[AVMetadataMachineReadableCodeObject class]])
			continue;

		AVMetadataMachineReadableCodeObject* code = (AVMetadataMachineReadableCodeObject*)object;
		if (code.stringValue.length == 0)
			continue;

		matched = code;
		break;
	}

	if (!matched)
		return;

	NSString* format = FCVFormatNameForMetadataObjectType(matched.type);

	if (self.continuous) {
		// Only report a code once so a static barcode does not flood the
		// callback on every frame.
		if (self.lastValue != nil && [self.lastValue isEqualToString:matched.stringValue])
			return;

		self.lastValue = matched.stringValue;

		void (^onDetected)(NSString*, NSString*) = self.onDetected;
		if (onDetected)
			onDetected(matched.stringValue, format);
		return;
	}

	self.finished = YES;

	// Keep the delegate alive until this method returns: the result block
	// releases the session's reference to it.
	FCVBarcodeScanDelegate* keepAlive = self;
	(void)keepAlive;

	void (^onResult)(NSString*, NSString*) = self.onResult;
	self.onResult = nil;
	self.onCancel = nil;
	if (onResult)
		onResult(matched.stringValue, format);
}

@end

@implementation FCVFrameAnalysisDelegate {
	NSMutableArray<id<FCVMetadataConsumer>>* _consumers;
}

- (instancetype)init {
	self = [super init];
	if (self)
		_consumers = [[NSMutableArray alloc] init];
	return self;
}

- (void)addConsumer:(id<FCVMetadataConsumer>)consumer {
	if (!consumer || [_consumers indexOfObjectIdenticalTo:consumer] != NSNotFound)
		return;

	[_consumers addObject:consumer];
}

- (void)removeConsumer:(id<FCVMetadataConsumer>)consumer {
	NSUInteger index = [_consumers indexOfObjectIdenticalTo:consumer];
	if (index != NSNotFound)
		[_consumers removeObjectAtIndex:index];
}

- (id<FCVMetadataConsumer>)consumerOfClass:(Class)cls {
	for (id<FCVMetadataConsumer> consumer in _consumers) {
		if ([consumer isKindOfClass:cls])
			return consumer;
	}
	return nil;
}

- (BOOL)hasActiveConsumer {
	return _consumers.count > 0;
}

- (NSArray<NSString*>*)metadataObjectTypes {
	NSMutableArray* types = [[NSMutableArray alloc] init];

	for (id<FCVMetadataConsumer> consumer in _consumers) {
		for (NSString* type in [consumer metadataObjectTypes]) {
			if (![types containsObject:type])
				[types addObject:type];
		}
	}

	return types;
}

// Consumers are only called when the frame contains objects they asked for, so
// a consumer never sees a frame it has nothing to do with.
- (BOOL)objects:(NSArray<AVMetadataObject*>*)objects matchTypes:(NSArray<NSString*>*)types {
	if (types.count == 0)
		return YES;

	for (AVMetadataObject* object in objects) {
		if ([types containsObject:object.type])
			return YES;
	}

	return NO;
}

- (void)captureOutput:(AVCaptureOutput*)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject*>*)metadataObjects fromConnection:(AVCaptureConnection*)connection {
	NSArray<id<FCVMetadataConsumer>>* consumers = [_consumers copy];
	if (consumers.count == 0)
		return;

	for (id<FCVMetadataConsumer> consumer in consumers) {
		if ([self objects:metadataObjects matchTypes:[consumer metadataObjectTypes]])
			[consumer consumeObjects:metadataObjects connection:connection];
	}
}

- (void)cancelWithMessage:(NSString*)message {
	NSArray<id<FCVMetadataConsumer>>* consumers = [_consumers copy];
	[_consumers removeAllObjects];

	for (id<FCVMetadataConsumer> consumer in consumers)
		[consumer cancelWithMessage:message];
}

@end
