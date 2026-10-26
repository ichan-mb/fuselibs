using Uno;
using Uno.UX;

namespace Fuse
{
	/** UX component for configuring audio sampling parameters

		This component can be used as a child element within AudioPlayer or AudioRecorder
		to configure sampling settings declaratively in UX markup.

		## Example
		```xml
			<AudioPlayer File="music.mp3">
				<SampleConfig SampleRate="48000"
				             ChannelCount="2"
				             Format="Float32"
				             BufferSize="2048"
				             UpdateIntervalMs="25" />
			</AudioPlayer>
		```

		## Properties
		- SampleRate: Audio sample rate in Hz (default: 44100)
		- ChannelCount: Number of channels - 1 for mono, 2 for stereo (default: 1)
		- Format: Sample format - "Int16" or "Float32" (default: "Int16")
		- BufferSize: Buffer size in samples per channel (default: 1024)
		- UpdateIntervalMs: Update interval in milliseconds (default: 50)
	*/
	public class SampleConfig : PropertyObject
	{
		int _sampleRate = 44100;
		int _channelCount = 1;
		AudioSampleFormat _format = AudioSampleFormat.Int16;
		int _bufferSize = 1024;
		int _updateIntervalMs = 50;

		/** Gets or sets the sample data format (default: Int16) */
		public AudioSampleFormat Format
		{
			get { return _format; }
			set { _format = value; }
		}

		/** Gets or sets the sample rate in Hz (default: 44100) */
		public int SampleRate
		{
			get { return _sampleRate; }
			set
			{
				_sampleRate = Math.Max(8000, Math.Min(96000, value));
			}
		}

		/** Gets or sets the number of channels - 1 for mono, 2 for stereo (default: 1) */
		public int ChannelCount
		{
			get { return _channelCount; }
			set
			{
				_channelCount = Math.Max(1, Math.Min(2, value));
			}
		}

		/** Gets or sets the buffer size in samples per channel (default: 1024) */
		public int BufferSize
		{
			get { return _bufferSize; }
			set
			{
				_bufferSize = Math.Max(128, Math.Min(8192, value));
			}
		}

		/** Gets or sets the update interval in milliseconds (default: 50) */
		public int UpdateIntervalMs
		{
			get { return _updateIntervalMs; }
			set
			{
				_updateIntervalMs = Math.Max(10, Math.Min(1000, value));
			}
		}

		/** Gets the sample rate */
		public int GetSampleRate() { return _sampleRate; }

		/** Gets the channel count */
		public int GetChannelCount() { return _channelCount; }

		/** Gets the buffer size */
		public int GetBufferSize() { return _bufferSize; }

		/** Gets the update interval */
		public int GetUpdateIntervalMs() { return _updateIntervalMs; }

		public int GetAudioSampleFormat()
		{
			return _format == AudioSampleFormat.Int16 ? 0 : 1;
		}

	}
}
