#ifndef RECORDINGSESSION_H
#define RECORDINGSESSION_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/**
        Records video to a single output file.

        Pause/resume is implemented by recording separate segments and joining
   them when the recording is stopped, since AVCaptureMovieFileOutput has no
   pause.
*/
@interface RecordingSession : NSObject <AVCaptureFileOutputRecordingDelegate>

- (instancetype)initWithMovieFileOutput:
                    (AVCaptureMovieFileOutput *)movieFileOutput
                     withOutputFilePath:(NSString *)outputFilePath
                     withCleanupHandler:(void (^)(void))handler
                      withDispatchQueue:(dispatch_queue_t)queue;

/** Starts the first segment. Must be called on the provided dispatch queue. */
- (void)startRecording;

- (void)stopRecording:(void (^)(NSString *))resolve
             onReject:(void (^)(NSString *))reject;
- (void)pauseRecording:(void (^)(BOOL))resolve
              onReject:(void (^)(NSString *))reject;
- (void)resumeRecording:(void (^)(BOOL))resolve
               onReject:(void (^)(NSString *))reject;

- (int64_t)durationMilliseconds;

@end

#endif
