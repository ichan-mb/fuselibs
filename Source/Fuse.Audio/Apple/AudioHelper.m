#ifdef iOS
#import "AudioHelper.h"
#else
#import "Apple/AudioHelper.h"
#endif

@implementation SoundHandle
{
	NSNumber* _identifier;
	AudioHelper* _helper;
}

@synthesize player;

static int _idPool = 0;
+(NSNumber*)getNextID
{
	return [[NSNumber alloc] initWithInt:_idPool++];
}

-(NSNumber*)getIdentifier
{
	return _identifier;
}

-(id) init:(NSData*)bytes helper:(AudioHelper*)helper
{
	self = [super init];
	_identifier = [SoundHandle getNextID];
	_helper = helper;
	self.player = [[AVAudioPlayer alloc] initWithData:bytes error:nil];
	[player setDelegate: self];
	[player prepareToPlay];

	return self;
}

-(id) initWithUrl:(NSURL*)url helper:(AudioHelper*)helper
{
	self = [super init];
	_identifier = [SoundHandle getNextID];
	_helper = helper;
	self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
	[player setDelegate: self];
	[player prepareToPlay];

	return self;
}

- (void)play
{
	[player play];
}

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player
						successfully: (BOOL) completed
{
	if (completed)
    {
		self.player = nil;
		[_helper kill:self];
	}
}

@end

@implementation AudioHelper
{
	NSMutableDictionary* _playingSounds;
	RecorderHandle* _currentRecorder;
	AVAudioEngine* _samplingAudioEngine;
}

static AudioHelper* _instance;

+(AudioHelper*) getInstance
{
	if(_instance == nil) _instance = [[AudioHelper alloc] init];
	return _instance;
}

- (void)kill:(SoundHandle *)handle
{
	[_playingSounds removeObjectForKey:[handle getIdentifier]];
}

-(id)init
{
	self = [super init];
	_playingSounds = [[NSMutableDictionary alloc] init];
	_currentRecorder = nil;
	_samplingAudioEngine = nil;
	return self;
}

- (NSNumber *)playSound:(NSData*)bytes
{
	SoundHandle* handle = [[SoundHandle alloc] init:bytes helper:self];
	_playingSounds[[handle getIdentifier]] = handle;
	[handle play];
	return [handle getIdentifier];
}

- (NSNumber *)playSoundFromFile:(NSURL*)url
{
	SoundHandle* handle = [[SoundHandle alloc] initWithUrl:url helper:self];
	_playingSounds[[handle getIdentifier]] = handle;
	[handle play];
	return [handle getIdentifier];
}

- (BOOL)startRecordingWithPath:(NSString *)path
                        format:(int)format
                    sampleRate:(int)sampleRate
                       bitRate:(int)bitRate
                      channels:(int)channels
                        source:(int)source
                   maxDuration:(double)maxDuration
{
	if (_currentRecorder != nil) {
		[self stopRecording];
	}

	_currentRecorder = [[RecorderHandle alloc] initWithPath:path
													 format:format
												 sampleRate:sampleRate
													bitRate:bitRate
												   channels:channels
												     source:source
											 maxDuration:maxDuration];
	return [_currentRecorder startRecording];
}

- (AVAudioRecorder *)currentRecorder
{
	if (_currentRecorder == nil)
		return nil;

	return [_currentRecorder getRecorder];
}

- (NSString *)stopRecording
{
	if (_currentRecorder == nil) {
		return nil;
	}

	NSString *path = [_currentRecorder stopRecording];
	_currentRecorder = nil;
	return path;
}

- (BOOL)pauseRecording
{
	if (_currentRecorder == nil) {
		return NO;
	}

	return [_currentRecorder pauseRecording];
}

- (BOOL)resumeRecording
{
	if (_currentRecorder == nil) {
		return NO;
	}

	return [_currentRecorder resumeRecording];
}

- (BOOL)hasRecordingPermission
{
	AVAudioSessionRecordPermission permission = [[AVAudioSession sharedInstance] recordPermission];
	return permission == AVAudioSessionRecordPermissionGranted;
}

- (void)setSamplingAudioEngine:(AVAudioEngine *)audioEngine
{
	_samplingAudioEngine = audioEngine;
}

- (AVAudioEngine *)getSamplingAudioEngine
{
	return _samplingAudioEngine;
}

@end

@implementation RecorderHandle

- (id)initWithPath:(NSString *)path
            format:(int)format
        sampleRate:(int)sampleRate
           bitRate:(int)bitRate
          channels:(int)channels
            source:(int)source
       maxDuration:(double)maxDuration
{
	self = [super init];
	if (self) {
		_recordingPath = path;
		_source = source;
		_maxDuration = maxDuration;

		// Create recording directory if it doesn't exist
		NSString *directory = [path stringByDeletingLastPathComponent];
		[[NSFileManager defaultManager] createDirectoryAtPath:directory
								  withIntermediateDirectories:YES
												   attributes:nil
														error:nil];

		// Setup recording settings
		NSMutableDictionary *settings = [[NSMutableDictionary alloc] init];

		// Set format based on the format parameter
		switch (format) {
			case 0: // WAV
				[settings setObject:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
				[settings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
				[settings setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
				[settings setObject:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
				break;
			case 1: // AAC
				[settings setObject:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
				break;
			case 2: // MP3 - Use AAC as fallback since iOS doesn't support MP3 recording
			case 3: // M4A
			default:
				[settings setObject:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
				break;
		}

		[settings setObject:[NSNumber numberWithFloat:sampleRate] forKey:AVSampleRateKey];
		[settings setObject:[NSNumber numberWithInt:channels] forKey:AVNumberOfChannelsKey];
		[settings setObject:[NSNumber numberWithInt:bitRate] forKey:AVEncoderBitRateKey];
		[settings setObject:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];

		// Create recorder
		NSURL *url = [NSURL fileURLWithPath:path];
		NSError *error = nil;
		_recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];

		if (error) {
			NSLog(@"Error creating audio recorder: %@", error.localizedDescription);
			return nil;
		}

		[_recorder setDelegate:self];
		[_recorder setMeteringEnabled:YES];
		[_recorder prepareToRecord];
	}
	return self;
}

- (AVAudioRecorder*)getRecorder
{
	return _recorder;
}

+ (NSString *)modeForSource:(int)source
{
	switch (source) {
		case 2: // VoiceRecognition
			return AVAudioSessionModeMeasurement;
		case 3: // VoiceCommunication
			return AVAudioSessionModeVoiceChat;
		case 4: // Camcorder
			return AVAudioSessionModeVideoRecording;
		default:
			return AVAudioSessionModeDefault;
	}
}

- (BOOL)startRecording
{
	// Configure audio session
	NSError *error = nil;
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	[audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
	[audioSession setMode:[RecorderHandle modeForSource:_source] error:&error];
	[audioSession setActive:YES error:&error];

	if (error) {
		NSLog(@"Error configuring audio session: %@", error.localizedDescription);
		return NO;
	}

	if (_maxDuration > 0.0)
		return [_recorder recordForDuration:_maxDuration];

	return [_recorder record];
}

- (NSString *)stopRecording
{
	if (_recorder == nil) {
		return nil;
	}

	// stop finalizes the file, and is also valid when the recorder is paused.
	[_recorder stop];
	_recorder = nil;

	// Recording leaves the session in AVAudioSessionCategoryRecord, which would
	// silence subsequent playback. Restore a playback-friendly session.
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *error = nil;
	[audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
	[audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];

	return _recordingPath;
}

- (BOOL)pauseRecording
{
	if (_recorder && _recorder.isRecording) {
		[_recorder pause];
		return YES;
	}
	return NO;
}

- (BOOL)resumeRecording
{
	if (_recorder && !_recorder.isRecording) {
		return [_recorder record];
	}
	return NO;
}

// AVAudioRecorderDelegate methods
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
	if (!flag) {
		NSLog(@"Recording finished with error");
	}
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
	NSLog(@"Recording encode error: %@", error.localizedDescription);
}

@end
