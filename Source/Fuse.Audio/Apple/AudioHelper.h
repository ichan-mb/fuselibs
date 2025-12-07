#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class SoundHandle;
@class RecorderHandle;

@interface AudioHelper : NSObject
+ (AudioHelper *)getInstance;
- (NSNumber *)playSound:(NSData *)data;
- (NSNumber *)playSoundFromFile:(NSURL *)data;
- (void)kill:(SoundHandle *)handle;

// Recording methods
- (BOOL)startRecordingWithPath:(NSString *)path
                        format:(int)format
                    sampleRate:(int)sampleRate
                       bitRate:(int)bitRate
                      channels:(int)channels;
- (NSString *)stopRecording;
- (BOOL)pauseRecording;
- (BOOL)resumeRecording;
- (BOOL)hasRecordingPermission;
- (void)requestRecordingPermission;
@end

@interface SoundHandle : NSObject <AVAudioPlayerDelegate>
@property(nonatomic, retain) AVAudioPlayer *player;
- (id)initWithUrl:(NSURL *)url helper:(AudioHelper *)helper;
- (id)init:(NSData *)bytes helper:(AudioHelper *)helper;
- (void)play;
- (NSNumber *)getIdentifier;
@end
