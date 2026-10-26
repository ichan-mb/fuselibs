#ifdef iOS
#import "AudioWaveform.h"
#else
#import "Apple/AudioWaveform.h"
#endif

#include <math.h>

bool UnoAudioWaveformExtract(NSURL *url, uArray *output)
{
	if (url == nil || output == NULL)
		return false;

	const int bars = output->Length();
	if (bars < 2)
		return false;

	@autoreleasepool
	{
		NSError* error = nil;
		AVAudioFile* file = [[AVAudioFile alloc] initForReading:url error:&error];
		if (file == nil || error != nil)
			return false;

		// Processing format is linear PCM float32, non-interleaved
		AVAudioFormat* format = file.processingFormat;
		AVAudioChannelCount channels = format.channelCount;
		if (channels < 1)
			return false;

		AVAudioFramePosition totalFrames = file.length;
		if (totalFrames <= 0)
			return false;

		AVAudioPCMBuffer* buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:4096];
		if (buffer == nil)
			return false;

		AVAudioFramePosition frame = 0;

		while (frame < totalFrames)
		{
			NSError* readError = nil;
			if (![file readIntoBuffer:buffer error:&readError] || readError != nil)
				break;

			AVAudioFrameCount frames = buffer.frameLength;
			if (frames == 0)
				break;

			float* const* data = buffer.floatChannelData;
			if (data == NULL)
				return false;

			for (AVAudioFrameCount i = 0; i < frames; i++)
			{
				float peak = 0.0f;
				for (AVAudioChannelCount ch = 0; ch < channels; ch++)
				{
					float value = fabsf(data[ch][i]);
					if (value > peak)
						peak = value;
				}

				int bucket = (int)(((frame + i) * (AVAudioFramePosition)bars) / totalFrames);
				if (bucket < 0) bucket = 0;
				if (bucket >= bars) bucket = bars - 1;

				if (peak > 1.0f) peak = 1.0f;
				if (peak > output->Item<float>(bucket))
					output->Item<float>(bucket) = peak;
			}

			frame += frames;
		}
	}

	return true;
}
