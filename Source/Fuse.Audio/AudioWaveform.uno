using Uno;
using Uno.UX;
using Uno.Threading;

namespace Fuse
{
	/**
		Extracts a waveform envelope from an audio file.

		`Extract` decodes the file on a background thread and returns `barCount` normalized
		peak values (`0..1`), ready to be drawn by a @Waveform control or by custom UI. The
		future is resolved on the UI thread, so the result can be used directly.

		The result is an envelope: one peak per bar, for example 64 values for a one minute
		recording. It is not the raw sample data, which makes it cheap to store and draw.

		## Example
		```uno
			AudioWaveform.Extract(path, 64).Then(values => {
				waveform.SetValues(values);
			}, error => {
				Fuse.Diagnostics.UserWarning("Could not read the waveform: " + error.Message, this);
			});
		```

		Supported formats are whatever the platform can decode: AAC/M4A, MP3 and WAV on both
		platforms, plus anything else the system decoder understands.
	*/
	public static class AudioWaveform
	{
		/** Extracts the envelope of a file on disk. `path` can be a path or a `file://` URL. */
		public static Future<float[]> Extract(string path, int barCount)
		{
			var bars = ClampBars(barCount);
			var promise = new Promise<float[]>();

			if (string.IsNullOrEmpty(path))
			{
				promise.Reject(new Exception("AudioWaveform.Extract: no path specified"));
				return promise;
			}

			ExtractOnThread(path, null, bars, promise);
			return promise;
		}

		/** Extracts the envelope of a @FileSource, including bundled files. */
		public static Future<float[]> Extract(FileSource file, int barCount)
		{
			var bars = ClampBars(barCount);
			var promise = new Promise<float[]>();

			if (file == null)
			{
				promise.Reject(new Exception("AudioWaveform.Extract: no file specified"));
				return promise;
			}

			ExtractOnThread(null, file, bars, promise);
			return promise;
		}

		static int ClampBars(int barCount)
		{
			return Math.Max(2, Math.Min(512, barCount));
		}

		static void ExtractOnThread(string path, FileSource file, int bars, Promise<float[]> promise)
		{
			new Thread(() =>
			{
				float[] values = null;
				string error = null;

				try
				{
					values = new float[bars];
					var ok = path != null
						? ExtractFromPathImpl(path, values)
						: ExtractFromFileImpl(file, values);

					if (!ok)
					{
						values = null;
						error = "the audio file could not be decoded";
					}
				}
				catch (Exception e)
				{
					values = null;
					error = e.Message;
				}

				// Resolve on the UI thread so callers can touch their UI directly
				UpdateManager.PostAction(() =>
				{
					if (values != null)
						promise.Resolve(values);
					else
						promise.Reject(new Exception("AudioWaveform.Extract: " + error));
				});
			}).Start();
		}

		extern(!Android && !iOS)
		static bool ExtractFromPathImpl(string path, float[] output)
		{
			return false;
		}

		extern(Android || iOS)
		static bool ExtractFromPathImpl(string path, float[] output)
		{
			return Fuse.Audio.AudioWaveformImpl.ExtractFromPath(path, output);
		}

		extern(!Android && !iOS)
		static bool ExtractFromFileImpl(FileSource file, float[] output)
		{
			return false;
		}

		extern(Android || iOS)
		static bool ExtractFromFileImpl(FileSource file, float[] output)
		{
			return Fuse.Audio.AudioWaveformImpl.ExtractFromFile(file, output);
		}
	}
}
