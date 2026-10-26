#import <AVFoundation/AVFoundation.h>
#include <uObjC.Foreign.h>

/** Forwards AVAudioPlayer/AVPlayer callbacks to Uno delegates. */
@interface UnoAudioPlayerDelegate : NSObject <AVAudioPlayerDelegate>
- (void)setCallbacks:(uDelegate *)onCompleted error:(uDelegate *)onError;
- (void)notifyCompleted;
@end

/**
        Installs a delegate on a local AVAudioPlayer that reports completion and
   decode errors. The delegate is retained by the player itself (via an
   associated object).
*/
void UnoAudioPlayerInstallCallbacks(AVAudioPlayer *player,
                                    uDelegate *onCompleted, uDelegate *onError);

/**
        Observes an AVPlayer for end-of-stream (completion). The observer is
   retained by the player itself and must be removed with
   UnoAudioPlayerRemoveObservers.
*/
void UnoAudioPlayerObserveStream(AVPlayer *player, uDelegate *onCompleted,
                                 uDelegate *onError);

/** Removes the stream observers installed by UnoAudioPlayerObserveStream. */
void UnoAudioPlayerRemoveObservers(AVPlayer *player);
