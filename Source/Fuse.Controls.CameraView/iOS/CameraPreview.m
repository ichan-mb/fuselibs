#import "CameraPreview.h"

static AVCaptureVideoOrientation VideoOrientationFromDeviceOrientation(UIDeviceOrientation orientation) {
	switch (orientation) {
		case UIDeviceOrientationPortrait:
			return AVCaptureVideoOrientationPortrait;
		case UIDeviceOrientationPortraitUpsideDown:
			return AVCaptureVideoOrientationPortraitUpsideDown;
		case UIDeviceOrientationLandscapeLeft:
			return AVCaptureVideoOrientationLandscapeRight;
		case UIDeviceOrientationLandscapeRight:
			return AVCaptureVideoOrientationLandscapeLeft;
		default:
			return AVCaptureVideoOrientationPortrait;
	}
}

@interface CameraPreview () {
	BOOL _fillView;
	CGContextRef _overlayContext;
	int _overlayWidth;
	int _overlayHeight;
}

@property (nonatomic, strong) UIView* overlayView;

@end

@implementation CameraPreview

+(Class)layerClass {
	return [AVCaptureVideoPreviewLayer class];
}

-(AVCaptureVideoPreviewLayer*)videoPreviewLayer {
	return (AVCaptureVideoPreviewLayer*)self.layer;
}

-(AVCaptureSession*)session {
	return self.videoPreviewLayer.session;
}

-(void)setSession:(AVCaptureSession*)session {
	self.videoPreviewLayer.session = session;
}

-(void)setFrame:(CGRect)frame {
	[super setFrame:frame];

	if (!self.session)
		return;

	UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;

	if (UIDeviceOrientationIsPortrait(deviceOrientation) ||
		UIDeviceOrientationIsLandscape(deviceOrientation)) {
		self.videoPreviewLayer.connection.videoOrientation = VideoOrientationFromDeviceOrientation(deviceOrientation);
	}
}

-(BOOL)fillView {
	return _fillView;
}

-(void)setFillView:(BOOL)value {
	_fillView = value;
	if (_fillView) {
		self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	} else {
		self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
	}

	if (self.overlayView) {
		self.overlayView.layer.contentsGravity = _fillView ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
	}
}

-(void)layoutSubviews {
	[super layoutSubviews];

	if (self.overlayView)
		self.overlayView.frame = self.bounds;
}

-(void)setOverlayPixels:(const uint32_t*)pixels width:(int)width height:(int)height {
	if (!pixels || width <= 0 || height <= 0)
		return;

	UIView* overlay = self.overlayView;
	if (!overlay) {
		overlay = [[UIView alloc] initWithFrame:self.bounds];
		overlay.userInteractionEnabled = NO;
		overlay.layer.contentsGravity = _fillView ? kCAGravityResizeAspectFill : kCAGravityResizeAspect;
		overlay.layer.magnificationFilter = kCAFilterNearest;
		// The mask is opaque so it can share the ARGB buffer with Android; the
		// transparency comes from the layer.
		overlay.layer.opacity = 0.75f;
		[self addSubview:overlay];
		self.overlayView = overlay;
	}

	if (!_overlayContext || _overlayWidth != width || _overlayHeight != height) {
		if (_overlayContext)
			CGContextRelease(_overlayContext);

		CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
		_overlayContext = CGBitmapContextCreate(NULL, width, height, 8, (size_t)width * 4, space,
			kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGColorSpaceRelease(space);

		if (!_overlayContext) {
			_overlayWidth = 0;
			_overlayHeight = 0;
			return;
		}

		_overlayWidth = width;
		_overlayHeight = height;
	}

	memcpy(CGBitmapContextGetData(_overlayContext), pixels, (size_t)width * height * 4);

	CGImageRef image = CGBitmapContextCreateImage(_overlayContext);
	if (!image)
		return;

	overlay.layer.contents = (__bridge id)image;
	CGImageRelease(image);

	overlay.frame = self.bounds;
}

-(void)clearOverlay {
	if (_overlayContext) {
		CGContextRelease(_overlayContext);
		_overlayContext = NULL;
		_overlayWidth = 0;
		_overlayHeight = 0;
	}

	if (!self.overlayView)
		return;

	self.overlayView.layer.contents = nil;
	[self.overlayView removeFromSuperview];
	self.overlayView = nil;
}

-(void)dealloc {
	if (_overlayContext)
		CGContextRelease(_overlayContext);
}

@end
