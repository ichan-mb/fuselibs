#ifdef iOS
#import "AudioRecorderCallbacks.h"
#else
#import "Apple/AudioRecorderCallbacks.h"
#endif

#import <objc/runtime.h>

@implementation UnoAudioRecorderDelegate
{
	uDelegate* _onCompleted;
	uDelegate* _onError;
}

- (void)setCallbacks:(uDelegate *)onCompleted error:(uDelegate *)onError
{
	if (_onCompleted != NULL)
	{
		uRelease(_onCompleted);
		_onCompleted = NULL;
	}

	if (_onError != NULL)
	{
		uRelease(_onError);
		_onError = NULL;
	}

	if (onCompleted != NULL)
	{
		uRetain(onCompleted);
		_onCompleted = onCompleted;
	}

	if (onError != NULL)
	{
		uRetain(onError);
		_onError = onError;
	}
}

- (void)dealloc
{
	if (_onCompleted != NULL)
	{
		uRelease(_onCompleted);
		_onCompleted = NULL;
	}

	if (_onError != NULL)
	{
		uRelease(_onError);
		_onError = NULL;
	}
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)completed
{
	if (_onCompleted == NULL)
		return;

	// A finish that is not successful is reported as an encode error instead
	if (completed)
		@{Uno.Action:of(_onCompleted):call()};
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
	if (_onError != NULL)
		@{Uno.Action<string>:of(_onError):call(error.localizedDescription)};
}

@end

static char UnoAudioRecorderDelegateKey;

void UnoAudioRecorderInstallCallbacks(AVAudioRecorder *recorder, uDelegate *onCompleted, uDelegate *onError)
{
	UnoAudioRecorderDelegate* delegate = [[UnoAudioRecorderDelegate alloc] init];
	[delegate setCallbacks:onCompleted error:onError];

	recorder.delegate = delegate;
	objc_setAssociatedObject(recorder, &UnoAudioRecorderDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
