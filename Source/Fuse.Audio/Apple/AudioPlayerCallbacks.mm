#ifdef iOS
#import "AudioPlayerCallbacks.h"
#else
#import "Apple/AudioPlayerCallbacks.h"
#endif

#import <objc/runtime.h>

@implementation UnoAudioPlayerDelegate
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

- (void)notifyCompleted
{
	if (_onCompleted != NULL)
		@{Uno.Action:of(_onCompleted):call()};
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)completed
{
	if (completed)
		[self notifyCompleted];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
	if (_onError != NULL)
		@{Uno.Action<string>:of(_onError):call(error.localizedDescription)};
}

@end

static char UnoAudioPlayerDelegateKey;
static char UnoAudioPlayerEndObserverKey;

void UnoAudioPlayerInstallCallbacks(AVAudioPlayer *player, uDelegate *onCompleted, uDelegate *onError)
{
	UnoAudioPlayerDelegate* delegate = [[UnoAudioPlayerDelegate alloc] init];
	[delegate setCallbacks:onCompleted error:onError];

	player.delegate = delegate;
	objc_setAssociatedObject(player, &UnoAudioPlayerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void UnoAudioPlayerObserveStream(AVPlayer *player, uDelegate *onCompleted, uDelegate *onError)
{
	UnoAudioPlayerDelegate* delegate = [[UnoAudioPlayerDelegate alloc] init];
	[delegate setCallbacks:onCompleted error:onError];
	objc_setAssociatedObject(player, &UnoAudioPlayerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	id token = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
	                                                            object:player.currentItem
	                                                             queue:[NSOperationQueue mainQueue]
	                                                        usingBlock:^(NSNotification* note) {
		[delegate notifyCompleted];
	}];

	objc_setAssociatedObject(player, &UnoAudioPlayerEndObserverKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void UnoAudioPlayerRemoveObservers(AVPlayer *player)
{
	id token = objc_getAssociatedObject(player, &UnoAudioPlayerEndObserverKey);
	if (token != nil)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:token];
		objc_setAssociatedObject(player, &UnoAudioPlayerEndObserverKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}
