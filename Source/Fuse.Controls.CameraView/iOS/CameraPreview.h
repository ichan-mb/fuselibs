#ifndef CAMERAPREVIEW_H
#define CAMERAPREVIEW_H

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraPreview : UIView

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer* videoPreviewLayer;
@property (nonatomic) AVCaptureSession* session;
@property (nonatomic) BOOL fillView;

/** Draws an opaque ARGB mask above the preview. Must be called on the main thread. */
- (void)setOverlayPixels:(const uint32_t*)pixels width:(int)width height:(int)height;

/** Removes the overlay. Must be called on the main thread. */
- (void)clearOverlay;

@end

#endif
