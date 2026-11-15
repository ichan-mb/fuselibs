#ifndef CAMERADELEGATES_H
#define CAMERADELEGATES_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class CameraPreview;

/**
 * A detector that consumes the objects reported by the shared metadata output.
 *
 * Consumers declare the object types they are interested in, which is used to
 * configure AVCaptureMetadataOutput. Every consumer filters the objects it is
 * handed itself, so consumers can be added without knowing about each other.
 */
@protocol FCVMetadataConsumer <NSObject>

- (NSArray<NSString*>*)metadataObjectTypes;
- (void)consumeObjects:(NSArray<AVMetadataObject*>*)objects connection:(AVCaptureConnection*)connection;
- (void)cancelWithMessage:(NSString*)message;

@end

@interface FCVBarcodeScanDelegate : NSObject <FCVMetadataConsumer>
@property (nonatomic, copy) void (^onResult)(NSString*, NSString*);
@property (nonatomic, copy) void (^onDetected)(NSString*, NSString*);
@property (nonatomic, copy) void (^onCancel)(NSString*);
@property (nonatomic, copy) NSString* lastValue;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL continuous;
@property (nonatomic, copy) NSArray* objectTypes;
- (void)cancelWithMessage:(NSString*)message;
@end

@interface FCVFaceDetectionDelegate : NSObject <FCVMetadataConsumer>
@property (nonatomic, copy) void (^onFace)(int, float, float, float, float, float, float);
@property (nonatomic, copy) void (^onFrame)(void);
@property (nonatomic, weak) CameraPreview* preview;
@property (nonatomic, assign) BOOL finished;
- (void)cancelWithMessage:(NSString*)message;
@end

/**
 * Routes the objects of one metadata output to any number of consumers, so
 * barcode scanning, face detection and other detectors can share a single
 * output.
 */
@interface FCVFrameAnalysisDelegate : NSObject <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, readonly) BOOL hasActiveConsumer;
@property (nonatomic, readonly) NSArray<NSString*>* metadataObjectTypes;
- (void)addConsumer:(id<FCVMetadataConsumer>)consumer;
- (void)removeConsumer:(id<FCVMetadataConsumer>)consumer;
- (id<FCVMetadataConsumer>)consumerOfClass:(Class)cls;
- (void)cancelWithMessage:(NSString*)message;
@end

#endif
