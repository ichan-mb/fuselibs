#import <AVFoundation/AVFoundation.h>
#include <uObjC.Foreign.h>

/**
        Decodes the audio file at `url` and fills `output` with normalized
   (0..1) peak values, one per element. Returns false when the file cannot be
   opened or decoded.

        `output` must have at least two elements.
*/
bool UnoAudioWaveformExtract(NSURL *url, uArray *output);
