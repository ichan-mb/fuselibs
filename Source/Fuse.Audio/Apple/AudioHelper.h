#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class SoundHandle;

@interface AudioHelper : NSObject
+ (AudioHelper*) getInstance;
- (NSNumber*)playSound:(NSData *)data;
- (NSNumber*)playSoundFromFile:(NSURL *)data;
- (void)kill:(SoundHandle *)handle;

// Recording methods
- (BOOL)startRecordingWithPath:(NSString *)path
                        format:(int)format
                    sampleRate:(int)sampleRate
                       bitRate:(int)bitRate
                      channels:(int)channels
                        source:(int)source
                   maxDuration:(double)maxDuration;
- (NSString *)stopRecording;
- (BOOL)pauseRecording;
- (BOOL)resumeRecording;
- (BOOL)hasRecordingPermission;

// Access to the recorder that is currently recording (for metering and callbacks)
- (AVAudioRecorder *)currentRecorder;

// Audio sampling methods
- (void)setSamplingAudioEngine:(AVAudioEngine *)audioEngine;
- (AVAudioEngine *)getSamplingAudioEngine;
@end

@interface SoundHandle : NSObject <AVAudioPlayerDelegate>
@property (nonatomic, retain) AVAudioPlayer *player;
-(id) initWithUrl:(NSURL*)url helper:(AudioHelper*)helper;
-(id) init:(NSData*)bytes helper:(AudioHelper*)helper;
-(void) play;
-(NSNumber*)getIdentifier;
@end

@interface RecorderHandle : NSObject <AVAudioRecorderDelegate>
{
	AVAudioRecorder* _recorder;
	NSString* _recordingPath;
	int _source;
	double _maxDuration;
}
-(id) initWithPath:(NSString*)path
            format:(int)format
        sampleRate:(int)sampleRate
           bitRate:(int)bitRate
          channels:(int)channels
            source:(int)source
       maxDuration:(double)maxDuration;
-(BOOL) startRecording;
-(NSString*) stopRecording;
-(BOOL) pauseRecording;
-(BOOL) resumeRecording;
-(AVAudioRecorder*) getRecorder;
@end
