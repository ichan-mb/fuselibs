#include "RecordingSession.h"
#include <math.h>

@interface RecordingSession ()
@property (nonatomic,strong) AVCaptureMovieFileOutput* movieFileOutput;
@property (nonatomic,copy) NSString* outputFilePath;
@property (nonatomic,copy) void(^cleanupHandler)(void);
@property (nonatomic,strong) dispatch_queue_t queue;

@property (nonatomic) BOOL stopped;
@property (nonatomic) BOOL paused;
@property (nonatomic) BOOL segmentStopPending;

@property (nonatomic,strong) NSMutableArray<NSURL*>* segments;
@property (nonatomic,strong) NSURL* currentSegmentURL;
@property (nonatomic) CMTime accumulatedDuration;
@property (nonatomic) CMTime pendingSegmentDuration;

@property (copy) void(^stopResolve)(NSString*);
@property (copy) void(^stopReject)(NSString*);
@property (copy) void(^pauseResolve)(BOOL);
@property (copy) void(^pauseReject)(NSString*);
@property (copy) void(^resumeResolve)(BOOL);
@end

@implementation RecordingSession

-(instancetype)initWithMovieFileOutput:(AVCaptureMovieFileOutput*)movieFileOutput withOutputFilePath:(NSString*)outputFilePath withCleanupHandler:(void(^)(void))handler withDispatchQueue:(dispatch_queue_t)queue {
	if (self = [super init]) {
		self.movieFileOutput = movieFileOutput;
		self.outputFilePath = outputFilePath;
		self.cleanupHandler = handler;
		self.queue = queue;
		self.stopped = false;
		self.paused = false;
		self.segments = [[NSMutableArray alloc] init];
		self.accumulatedDuration = kCMTimeZero;
		self.pendingSegmentDuration = kCMTimeZero;
	}
	return self;
}

-(void)startRecording {
	dispatch_async(self.queue, ^{
		[self startSegment];
	});
}

-(void)startSegment {
	NSString* fileName = [NSUUID UUID].UUIDString;
	NSURL* url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[fileName stringByAppendingPathExtension:@"mov"]]];
	self.currentSegmentURL = url;
	[self.movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
}

-(void)stopRecording:(void(^)(NSString*))resolve onReject:(void(^)(NSString*))reject {
	dispatch_async(self.queue, ^{
		if (self.stopped) {
			reject(@"RecordingSession already stopped!");
			return;
		}

		self.stopped = true;
		self.stopResolve = resolve;
		self.stopReject = reject;

		// A segment stop is in flight: the delegate adds the segment and then
		// finalizes the output.
		if (self.segmentStopPending)
			return;

		if (self.paused || !self.movieFileOutput.isRecording || self.currentSegmentURL == nil) {
			[self finalizeOutput];
			return;
		}

		self.segmentStopPending = true;
		self.pendingSegmentDuration = self.movieFileOutput.recordedDuration;
		[self.movieFileOutput stopRecording];
	});
}

-(void)pauseRecording:(void(^)(BOOL))resolve onReject:(void(^)(NSString*))reject {
	dispatch_async(self.queue, ^{
		if (self.stopped || self.paused || self.segmentStopPending || !self.movieFileOutput.isRecording || self.currentSegmentURL == nil) {
			resolve(NO);
			return;
		}

		self.paused = true;
		self.pauseResolve = resolve;
		self.pauseReject = reject;
		self.segmentStopPending = true;
		self.pendingSegmentDuration = self.movieFileOutput.recordedDuration;
		[self.movieFileOutput stopRecording];
	});
}

-(void)resumeRecording:(void(^)(BOOL))resolve onReject:(void(^)(NSString*))reject {
	dispatch_async(self.queue, ^{
		if (self.stopped || !self.paused || self.segmentStopPending) {
			resolve(NO);
			return;
		}

		self.paused = false;
		[self startSegment];
		resolve(YES);
	});
}

-(int64_t)durationMilliseconds {
	CMTime duration = self.accumulatedDuration;
	if (!self.paused && !self.stopped && self.movieFileOutput.isRecording) {
		CMTime current = self.movieFileOutput.recordedDuration;
		if (CMTIME_IS_VALID(current))
			duration = CMTimeAdd(duration, current);
	}

	if (CMTIME_IS_VALID(duration))
		return (int64_t)llround(CMTimeGetSeconds(duration) * 1000.0);
	return 0;
}

- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
	dispatch_async(self.queue, ^{
		BOOL success = YES;
		if (error) {
			NSLog(@"Movie file finishing error: %@", error);
			success = [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue];
		}

		// Whatever happens, the stopped segment is no longer in progress.
		self.currentSegmentURL = nil;
		self.segmentStopPending = false;

		void (^pauseResolve)(BOOL) = self.pauseResolve;
		void (^pauseReject)(NSString*) = self.pauseReject;
		self.pauseResolve = nil;
		self.pauseReject = nil;

		if (!success) {
			[self discardSegments];

			if (self.stopped) {
				[self finishStopWithError:[NSString stringWithFormat:@"Failed to capture output: %@", error]];
				return;
			}

			if (pauseReject)
				pauseReject([NSString stringWithFormat:@"Failed to pause recording: %@", error]);
			return;
		}

		[self.segments addObject:outputFileURL];
		self.accumulatedDuration = CMTimeAdd(self.accumulatedDuration, self.pendingSegmentDuration);

		if (self.stopped) {
			if (pauseResolve)
				pauseResolve(NO);
			[self finalizeOutput];
			return;
		}

		if (pauseResolve)
			pauseResolve(YES);
	});
}

-(void)finalizeOutput {
	if (self.segments.count == 0) {
		[self finishStopWithError:@"No video was recorded"];
		return;
	}

	if (self.segments.count == 1) {
		NSURL* segment = self.segments[0];
		NSURL* destination = [NSURL fileURLWithPath:self.outputFilePath];
		[[NSFileManager defaultManager] removeItemAtURL:destination error:NULL];

		NSError* error = nil;
		if ([[NSFileManager defaultManager] moveItemAtURL:segment toURL:destination error:&error]) {
			[self.segments removeAllObjects];
			[self finishStopWithPath:self.outputFilePath];
		} else {
			[self finishStopWithError:[NSString stringWithFormat:@"Failed to move recorded video: %@", error]];
		}
		return;
	}

	[self concatenateSegments];
}

-(void)concatenateSegments {
	AVMutableComposition* composition = [AVMutableComposition composition];
	AVMutableCompositionTrack* videoTrack = nil;
	AVMutableCompositionTrack* audioTrack = nil;
	CMTime cursor = kCMTimeZero;

	for (NSURL* url in self.segments) {
		AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:nil];
		NSArray<AVAssetTrack*>* videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
		if (videoTracks.count == 0)
			continue;

		AVAssetTrack* sourceVideo = videoTracks[0];
		CMTimeRange range = CMTimeRangeMake(kCMTimeZero, asset.duration);

		if (videoTrack == nil) {
			videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
			videoTrack.preferredTransform = sourceVideo.preferredTransform;
		}

		[videoTrack insertTimeRange:range ofTrack:sourceVideo atTime:cursor error:NULL];

		NSArray<AVAssetTrack*>* audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
		if (audioTracks.count > 0) {
			if (audioTrack == nil)
				audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

			[audioTrack insertTimeRange:range ofTrack:audioTracks[0] atTime:cursor error:NULL];
		}

		cursor = CMTimeAdd(cursor, asset.duration);
	}

	if (videoTrack == nil || CMTIME_COMPARE_INLINE(cursor, <=, kCMTimeZero)) {
		[self finishStopWithError:@"No video was recorded"];
		return;
	}

	AVAssetExportSession* exportSession = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
	if (exportSession == nil) {
		[self finishStopWithError:@"Failed to create a video export session"];
		return;
	}

	NSURL* destination = [NSURL fileURLWithPath:self.outputFilePath];
	[[NSFileManager defaultManager] removeItemAtURL:destination error:NULL];

	exportSession.outputURL = destination;
	exportSession.outputFileType = AVFileTypeQuickTimeMovie;
	exportSession.shouldOptimizeForNetworkUse = YES;

	[exportSession exportAsynchronouslyWithCompletionHandler:^{
		dispatch_async(self.queue, ^{
			if (exportSession.status == AVAssetExportSessionStatusCompleted)
				[self finishStopWithPath:self.outputFilePath];
			else
				[self finishStopWithError:[NSString stringWithFormat:@"Failed to export recorded video: %@", exportSession.error]];
		});
	}];
}

-(void)discardSegments {
	for (NSURL* url in self.segments)
		[[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
	[self.segments removeAllObjects];
}

-(void)finishStopWithPath:(NSString*)path {
	void (^resolve)(NSString*) = self.stopResolve;
	self.stopResolve = nil;
	self.stopReject = nil;
	[self discardSegments];
	[self finishCleanup];
	if (resolve)
		resolve(path);
}

-(void)finishStopWithError:(NSString*)message {
	void (^reject)(NSString*) = self.stopReject;
	self.stopResolve = nil;
	self.stopReject = nil;
	[[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:self.outputFilePath] error:NULL];
	[self discardSegments];
	[self finishCleanup];
	if (reject)
		reject(message);
}

-(void)finishCleanup {
	void (^cleanup)(void) = self.cleanupHandler;
	self.cleanupHandler = nil;
	if (cleanup)
		cleanup();
}

@end
