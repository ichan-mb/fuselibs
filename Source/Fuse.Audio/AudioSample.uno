using Uno;
using Fuse.Scripting;

namespace Fuse
{
	/** Audio sample data format types */
	public enum AudioSampleFormat
	{
		/** 16-bit signed integer samples */
		Int16,
		/** 32-bit floating point samples */
		Float32
	}

	/** Audio sample data containing waveform information for visualization or analysis */
	public class AudioSample
	{
		/** Sample rate of the audio data (samples per second) */
		public int SampleRate { get; private set; }

		/** Number of audio channels (1 = mono, 2 = stereo) */
		public int ChannelCount { get; private set; }

		/** Format of the sample data */
		public AudioSampleFormat Format { get; private set; }

		/** Number of samples per channel in this sample */
		public int SampleCount { get; private set; }

		/** Raw sample data array */
		public byte[] Data { get; private set; }

		/** Timestamp when this sample was captured (in milliseconds since start) */
		public double Timestamp { get; private set; }

		public AudioSample(int sampleRate, int channelCount, AudioSampleFormat format,
		                  int sampleCount, byte[] data, double timestamp)
		{
			SampleRate = sampleRate;
			ChannelCount = channelCount;
			Format = format;
			SampleCount = sampleCount;
			Data = data;
			Timestamp = timestamp;
		}

		/** Gets the size of each sample in bytes based on the format */
		public int GetSampleSizeInBytes()
		{
			switch (Format)
			{
				case AudioSampleFormat.Int16:
					return 2;
				case AudioSampleFormat.Float32:
					return 4;
				default:
					return 2;
			}
		}

		/** Gets the total size of all data in bytes */
		public int GetTotalDataSize()
		{
			return SampleCount * ChannelCount * GetSampleSizeInBytes();
		}

		/** Extracts 16-bit integer samples from the data array for a specific channel */
		public short[] GetInt16Samples(int channel = 0)
		{
			if (Format != AudioSampleFormat.Int16)
				throw new Exception("Sample format is not Int16");

			if (channel >= ChannelCount)
				throw new ArgumentException("Channel index out of range");

			var samples = new short[SampleCount];
			var sampleSize = GetSampleSizeInBytes();
			var frameSize = ChannelCount * sampleSize;

			for (int i = 0; i < SampleCount; i++)
			{
				var offset = i * frameSize + channel * sampleSize;
				samples[i] = (short)(Data[offset] | (Data[offset + 1] << 8));
			}

			return samples;
		}

		/** Extracts 32-bit float samples from the data array for a specific channel */
		public float[] GetFloat32Samples(int channel = 0)
		{
			if (Format != AudioSampleFormat.Float32)
				throw new Exception("Sample format is not Float32");

			if (channel >= ChannelCount)
				throw new ArgumentException("Channel index out of range");

			var samples = new float[SampleCount];
			var sampleSize = GetSampleSizeInBytes();
			var frameSize = ChannelCount * sampleSize;

			for (int i = 0; i < SampleCount; i++)
			{
				var offset = i * frameSize + channel * sampleSize;
				// Manually convert 4 bytes to float (little-endian)
				uint raw = (uint)(Data[offset] | (Data[offset + 1] << 8) | (Data[offset + 2] << 16) | (Data[offset + 3] << 24));
				samples[i] = raw;
			}

			return samples;
		}

		/** Calculates the RMS (Root Mean Square) amplitude for a specific channel */
		public double GetRMSAmplitude(int channel = 0)
		{
			if (channel >= ChannelCount)
				throw new ArgumentException("Channel index out of range");

			double sum = 0.0;

			if (Format == AudioSampleFormat.Int16)
			{
				var samples = GetInt16Samples(channel);
				foreach (var sample in samples)
				{
					var normalized = sample / 32768.0;
					sum += normalized * normalized;
				}
			}
			else if (Format == AudioSampleFormat.Float32)
			{
				var samples = GetFloat32Samples(channel);
				foreach (var sample in samples)
				{
					sum += sample * sample;
				}
			}

			return Math.Sqrt(sum / SampleCount);
		}

		/** Calculates the peak amplitude for a specific channel */
		public double GetPeakAmplitude(int channel = 0)
		{
			if (channel >= ChannelCount)
				throw new ArgumentException("Channel index out of range");

			double peak = 0.0;

			if (Format == AudioSampleFormat.Int16)
			{
				var samples = GetInt16Samples(channel);
				foreach (var sample in samples)
				{
					var normalized = Math.Abs(sample) / 32768.0;
					if (normalized > peak)
						peak = normalized;
				}
			}
			else if (Format == AudioSampleFormat.Float32)
			{
				var samples = GetFloat32Samples(channel);
				foreach (var sample in samples)
				{
					var abs = Math.Abs(sample);
					if (abs > peak)
						peak = abs;
				}
			}

			return peak;
		}
	}

	/** Event arguments for audio sampling events */
	public class AudioSampleEventArgs : EventArgs, IScriptEvent
	{
		public AudioSample Sample { get; private set; }

		public AudioSampleEventArgs(AudioSample sample)
		{
			Sample = sample;
		}
		
		void IScriptEvent.Serialize(IEventSerializer s)
		{
			Serialize(s);
		}

		virtual void Serialize(IEventSerializer s)
		{
			s.AddInt("sampleRate", Sample.SampleRate);
			s.AddInt("channelCount", Sample.ChannelCount);
			s.AddString("format", Sample.Format == AudioSampleFormat.Int16 ? "Int16" : "Float32");
			s.AddInt("sampleCount", Sample.SampleCount);
			s.AddDouble("peakAmplitude", Sample.GetPeakAmplitude());
			s.AddDouble("rmsAmplitude", Sample.GetRMSAmplitude());
			s.AddInt("totalSize", Sample.GetTotalDataSize());
			s.AddDouble("timestamp", Sample.Timestamp);
			s.AddInt("sampleSizeInBytes", Sample.GetSampleSizeInBytes());
			
		}
	}


}
