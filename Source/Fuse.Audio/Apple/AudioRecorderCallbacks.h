#import <AVFoundation/AVFoundation.h>
#include <uObjC.Foreign.h>

/** Forwards AVAudioRecorder delegate callbacks to Uno delegates. */
@interface UnoAudioRecorderDelegate : NSObject <AVAudioRecorderDelegate>
- (void)setCallbacks:(uDelegate *)onCompleted error:(uDelegate *)onError;
@end

/**
        Installs a delegate on the recorder that reports when it stopped (for
   example because of a max duration limit) and encoder errors. The delegate is
   retained by the recorder.
*/
void UnoAudioRecorderInstallCallbacks(AVAudioRecorder *recorder,
                                      uDelegate *onCompleted,
                                      uDelegate *onError);
