#include "FrameStatistics.h"

#include <atomic>
#include <math.h>
#include <stdlib.h>

#include "CameraViewImpl.h"
#include "CameraPreview.h"

namespace fcv {

	namespace {

		const int HistogramBins = 64;
		const int MaskWidth = 160;

		const uint32_t ZebraColor = 0xffffffff;
		const uint32_t PeakingColor = 0xffffeb3b;

		// Degrees needed to make the raw buffer upright.
		int RotationFromConnection(AVCaptureConnection* connection) {
			if (!connection)
				return 0;

			switch (connection.videoOrientation) {
				case AVCaptureVideoOrientationPortrait:
					return 90;
				case AVCaptureVideoOrientationPortraitUpsideDown:
					return 270;
				case AVCaptureVideoOrientationLandscapeLeft:
					return 180;
				default:
					return 0;
			}
		}

		bool IsMirrored(CameraView* cameraView) {
			if (!cameraView || !cameraView->avState)
				return false;

			NSString* mode = cameraView->avState->mirrorMode ?: @"auto";
			bool isFront = cameraView->cameraFacing == CAMERA_FACING_FRONT;
			return [mode isEqualToString:@"on"] || ([mode isEqualToString:@"auto"] && isFront);
		}

		double Percentile(const int* counts, int total, double fraction) {
			int target = (int)ceil(fraction * total);
			if (target <= 0)
				target = 1;

			int cumulative = 0;
			for (int i = 0; i < HistogramBins; i++) {
				cumulative += counts[i];
				if (cumulative >= target)
					return (i + 0.5) / HistogramBins;
			}

			return 1.0;
		}

		double Clipped(const int* counts, int total, int start) {
			int clipped = 0;
			for (int i = start; i < start + 2 && i < HistogramBins; i++)
				clipped += counts[i];

			return total > 0 ? (double)clipped / total : 0.0;
		}

		int ClampIndex(int value, int size) {
			if (value < 0)
				return 0;
			return value >= size ? size - 1 : value;
		}

		// Samples the luminance plane into an upright, optionally mirrored, image.
		void DownsampleLuma(const uint8_t* base, size_t rowStride, int width, int height,
			int rotation, bool mirrored, int lumaWidth, int lumaHeight, uint8_t* destination) {
			for (int ty = 0; ty < lumaHeight; ty++) {
				double v = (ty + 0.5) / lumaHeight;
				int rowOffset = ty * lumaWidth;

				for (int tx = 0; tx < lumaWidth; tx++) {
					double u = (tx + 0.5) / lumaWidth;
					if (mirrored)
						u = 1.0 - u;

					int sx;
					int sy;

					switch (rotation) {
						case 90:
							sx = (int)(v * width);
							sy = (int)((1.0 - u) * height);
							break;
						case 180:
							sx = (int)((1.0 - u) * width);
							sy = (int)((1.0 - v) * height);
							break;
						case 270:
							sx = (int)((1.0 - v) * width);
							sy = (int)(u * height);
							break;
						default:
							sx = (int)(u * width);
							sy = (int)(v * height);
							break;
					}

					sx = ClampIndex(sx, width);
					sy = ClampIndex(sy, height);

					destination[rowOffset + tx] = base[sy * rowStride + sx];
				}
			}
		}

		bool IsEdge(const uint8_t* grid, int width, int height, int x, int y, double sensitivity) {
			int left = grid[y * width + MAX(0, x - 1)];
			int right = grid[y * width + MIN(width - 1, x + 1)];
			int top = grid[MAX(0, y - 1) * width + x];
			int bottom = grid[MIN(height - 1, y + 1) * width + x];

			int gradient = abs(right - left) + abs(bottom - top);

			// A higher sensitivity means weaker edges are marked.
			int threshold = (int)((1.0 - sensitivity) * 200) + 20;
			return gradient >= threshold;
		}

		// Zebra and peaking in one pass over the small luminance grid.
		void RenderMask(const uint8_t* grid, int width, int height,
			double zebra, double peaking, uint32_t* mask) {
			bool useZebra = zebra > 0;
			bool usePeaking = peaking > 0;
			int zebraThreshold = (int)(zebra * 255);

			for (int y = 0; y < height; y++) {
				int row = y * width;

				for (int x = 0; x < width; x++) {
					int index = row + x;
					uint32_t color = 0;

					if (useZebra && grid[index] >= zebraThreshold)
						color = ((x + y) & 7) < 4 ? ZebraColor : 0;

					if (color == 0 && usePeaking && IsEdge(grid, width, height, x, y, peaking))
						color = PeakingColor;

					mask[index] = color;
				}
			}
		}

		NSString* PresetForResolution(int width, int height) {
			int64_t pixels = (int64_t)width * height;
			if (pixels <= 640 * 480)
				return AVCaptureSessionPreset640x480;
			if (pixels <= 1280 * 720)
				return AVCaptureSessionPreset1280x720;
			if (pixels <= 1920 * 1080)
				return AVCaptureSessionPreset1920x1080;
			return AVCaptureSessionPresetHigh;
		}

		// Keeps full resolution stills when the session leaves the photo preset.
		void RefreshMaxPhotoDimensions(AVState* avState) {
			if (@available(iOS 16.0, *)) {
				if (!avState->photoOutput || !avState->deviceInput)
					return;

				CMVideoDimensions best = { 0, 0 };
				for (NSValue* value in avState->deviceInput.device.activeFormat.supportedMaxPhotoDimensions) {
					CMVideoDimensions dimensions;
					[value getValue:&dimensions];
					if ((int64_t)dimensions.width * dimensions.height > (int64_t)best.width * best.height)
						best = dimensions;
				}

				if (best.width > 0 && best.height > 0)
					avState->photoOutput.maxPhotoDimensions = best;
			}
		}

		void ReleaseVideoDataOutput(AVState* avState) {
			AVCaptureVideoDataOutput* output = avState->videoDataOutput;
			if (!output)
				return;

			avState->videoDataOutput = nil;
			avState->videoDataDelegate = nil;

			[avState->session beginConfiguration];
			[avState->session removeOutput:output];

			NSString* preset = avState->presetBeforeVideoData;
			avState->presetBeforeVideoData = nil;
			if (preset && [avState->session canSetSessionPreset:preset])
				avState->session.sessionPreset = preset;

			[avState->session commitConfiguration];

			RefreshMaxPhotoDimensions(avState);
		}

		bool HasActiveConsumer(FCVStatisticsDelegate* delegate) {
			if (!delegate)
				return false;

			return delegate.onStatistics != nil || delegate.zebra > 0 || delegate.peaking > 0;
		}

		void ReleaseVideoDataOutputIfIdle(AVState* avState) {
			FCVStatisticsDelegate* delegate = (FCVStatisticsDelegate*)avState->videoDataDelegate;
			if (HasActiveConsumer(delegate))
				return;

			ReleaseVideoDataOutput(avState);
		}

		// Must be called on the session queue.
		FCVStatisticsDelegate* ObtainVideoDelegate(AVState* avState) {
			FCVStatisticsDelegate* delegate = (FCVStatisticsDelegate*)avState->videoDataDelegate;
			if (delegate)
				return delegate;

			delegate = [[FCVStatisticsDelegate alloc] init];
			delegate.maxFps = 15;
			avState->videoDataDelegate = delegate;
			return delegate;
		}

		// Must be called on the session queue.
		NSString* EnsureVideoDataOutput(CameraView* cameraView, FCVStatisticsDelegate* delegate,
			int resolutionWidth, int resolutionHeight) {
			AVState* avState = cameraView->avState;
			if (avState->videoDataOutput)
				return nil;

			AVCaptureVideoDataOutput* output = [[AVCaptureVideoDataOutput alloc] init];
			output.alwaysDiscardsLateVideoFrames = YES;
			output.videoSettings = [NSDictionary dictionaryWithObject:
				[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
				forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];

			[avState->session beginConfiguration];

			avState->presetBeforeVideoData = avState->session.sessionPreset;

			if (![avState->session canAddOutput:output]) {
				avState->presetBeforeVideoData = nil;
				[avState->session commitConfiguration];
				return @"Cannot add AVCaptureVideoDataOutput to the session";
			}

			[avState->session addOutput:output];

			// A video data output does not deliver frames under the photo preset,
			// so analysis runs on a video preset.
			NSString* preset = PresetForResolution(resolutionWidth, resolutionHeight);
			if ([avState->session canSetSessionPreset:preset])
				avState->session.sessionPreset = preset;

			[output setSampleBufferDelegate:delegate queue:avState->queue];

			[avState->session commitConfiguration];

			avState->videoDataOutput = output;
			avState->videoDataDelegate = delegate;

			RefreshMaxPhotoDimensions(avState);

			// The preview layer belongs to a UIView, so the orientation is copied
			// from the main queue. Best effort: analysis works without it.
			dispatch_async(dispatch_get_main_queue(), ^{
				AVCaptureVideoDataOutput* current = avState->videoDataOutput;
				if (!current || !avState->preview)
					return;

				AVCaptureConnection* connection = [current connectionWithMediaType:AVMediaTypeVideo];
				if (connection)
					connection.videoOrientation = avState->preview.videoPreviewLayer.connection.videoOrientation;
			});

			return nil;
		}

	} // namespace

	void startFrameAnalysis(CameraView* cameraView, int maxFps, int resolutionWidth, int resolutionHeight,
		int lumaWidth, int lumaHeight,
		void (^onStatistics)(double, double, double, double, double, double, double, double),
		void (^onStarted)(id), void (^onError)(NSString*)) {
		AVState* avState = cameraView->avState;

		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onError(@"Cannot analyse frames while capturing a photo or recording video");
				return;
			}

			FCVStatisticsDelegate* existing = (FCVStatisticsDelegate*)avState->videoDataDelegate;
			if (existing && existing.onStatistics != nil) {
				onError(@"Frame analysis is already running");
				return;
			}

			FCVStatistics* statistics = [[FCVStatistics alloc] init];
			statistics.lumaWidth = lumaWidth;
			statistics.lumaHeight = lumaHeight;

			FCVStatisticsDelegate* delegate = ObtainVideoDelegate(avState);
			delegate.cameraView = cameraView;
			delegate.maxFps = maxFps > 0 ? maxFps : 15;
			delegate.lumaWidth = lumaWidth;
			delegate.lumaHeight = lumaHeight;
			delegate.statistics = statistics;
			delegate.onStatistics = onStatistics;

			NSString* error = EnsureVideoDataOutput(cameraView, delegate, resolutionWidth, resolutionHeight);
			if (error != nil) {
				delegate.onStatistics = nil;
				delegate.statistics = nil;
				ReleaseVideoDataOutputIfIdle(avState);
				onError(error);
				return;
			}

			onStarted(statistics);
		});
	}

	void stopFrameAnalysis(CameraView* cameraView, void (^onStopped)(bool)) {
		AVState* avState = cameraView->avState;

		dispatch_async(avState->queue, ^{
			FCVStatisticsDelegate* delegate = (FCVStatisticsDelegate*)avState->videoDataDelegate;
			bool wasAnalysing = delegate != nil && delegate.onStatistics != nil;

			if (delegate) {
				delegate.onStatistics = nil;
				delegate.statistics = nil;
				ReleaseVideoDataOutputIfIdle(avState);
			}

			onStopped(wasAnalysing);
		});
	}

	void setOverlayOptions(CameraView* cameraView, double zebra, double peaking,
		void (^onResolved)(double, double), void (^onError)(NSString*)) {
		AVState* avState = cameraView->avState;

		dispatch_async(avState->queue, ^{
			if (cameraView->captureState != CAPTURE_STATE_IDLE) {
				onError(@"Cannot draw the analysis overlay while capturing a photo or recording video");
				return;
			}

			FCVStatisticsDelegate* delegate = ObtainVideoDelegate(avState);
			delegate.cameraView = cameraView;
			delegate.zebra = zebra;
			delegate.peaking = peaking;

			if (zebra <= 0 && peaking <= 0) {
				ReleaseVideoDataOutputIfIdle(avState);

				dispatch_async(dispatch_get_main_queue(), ^{
					if (avState->preview)
						[avState->preview clearOverlay];
				});

				onResolved(zebra, peaking);
				return;
			}

			NSString* error = EnsureVideoDataOutput(cameraView, delegate, 640, 480);
			if (error != nil) {
				delegate.zebra = 0;
				delegate.peaking = 0;
				ReleaseVideoDataOutputIfIdle(avState);
				onError(error);
				return;
			}

			onResolved(zebra, peaking);
		});
	}

	NSData* statisticsHistogram(void* statistics) {
		return statistics ? ((__bridge FCVStatistics*)statistics).histogram : nil;
	}

	NSData* statisticsLuma(void* statistics) {
		return statistics ? ((__bridge FCVStatistics*)statistics).luma : nil;
	}

	int statisticsLumaWidth(void* statistics) {
		return statistics ? ((__bridge FCVStatistics*)statistics).lumaWidth : 0;
	}

	int statisticsLumaHeight(void* statistics) {
		return statistics ? ((__bridge FCVStatistics*)statistics).lumaHeight : 0;
	}

} // namespace fcv

@implementation FCVStatistics
@end

@implementation FCVStatisticsDelegate {
	double _lastDeliveryMs;

	uint8_t* _grid;
	uint32_t* _masks[2];
	int _maskWidth;
	int _maskHeight;
	int _maskIndex;
	std::atomic<bool> _pendingMask;
}

- (void)dealloc {
	free(_grid);
	free(_masks[0]);
	free(_masks[1]);
}

- (void)captureOutput:(AVCaptureOutput*)output
	didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	fromConnection:(AVCaptureConnection*)connection {

	FCVStatistics* statistics = self.statistics;
	bool wantsStatistics = statistics != nil && self.onStatistics != nil;
	bool wantsOverlay = self.zebra > 0 || self.peaking > 0;

	if (!wantsStatistics && !wantsOverlay)
		return;

	// The overlay has to keep up with the preview, so it raises the rate when it
	// is enabled.
	int maxFps = self.maxFps > 0 ? self.maxFps : 15;
	if (wantsOverlay && maxFps < 24)
		maxFps = 24;

	double nowMs = CACurrentMediaTime() * 1000.0;
	double minimumInterval = 1000.0 / maxFps;

	if (_lastDeliveryMs > 0 && nowMs - _lastDeliveryMs < minimumInterval)
		return;

	CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!pixelBuffer)
		return;

	CFTimeInterval started = CACurrentMediaTime();

	CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

	size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
	size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
	size_t rowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
	uint8_t* base = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);

	if (!base || width == 0 || height == 0) {
		CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
		return;
	}

	int rotation = fcv::RotationFromConnection(connection);

	if (wantsStatistics) {
		int counts[fcv::HistogramBins];
		memset(counts, 0, sizeof(counts));

		uint64_t sum = 0;
		for (size_t y = 0; y < height; y++) {
			const uint8_t* row = base + y * rowStride;
			for (size_t x = 0; x < width; x++) {
				uint8_t value = row[x];
				counts[value >> 2]++;
				sum += value;
			}
		}

		int total = (int)(width * height);

		uint8_t histogram[fcv::HistogramBins];
		for (int i = 0; i < fcv::HistogramBins; i++)
			histogram[i] = (uint8_t)MIN(255, (int)((int64_t)counts[i] * 255 / (total > 0 ? total : 1)));

		statistics.histogram = [NSData dataWithBytes:histogram length:sizeof(histogram)];

		if (self.lumaWidth > 0 && self.lumaHeight > 0) {
			size_t size = (size_t)(self.lumaWidth * self.lumaHeight);
			if (!statistics.luma || statistics.luma.length != size)
				statistics.luma = [NSMutableData dataWithLength:size];

			fcv::DownsampleLuma(base, rowStride, (int)width, (int)height, rotation,
				fcv::IsMirrored((fcv::CameraView*)self.cameraView),
				self.lumaWidth, self.lumaHeight, (uint8_t*)statistics.luma.mutableBytes);
		}

		double analysisMs = (CACurrentMediaTime() - started) * 1000.0;
		double timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000.0;

		void (^onStatistics)(double, double, double, double, double, double, double, double) = self.onStatistics;
		if (onStatistics) {
			onStatistics(
				timestamp,
				(double)sum / ((double)total * 255.0),
				fcv::Percentile(counts, total, 0.01),
				fcv::Percentile(counts, total, 0.50),
				fcv::Percentile(counts, total, 0.99),
				fcv::Clipped(counts, total, 0),
				fcv::Clipped(counts, total, fcv::HistogramBins - 2),
				analysisMs);
		}
	}

	if (wantsOverlay)
		[self renderOverlayFrom:base rowStride:rowStride width:(int)width height:(int)height rotation:rotation];

	CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

	_lastDeliveryMs = nowMs;
}

- (void)renderOverlayFrom:(const uint8_t*)base
	rowStride:(size_t)rowStride
	width:(int)width
	height:(int)height
	rotation:(int)rotation {

	if (!self.cameraView)
		return;

	bool swapped = rotation == 90 || rotation == 270;
	int uprightWidth = swapped ? height : width;
	int uprightHeight = swapped ? width : height;
	if (uprightWidth <= 0)
		return;

	int maskWidth = fcv::MaskWidth;
	int maskHeight = MAX(1, (int)lround((double)maskWidth * uprightHeight / uprightWidth));

	if (!_grid || _maskWidth != maskWidth || _maskHeight != maskHeight) {
		free(_grid);
		free(_masks[0]);
		free(_masks[1]);

		_grid = (uint8_t*)malloc((size_t)maskWidth * maskHeight);
		_masks[0] = (uint32_t*)calloc((size_t)maskWidth * maskHeight, sizeof(uint32_t));
		_masks[1] = (uint32_t*)calloc((size_t)maskWidth * maskHeight, sizeof(uint32_t));

		_maskWidth = maskWidth;
		_maskHeight = maskHeight;
	}

	if (!_grid || !_masks[0] || !_masks[1])
		return;

	fcv::DownsampleLuma(base, rowStride, width, height, rotation,
		fcv::IsMirrored((fcv::CameraView*)self.cameraView),
		maskWidth, maskHeight, _grid);

	int index = _maskIndex;
	uint32_t* mask = _masks[index];
	fcv::RenderMask(_grid, maskWidth, maskHeight, self.zebra, self.peaking, mask);

	if (_pendingMask.exchange(true))
		return;

	// The other buffer is used by the next frame, so this one is safe to read
	// from the main thread.
	_maskIndex = index ^ 1;

	CameraPreview* preview = ((fcv::CameraView*)self.cameraView)->avState->preview;
	if (!preview)
		return;

	dispatch_async(dispatch_get_main_queue(), ^{
		self->_pendingMask = false;

		[preview setOverlayPixels:mask width:maskWidth height:maskHeight];
	});
}

@end
