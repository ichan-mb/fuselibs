#ifndef FRAMESTATISTICS_H
#define FRAMESTATISTICS_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * Holds the buffers of the last analysed frame.
 *
 * The buffers are reused between frames and are only valid until the statistics
 * callback returns, which is how the Uno layer reads them.
 */
@interface FCVStatistics : NSObject
@property (nonatomic, strong) NSData* histogram;
@property (nonatomic, strong) NSMutableData* luma;
@property (nonatomic, assign) int lumaWidth;
@property (nonatomic, assign) int lumaHeight;
@end

/**
 * Consumes the video data output for both statistics and the analysis overlay.
 *
 * Statistics are delivered through `onStatistics`, while the overlay is drawn
 * directly on the preview, so JavaScript never sees the mask.
 */
@interface FCVStatisticsDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, copy) void (^onStatistics)(double, double, double, double, double, double, double, double);
@property (nonatomic, assign) int maxFps;
@property (nonatomic, assign) int lumaWidth;
@property (nonatomic, assign) int lumaHeight;
/** Zebra luminance threshold, 0 when disabled. */
@property (nonatomic, assign) double zebra;
/** Peaking sensitivity, 0 when disabled. */
@property (nonatomic, assign) double peaking;
/** Non retained fcv::CameraView*, used to read the current orientation, mirroring and preview. */
@property (nonatomic, assign) void* cameraView;
@property (nonatomic, strong) FCVStatistics* statistics;
@end

#endif
